const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

const UserIdRow = struct { user_id: i64 };

const ScheduledPost = struct {
    id: i64,
    user_id: i64,
    content: []const u8,
    media_urls: ?[]const u8,
    scheduled_at: []const u8,
    created_at: []const u8,
    is_posted: i64,
};

pub fn getScheduledPosts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT id, user_id, content, media_urls, scheduled_at, created_at, is_posted
        \\FROM scheduled_posts
        \\WHERE user_id = ? AND is_posted = 0
        \\ORDER BY scheduled_at ASC
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(ScheduledPost, allocator, sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get scheduled posts: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get scheduled posts\"}");
        return;
    };
    defer db.freeRows(ScheduledPost, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"scheduled_posts\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_content = try json_utils.escapeJson(allocator, row.content);
        defer allocator.free(escaped_content);
        const escaped_scheduled_at = try json_utils.escapeJson(allocator, row.scheduled_at);
        defer allocator.free(escaped_scheduled_at);
        const escaped_created_at = try json_utils.escapeJson(allocator, row.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"content\":\"{s}\"", .{
            row.id, row.user_id, escaped_content,
        });
        if (row.media_urls) |urls| {
            const escaped_media_urls = try json_utils.escapeJson(allocator, urls);
            defer allocator.free(escaped_media_urls);
            try res.bodyWriter().print(",\"media_urls\":\"{s}\"", .{escaped_media_urls});
        }
        try res.bodyWriter().print(",\"scheduled_at\":\"{s}\",\"created_at\":\"{s}\",\"is_posted\":{d}}}", .{
            escaped_scheduled_at, escaped_created_at, row.is_posted,
        });
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn createScheduledPost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct {
        content: []const u8,
        media_urls: ?[]const u8,
        scheduled_at: []const u8,
    }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    try db.execute(
        "INSERT INTO scheduled_posts (user_id, content, media_urls, scheduled_at) VALUES (?, ?, ?, ?)",
        &[_][]const u8{
            user_id_str,
            parsed.value.content,
            parsed.value.media_urls orelse "",
            parsed.value.scheduled_at,
        },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"id\":{d},\"message\":\"Scheduled post created\"}}", .{db.lastInsertRowId()});
}

pub fn deleteScheduledPost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const post_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing post ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT user_id FROM scheduled_posts WHERE id = ?";
    const check_rows = db.query(UserIdRow, allocator, check_sql, &[_][]const u8{post_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Scheduled post not found\"}");
        return;
    }

    if (check_rows[0].user_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not authorized\"}");
        return;
    }

    try db.execute("DELETE FROM scheduled_posts WHERE id = ?", &[_][]const u8{post_id_str});

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"message\":\"Scheduled post deleted\"}");
}
