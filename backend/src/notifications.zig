const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

pub const Notification = struct {
    id: i64,
    user_id: i64,
    actor_id: i64,
    actor_username: []const u8,
    actor_display_name: []const u8,
    actor_avatar_url: []const u8,
    type: []const u8,
    post_id: ?i64,
    read: bool,
    created_at: []const u8,
};

pub fn create(user_id: i64, actor_id: i64, notif_type: []const u8, post_id: ?i64) !void {
    const sql = "INSERT INTO notifications (user_id, actor_id, type, post_id) VALUES (?, ?, ?, ?)";

    const user_id_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{user_id});
    defer std.heap.page_allocator.free(user_id_str);

    const actor_id_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{actor_id});
    defer std.heap.page_allocator.free(actor_id_str);

    const post_id_str = if (post_id) |id| try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{id}) else "";
    defer if (post_id != null) std.heap.page_allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, actor_id_str, notif_type, post_id_str }) catch |err| {
        std.log.err("Failed to create notification: {any}", .{err});
    };
}

pub fn list(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT n.id, n.user_id, n.actor_id, u.username as actor_username, 
        \\       u.display_name as actor_display_name, u.avatar_url as actor_avatar_url,
        \\       n.type, n.post_id, n.read, n.created_at
        \\FROM notifications n
        \\JOIN users u ON n.actor_id = u.id
        \\WHERE n.user_id = ?
        \\ORDER BY n.created_at DESC
        \\LIMIT 50
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(Notification, allocator, sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch notifications\"}");
        return;
    };
    defer db.freeRows(Notification, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("[");

    for (rows, 0..) |notif, i| {
        if (i > 0) try res.append(",");
        const escaped_type = try json_utils.escapeJson(allocator, notif.type);
        defer allocator.free(escaped_type);
        const escaped_actor_username = try json_utils.escapeJson(allocator, notif.actor_username);
        defer allocator.free(escaped_actor_username);
        const escaped_actor_display_name = try json_utils.escapeJson(allocator, notif.actor_display_name);
        defer allocator.free(escaped_actor_display_name);
        const escaped_created_at = try json_utils.escapeJson(allocator, notif.created_at);
        defer allocator.free(escaped_created_at);

        const post_id_str = if (notif.post_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null";
        defer if (notif.post_id != null) allocator.free(post_id_str);

        try res.bodyWriter().print("{{\"id\":{d},\"actor_id\":{d},\"actor_username\":\"{s}\",\"actor_display_name\":\"{s}\",\"type\":\"{s}\",\"post_id\":{s},\"read\":{s},\"created_at\":\"{s}\"}}", .{ notif.id, notif.actor_id, escaped_actor_username, escaped_actor_display_name, escaped_type, post_id_str, if (notif.read) "true" else "false", escaped_created_at });
    }

    try res.append("]");
}

pub fn markAsRead(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract notification ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var notif_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 4) {
            notif_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (notif_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid notification ID\"}");
        return;
    }

    const sql = "UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?";
    const notif_id_str = try std.fmt.allocPrint(allocator, "{d}", .{notif_id.?});
    defer allocator.free(notif_id_str);
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    db.execute(sql, &[_][]const u8{ notif_id_str, user_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to mark notification as read\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"read\":true}");
}

pub fn markAllAsRead(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql = "UPDATE notifications SET read = 1 WHERE user_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    db.execute(sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to mark notifications as read\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"read\":true}");
}

pub fn getUnreadCount(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql = "SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND read = 0";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const CountResult = struct {
        count: i64,
    };

    const rows = db.query(CountResult, allocator, sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get unread count\"}");
        return;
    };
    defer db.freeRows(CountResult, allocator, rows);

    const count = if (rows.len > 0) rows[0].count else 0;

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"unread_count\":{d}}}", .{count});
}
