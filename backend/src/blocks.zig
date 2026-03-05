const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");

const UserIdRow = struct { id: i64 };
const OwnerIdRow = struct { owner_id: i64 };
const DummyRow = struct { _dummy: i64 };

pub fn blockUser(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const blocked_username = req.params.get("username") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing username\"}");
        return;
    };

    // Get blocked user ID
    const user_sql = "SELECT id FROM users WHERE username = ?";
    const user_rows = db.query(UserIdRow, allocator, user_sql, &[_][]const u8{blocked_username}) catch |err| {
        std.log.err("Failed to get user: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get user\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, user_rows);

    if (user_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    }

    const blocked_id = user_rows[0].id;
    if (blocked_id == user_id) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Cannot block yourself\"}");
        return;
    }

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const blocked_id_str = try std.fmt.allocPrint(allocator, "{d}", .{blocked_id});
    defer allocator.free(blocked_id_str);

    // Remove any existing follow relationship
    try db.execute(
        "DELETE FROM follows WHERE follower_id = ? AND following_id = ?",
        &[_][]const u8{ user_id_str, blocked_id_str },
    );
    try db.execute(
        "DELETE FROM follows WHERE follower_id = ? AND following_id = ?",
        &[_][]const u8{ blocked_id_str, user_id_str },
    );

    // Add block
    try db.execute(
        "INSERT OR IGNORE INTO blocks (blocker_id, blocked_id) VALUES (?, ?)",
        &[_][]const u8{ user_id_str, blocked_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"User blocked\"}");
}

pub fn unblockUser(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const blocked_username = req.params.get("username") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing username\"}");
        return;
    };

    // Get blocked user ID
    const user_sql = "SELECT id FROM users WHERE username = ?";
    const user_rows = db.query(UserIdRow, allocator, user_sql, &[_][]const u8{blocked_username}) catch |err| {
        std.log.err("Failed to get user: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get user\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, user_rows);

    if (user_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    }

    const blocked_id = user_rows[0].id;
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const blocked_id_str = try std.fmt.allocPrint(allocator, "{d}", .{blocked_id});
    defer allocator.free(blocked_id_str);

    try db.execute(
        "DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?",
        &[_][]const u8{ user_id_str, blocked_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"User unblocked\"}");
}

pub fn getBlockedUsers(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url, b.created_at
        \\FROM blocks b
        \\JOIN users u ON b.blocked_id = u.id
        \\WHERE b.blocker_id = ?
        \\ORDER BY b.created_at DESC
    ;

    const BlockedUser = struct {
        id: i64,
        username: []const u8,
        display_name: ?[]const u8,
        avatar_url: ?[]const u8,
        created_at: []const u8,
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(BlockedUser, allocator, sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get blocked users: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get blocked users\"}");
        return;
    };
    defer db.freeRows(BlockedUser, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"blocked_users\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.body.writer().print(",", .{});
        try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\"", .{
            row.id, row.username,
        });
        if (row.display_name) |name| {
            try res.body.writer().print(",\"display_name\":\"{s}\"", .{name});
        }
        if (row.avatar_url) |url| {
            try res.body.writer().print(",\"avatar_url\":\"{s}\"", .{url});
        }
        try res.body.writer().print(",\"blocked_at\":\"{s}\"}}", .{row.created_at});
    }
    try res.body.writer().print("]}}", .{});
}

pub fn muteUser(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const muted_username = req.params.get("username") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing username\"}");
        return;
    };

    // Get muted user ID
    const user_sql = "SELECT id FROM users WHERE username = ?";
    const user_rows = db.query(UserIdRow, allocator, user_sql, &[_][]const u8{muted_username}) catch |err| {
        std.log.err("Failed to get user: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get user\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, user_rows);

    if (user_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    }

    const muted_id = user_rows[0].id;
    if (muted_id == user_id) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Cannot mute yourself\"}");
        return;
    }

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const muted_id_str = try std.fmt.allocPrint(allocator, "{d}", .{muted_id});
    defer allocator.free(muted_id_str);

    try db.execute(
        "INSERT OR IGNORE INTO mutes (muter_id, muted_id) VALUES (?, ?)",
        &[_][]const u8{ user_id_str, muted_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"User muted\"}");
}

pub fn unmuteUser(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const muted_username = req.params.get("username") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing username\"}");
        return;
    };

    // Get muted user ID
    const user_sql = "SELECT id FROM users WHERE username = ?";
    const user_rows = db.query(UserIdRow, allocator, user_sql, &[_][]const u8{muted_username}) catch |err| {
        std.log.err("Failed to get user: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get user\"}");
        return;
    };
    defer db.freeRows(UserIdRow, allocator, user_rows);

    if (user_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    }

    const muted_id = user_rows[0].id;
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const muted_id_str = try std.fmt.allocPrint(allocator, "{d}", .{muted_id});
    defer allocator.free(muted_id_str);

    try db.execute(
        "DELETE FROM mutes WHERE muter_id = ? AND muted_id = ?",
        &[_][]const u8{ user_id_str, muted_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"message\":\"User unmuted\"}");
}

pub fn getMutedUsers(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url, m.created_at
        \\FROM mutes m
        \\JOIN users u ON m.muted_id = u.id
        \\WHERE m.muter_id = ?
        \\ORDER BY m.created_at DESC
    ;

    const MutedUser = struct {
        id: i64,
        username: []const u8,
        display_name: ?[]const u8,
        avatar_url: ?[]const u8,
        created_at: []const u8,
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(MutedUser, allocator, sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get muted users: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get muted users\"}");
        return;
    };
    defer db.freeRows(MutedUser, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"muted_users\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.body.writer().print(",", .{});
        try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\"", .{
            row.id, row.username,
        });
        if (row.display_name) |name| {
            try res.body.writer().print(",\"display_name\":\"{s}\"", .{name});
        }
        if (row.avatar_url) |url| {
            try res.body.writer().print(",\"avatar_url\":\"{s}\"", .{url});
        }
        try res.body.writer().print(",\"muted_at\":\"{s}\"}}", .{row.created_at});
    }
    try res.body.writer().print("]}}", .{});
}

pub fn isBlocked(allocator: std.mem.Allocator, user_id: i64, other_id: i64) !bool {
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const other_id_str = try std.fmt.allocPrint(allocator, "{d}", .{other_id});
    defer allocator.free(other_id_str);

    const sql = "SELECT 1 FROM blocks WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)";
    const rows = db.query(DummyRow, allocator, sql, &[_][]const u8{
        user_id_str, other_id_str, other_id_str, user_id_str,
    }) catch |err| {
        std.log.err("Failed to check block: {}", .{err});
        return false;
    };
    defer db.freeRows(DummyRow, allocator, rows);

    return rows.len > 0;
}

pub fn isMuted(allocator: std.mem.Allocator, user_id: i64, other_id: i64) !bool {
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const other_id_str = try std.fmt.allocPrint(allocator, "{d}", .{other_id});
    defer allocator.free(other_id_str);

    const sql = "SELECT 1 FROM mutes WHERE muter_id = ? AND muted_id = ?";
    const rows = db.query(DummyRow, allocator, sql, &[_][]const u8{
        user_id_str, other_id_str,
    }) catch |err| {
        std.log.err("Failed to check mute: {}", .{err});
        return false;
    };
    defer db.freeRows(DummyRow, allocator, rows);

    return rows.len > 0;
}
