const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");

const UserIdRow = struct { user_id: i64 };

const Draft = struct {
    id: i64,
    user_id: i64,
    content: []const u8,
    media_urls: ?[]const u8,
    created_at: []const u8,
    updated_at: []const u8,
};

pub fn getDrafts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT id, user_id, content, media_urls, created_at, updated_at
        \\FROM drafts
        \\WHERE user_id = ?
        \\ORDER BY updated_at DESC
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(Draft, allocator, sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get drafts: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get drafts\"}");
        return;
    };
    defer db.freeRows(Draft, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"drafts\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.body.writer().print(",", .{});
        try res.body.writer().print("{{\"id\":{d},\"user_id\":{d},\"content\":\"{s}\"", .{
            row.id, row.user_id, row.content,
        });
        if (row.media_urls) |urls| {
            try res.body.writer().print(",\"media_urls\":\"{s}\"", .{urls});
        }
        try res.body.writer().print(",\"created_at\":\"{s}\",\"updated_at\":\"{s}\"}}", .{
            row.created_at, row.updated_at,
        });
    }
    try res.body.writer().print("]}}", .{});
}

pub fn createDraft(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct {
        content: []const u8,
        media_urls: ?[]const u8,
    }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    try db.execute(
        "INSERT INTO drafts (user_id, content, media_urls) VALUES (?, ?, ?)",
        &[_][]const u8{
            user_id_str,
            parsed.value.content,
            parsed.value.media_urls orelse "",
        },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"id\":{d},\"message\":\"Draft created\"}}", .{db.lastInsertRowId()});
}

pub fn updateDraft(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const draft_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing draft ID\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct {
        content: []const u8,
        media_urls: ?[]const u8,
    }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT user_id FROM drafts WHERE id = ?";
    const check_rows = db.query(UserIdRow, allocator, check_sql, &[_][]const u8{draft_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Draft not found\"}");
        return;
    }

    if (check_rows[0].user_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Not authorized\"}");
        return;
    }

    try db.execute(
        "UPDATE drafts SET content = ?, media_urls = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        &[_][]const u8{
            parsed.value.content,
            parsed.value.media_urls orelse "",
            draft_id_str,
        },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"Draft updated\"}");
}

pub fn deleteDraft(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const draft_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing draft ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT user_id FROM drafts WHERE id = ?";
    const check_rows = db.query(UserIdRow, allocator, check_sql, &[_][]const u8{draft_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Draft not found\"}");
        return;
    }

    if (check_rows[0].user_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Not authorized\"}");
        return;
    }

    try db.execute("DELETE FROM drafts WHERE id = ?", &[_][]const u8{draft_id_str});

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"Draft deleted\"}");
}
