const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

const OwnerIdRow = struct { owner_id: i64 };
const DummyRow = struct { _dummy: i64 };

const UserList = struct {
    id: i64,
    owner_id: i64,
    name: []const u8,
    description: ?[]const u8,
    is_private: i64,
    member_count: i64,
    created_at: []const u8,
};

const ListMember = struct {
    id: i64,
    username: []const u8,
    display_name: ?[]const u8,
    avatar_url: ?[]const u8,
    added_at: []const u8,
};

pub fn getMyLists(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT l.id, l.owner_id, l.name, l.description, l.is_private,
        \\  (SELECT COUNT(*) FROM list_members WHERE list_id = l.id) as member_count,
        \\  l.created_at
        \\FROM user_lists l
        \\WHERE l.owner_id = ?
        \\ORDER BY l.created_at DESC
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(UserList, allocator, sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get lists: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get lists\"}");
        return;
    };
    defer db.freeRows(UserList, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"lists\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_name = try json_utils.escapeJson(allocator, row.name);
        defer allocator.free(escaped_name);
        const escaped_created_at = try json_utils.escapeJson(allocator, row.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"owner_id\":{d},\"name\":\"{s}\"", .{
            row.id, row.owner_id, escaped_name,
        });
        if (row.description) |desc| {
            const escaped_desc = try json_utils.escapeJson(allocator, desc);
            defer allocator.free(escaped_desc);
            try res.bodyWriter().print(",\"description\":\"{s}\"", .{escaped_desc});
        }
        try res.bodyWriter().print(",\"is_private\":{d},\"member_count\":{d},\"created_at\":\"{s}\"}}", .{
            row.is_private, row.member_count, escaped_created_at,
        });
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn createList(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        description: ?[]const u8,
        is_private: ?bool,
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
        "INSERT INTO user_lists (owner_id, name, description, is_private) VALUES (?, ?, ?, ?)",
        &[_][]const u8{
            user_id_str,
            parsed.value.name,
            parsed.value.description orelse "",
            if (parsed.value.is_private orelse false) "1" else "0",
        },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"id\":{d},\"message\":\"List created\"}}", .{db.lastInsertRowId()});
}

pub fn getList(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const list_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing list ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Get list info
    const list_sql =
        \\SELECT l.id, l.owner_id, l.name, l.description, l.is_private,
        \\  (SELECT COUNT(*) FROM list_members WHERE list_id = l.id) as member_count,
        \\  l.created_at
        \\FROM user_lists l
        \\WHERE l.id = ? AND (l.is_private = 0 OR l.owner_id = ?)
    ;

    const list_rows = db.query(UserList, allocator, list_sql, &[_][]const u8{
        list_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to get list: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get list\"}");
        return;
    };
    defer db.freeRows(UserList, allocator, list_rows);

    if (list_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"List not found or private\"}");
        return;
    }

    // Get members
    const members_sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url, lm.added_at
        \\FROM list_members lm
        \\JOIN users u ON lm.user_id = u.id
        \\WHERE lm.list_id = ?
        \\ORDER BY lm.added_at DESC
    ;

    const member_rows = db.query(ListMember, allocator, members_sql, &[_][]const u8{list_id_str}) catch |err| {
        std.log.err("Failed to get members: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get members\"}");
        return;
    };
    defer db.freeRows(ListMember, allocator, member_rows);

    res.headers.put("Content-Type", "application/json") catch {};
    const list = list_rows[0];
    const escaped_list_name = try json_utils.escapeJson(allocator, list.name);
    defer allocator.free(escaped_list_name);
    const escaped_list_created_at = try json_utils.escapeJson(allocator, list.created_at);
    defer allocator.free(escaped_list_created_at);
    try res.bodyWriter().print("{{\"list\":{{\"id\":{d},\"owner_id\":{d},\"name\":\"{s}\"", .{
        list.id, list.owner_id, escaped_list_name,
    });
    if (list.description) |desc| {
        const escaped_list_desc = try json_utils.escapeJson(allocator, desc);
        defer allocator.free(escaped_list_desc);
        try res.bodyWriter().print(",\"description\":\"{s}\"", .{escaped_list_desc});
    }
    try res.bodyWriter().print(",\"is_private\":{d},\"member_count\":{d},\"created_at\":\"{s}\"}},\"members\":[", .{
        list.is_private, list.member_count, escaped_list_created_at,
    });
    for (member_rows, 0..) |member, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_username = try json_utils.escapeJson(allocator, member.username);
        defer allocator.free(escaped_username);
        const escaped_added_at = try json_utils.escapeJson(allocator, member.added_at);
        defer allocator.free(escaped_added_at);
        try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\"", .{
            member.id, escaped_username,
        });
        if (member.display_name) |name| {
            const escaped_display_name = try json_utils.escapeJson(allocator, name);
            defer allocator.free(escaped_display_name);
            try res.bodyWriter().print(",\"display_name\":\"{s}\"", .{escaped_display_name});
        }
        if (member.avatar_url) |url| {
            const escaped_avatar_url = try json_utils.escapeJson(allocator, url);
            defer allocator.free(escaped_avatar_url);
            try res.bodyWriter().print(",\"avatar_url\":\"{s}\"", .{escaped_avatar_url});
        }
        try res.bodyWriter().print(",\"added_at\":\"{s}\"}}", .{escaped_added_at});
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn deleteList(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const list_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing list ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT owner_id FROM user_lists WHERE id = ?";
    const check_rows = db.query(OwnerIdRow, allocator, check_sql, &[_][]const u8{list_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(OwnerIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"List not found\"}");
        return;
    }

    if (check_rows[0].owner_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not authorized to delete this list\"}");
        return;
    }

    try db.execute("DELETE FROM user_lists WHERE id = ?", &[_][]const u8{list_id_str});
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"message\":\"List deleted\"}");
}

