const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");

const EndsAtRow = struct { ends_at: ?[]const u8 };
const VotedRow = struct { _dummy: i64 };

const Poll = struct {
    id: i64,
    post_id: i64,
    question: []const u8,
    duration_minutes: i64,
    created_at: []const u8,
    ends_at: ?[]const u8,
};

const PollOption = struct {
    id: i64,
    poll_id: i64,
    option_text: []const u8,
    position: i64,
    vote_count: i64,
};

pub fn createPoll(allocator: std.mem.Allocator, post_id: i64, question: []const u8, options: [][]const u8, duration_minutes: i32) !void {
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);
    const duration_str = try std.fmt.allocPrint(allocator, "{d}", .{duration_minutes});
    defer allocator.free(duration_str);

    try db.execute(
        "INSERT INTO polls (post_id, question, duration_minutes, ends_at) VALUES (?, ?, ?, datetime('now', ? || ' minutes'))",
        &[_][]const u8{ post_id_str, question, duration_str, duration_str },
    );

    const poll_id = db.lastInsertRowId();
    const poll_id_str = try std.fmt.allocPrint(allocator, "{d}", .{poll_id});
    defer allocator.free(poll_id_str);

    for (options, 0..) |option, i| {
        const position_str = try std.fmt.allocPrint(allocator, "{d}", .{i});
        defer allocator.free(position_str);
        try db.execute(
            "INSERT INTO poll_options (poll_id, option_text, position) VALUES (?, ?, ?)",
            &[_][]const u8{ poll_id_str, option, position_str },
        );
    }
}

pub fn getPoll(allocator: std.mem.Allocator, post_id: i64) !?struct { poll: Poll, options: []PollOption, total_votes: i64, has_voted: bool, selected_option: ?i64 } {
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);

    const poll_sql = "SELECT id, post_id, question, duration_minutes, created_at, ends_at FROM polls WHERE post_id = ?";
    const poll_rows = db.query(Poll, allocator, poll_sql, &[_][]const u8{post_id_str}) catch |err| {
        std.log.err("Failed to get poll: {}", .{err});
        return null;
    };
    defer db.freeRows(Poll, allocator, poll_rows);

    if (poll_rows.len == 0) return null;

    const poll = poll_rows[0];
    const poll_id_str = try std.fmt.allocPrint(allocator, "{d}", .{poll.id});
    defer allocator.free(poll_id_str);

    const options_sql = "SELECT id, poll_id, option_text, position, vote_count FROM poll_options WHERE poll_id = ? ORDER BY position";
    const option_rows = db.query(PollOption, allocator, options_sql, &[_][]const u8{poll_id_str}) catch |err| {
        std.log.err("Failed to get poll options: {}", .{err});
        return null;
    };

    var total_votes: i64 = 0;
    for (option_rows) |opt| {
        total_votes += opt.vote_count;
    }

    return .{
        .poll = poll,
        .options = option_rows,
        .total_votes = total_votes,
        .has_voted = false,
        .selected_option = null,
    };
}

pub fn vote(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const poll_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing poll ID\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct { option_id: i64 }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const option_id_str = try std.fmt.allocPrint(allocator, "{d}", .{parsed.value.option_id});
    defer allocator.free(option_id_str);

    // Check if poll is still open
    const check_sql = "SELECT ends_at FROM polls WHERE id = ?";
    const check_rows = db.query(EndsAtRow, allocator, check_sql, &[_][]const u8{poll_id_str}) catch |err| {
        std.log.err("Failed to check poll: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to check poll\"}");
        return;
    };
    defer db.freeRows(EndsAtRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Poll not found\"}");
        return;
    }

    // Check if already voted
    const voted_sql = "SELECT 1 FROM poll_votes WHERE poll_id = ? AND user_id = ?";
    const voted_rows = db.query(VotedRow, allocator, voted_sql, &[_][]const u8{
        poll_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to check vote: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to check vote\"}");
        return;
    };
    defer db.freeRows(VotedRow, allocator, voted_rows);

    if (voted_rows.len > 0) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Already voted\"}");
        return;
    }

    // Record vote
    try db.execute(
        "INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)",
        &[_][]const u8{ poll_id_str, option_id_str, user_id_str },
    );

    // Update vote count
    try db.execute(
        "UPDATE poll_options SET vote_count = vote_count + 1 WHERE id = ?",
        &[_][]const u8{option_id_str},
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"Vote recorded\"}");
}

pub fn getPollResults(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const poll_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing poll ID\"}");
        return;
    };

    const sql =
        \\SELECT po.id, po.option_text, po.position, po.vote_count,
        \\  (SELECT SUM(vote_count) FROM poll_options WHERE poll_id = po.poll_id) as total_votes
        \\FROM poll_options po
        \\WHERE po.poll_id = ?
        \\ORDER BY po.position
    ;

    const Result = struct {
        id: i64,
        option_text: []const u8,
        position: i64,
        vote_count: i64,
        total_votes: i64,
    };

    const rows = db.query(Result, allocator, sql, &[_][]const u8{poll_id_str}) catch |err| {
        std.log.err("Failed to get poll results: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get poll results\"}");
        return;
    };
    defer db.freeRows(Result, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"options\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.body.writer().print(",", .{});
        const percentage = if (row.total_votes > 0) @as(f64, @floatFromInt(row.vote_count)) / @as(f64, @floatFromInt(row.total_votes)) * 100.0 else 0.0;
        try res.body.writer().print("{{\"id\":{d},\"option_text\":\"{s}\",\"position\":{d},\"vote_count\":{d},\"percentage\":{d:.1}}}", .{
            row.id, row.option_text, row.position, row.vote_count, percentage,
        });
    }
    const total = if (rows.len > 0) rows[0].total_votes else 0;
    try res.body.writer().print("],\"total_votes\":{d}}}", .{total});
}