pub fn addMember(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const list_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing list ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT owner_id FROM user_lists WHERE id = ?";
    const check_rows = db.query(OwnerIdRow, allocator, check_sql, &[_][]const u8{list_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(OwnerIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"List not found\"}");
        return;
    }

    if (check_rows[0].owner_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not authorized to modify this list\"}");
        return;
    }

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct { user_id: i64 }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const member_id_str = try std.fmt.allocPrint(allocator, "{d}", .{parsed.value.user_id});
    defer allocator.free(member_id_str);

    try db.execute(
        "INSERT INTO list_members (list_id, user_id) VALUES (?, ?)",
        &[_][]const u8{ list_id_str, member_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"message\":\"Member added\"}");
}

pub fn removeMember(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const list_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing list ID\"}");
        return;
    };

    const member_id_str = req.params.get("user_id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing user ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT owner_id FROM user_lists WHERE id = ?";
    const check_rows = db.query(OwnerIdRow, allocator, check_sql, &[_][]const u8{list_id_str}) catch |err| {
        std.log.err("Failed to check ownership: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check ownership\"}");
        return;
    };
    defer db.freeRows(OwnerIdRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"List not found\"}");
        return;
    }

    if (check_rows[0].owner_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not authorized to modify this list\"}");
        return;
    }

    try db.execute(
        "DELETE FROM list_members WHERE list_id = ? AND user_id = ?",
        &[_][]const u8{ list_id_str, member_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"message\":\"Member removed\"}");
}

pub fn getListTimeline(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const list_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing list ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Check access
    const check_sql =
        \\SELECT 1 FROM user_lists l
        \\WHERE l.id = ? AND (l.is_private = 0 OR l.owner_id = ?)
    ;
    const check_rows = db.query(DummyRow, allocator, check_sql, &[_][]const u8{
        list_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to check access: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check access\"}");
        return;
    };
    defer db.freeRows(DummyRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"List not found or private\"}");
        return;
    }

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\  p.content, p.media_urls, p.reply_to_id, p.created_at,
        \\  (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\  (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\  (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\  EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = ?) as is_liked,
        \\  EXISTS(SELECT 1 FROM reposts WHERE post_id = p.id AND user_id = ?) as is_reposted
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\JOIN list_members lm ON p.user_id = lm.user_id
        \\WHERE lm.list_id = ?
        \\ORDER BY p.created_at DESC
        \\LIMIT 50
    ;

    const Post = struct {
        id: i64,
        user_id: i64,
        username: []const u8,
        display_name: ?[]const u8,
        avatar_url: ?[]const u8,
        content: []const u8,
        media_urls: ?[]const u8,
        reply_to_id: ?i64,
        created_at: []const u8,
        likes_count: i64,
        comments_count: i64,
        reposts_count: i64,
        is_liked: i64,
        is_reposted: i64,
    };

    const rows = db.query(Post, allocator, sql, &[_][]const u8{
        user_id_str,
        user_id_str,
        list_id_str,
    }) catch |err| {
        std.log.err("Failed to get list timeline: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get list timeline\"}");
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"posts\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_username = try json_utils.escapeJson(allocator, row.username);
        defer allocator.free(escaped_username);
        const escaped_content = try json_utils.escapeJson(allocator, row.content);
        defer allocator.free(escaped_content);
        const escaped_created_at = try json_utils.escapeJson(allocator, row.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\"", .{
            row.id, row.user_id, escaped_username,
        });
        if (row.display_name) |name| {
            const escaped_display_name = try json_utils.escapeJson(allocator, name);
            defer allocator.free(escaped_display_name);
            try res.bodyWriter().print(",\"display_name\":\"{s}\"", .{escaped_display_name});
        }
        if (row.avatar_url) |url| {
            const escaped_avatar_url = try json_utils.escapeJson(allocator, url);
            defer allocator.free(escaped_avatar_url);
            try res.bodyWriter().print(",\"avatar_url\":\"{s}\"", .{escaped_avatar_url});
        }
        try res.bodyWriter().print(",\"content\":\"{s}\"", .{escaped_content});
        if (row.media_urls) |urls| {
            const escaped_media_urls = try json_utils.escapeJson(allocator, urls);
            defer allocator.free(escaped_media_urls);
            try res.bodyWriter().print(",\"media_urls\":\"{s}\"", .{escaped_media_urls});
        } else {
            try res.bodyWriter().print(",\"media_urls\":\"\"", .{});
        }
        if (row.reply_to_id) |reply| {
            try res.bodyWriter().print(",\"reply_to_id\":{d}", .{reply});
        }
        try res.bodyWriter().print(",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{d},\"is_reposted\":{d}}}", .{
            escaped_created_at, row.likes_count, row.comments_count, row.reposts_count, row.is_liked, row.is_reposted,
        });
    }
    try res.bodyWriter().print("]}}", .{});
}
