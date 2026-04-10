const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

const DummyRow = struct { _dummy: i64 };
const CountRow = struct { count: i64 };

const ConversationWithParticipants = struct {
    id: i64,
    created_at: []const u8,
    updated_at: []const u8,
    participants: []const u8,
    last_message: ?[]const u8,
    unread_count: i64,
};

const Message = struct {
    id: i64,
    conversation_id: i64,
    sender_id: i64,
    sender_username: []const u8,
    sender_display_name: ?[]const u8,
    content: []const u8,
    media_urls: ?[]const u8,
    read: i64,
    created_at: []const u8,
};

pub fn getConversations(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT c.id, c.created_at, c.updated_at,
        \\  (SELECT GROUP_CONCAT(u.username) 
        \\   FROM conversation_participants cp2 
        \\   JOIN users u ON cp2.user_id = u.id 
        \\   WHERE cp2.conversation_id = c.id AND cp2.user_id != ?) as participants,
        \\  (SELECT content FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message,
        \\  (SELECT COUNT(*) FROM messages WHERE conversation_id = c.id AND sender_id != ? AND read = 0) as unread_count
        \\FROM conversations c
        \\JOIN conversation_participants cp ON c.id = cp.conversation_id
        \\WHERE cp.user_id = ?
        \\ORDER BY c.updated_at DESC
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(ConversationWithParticipants, allocator, sql, &[_][]const u8{
        user_id_str,
        user_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to get conversations: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get conversations\"}");
        return;
    };
    defer db.freeRows(ConversationWithParticipants, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"conversations\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_participants = try json_utils.escapeJson(allocator, row.participants);
        defer allocator.free(escaped_participants);
        const escaped_updated = try json_utils.escapeJson(allocator, row.updated_at);
        defer allocator.free(escaped_updated);
        try res.bodyWriter().print("{{\"id\":{d},\"created_at\":\"{s}\",\"updated_at\":\"{s}\",\"participants\":\"{s}\"", .{
            row.id, row.created_at, escaped_updated, escaped_participants,
        });
        if (row.last_message) |msg| {
            const escaped_msg = try json_utils.escapeJson(allocator, msg);
            defer allocator.free(escaped_msg);
            try res.bodyWriter().print(",\"last_message\":\"{s}\"", .{escaped_msg});
        }
        try res.bodyWriter().print(",\"unread_count\":{d}}}", .{row.unread_count});
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn createConversation(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct { participant_ids: []i64 }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    // Create conversation
    try db.execute("INSERT INTO conversations DEFAULT VALUES", &[_][]const u8{});
    const conversation_id = db.lastInsertRowId();

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const convo_id_str = try std.fmt.allocPrint(allocator, "{d}", .{conversation_id});
    defer allocator.free(convo_id_str);

    // Add creator as participant
    try db.execute(
        "INSERT INTO conversation_participants (conversation_id, user_id) VALUES (?, ?)",
        &[_][]const u8{ convo_id_str, user_id_str },
    );

    // Add other participants
    for (parsed.value.participant_ids) |pid| {
        if (pid != user_id) {
            const pid_str = try std.fmt.allocPrint(allocator, "{d}", .{pid});
            defer allocator.free(pid_str);
            try db.execute(
                "INSERT INTO conversation_participants (conversation_id, user_id) VALUES (?, ?)",
                &[_][]const u8{ convo_id_str, pid_str },
            );
        }
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"id\":{d},\"message\":\"Conversation created\"}}", .{conversation_id});
}

pub fn getMessages(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const conversation_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing conversation ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Check if user is participant
    const check_sql = "SELECT 1 FROM conversation_participants WHERE conversation_id = ? AND user_id = ?";
    const check_rows = db.query(DummyRow, allocator, check_sql, &[_][]const u8{
        conversation_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to check participation: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check participation\"}");
        return;
    };
    defer db.freeRows(DummyRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not a participant in this conversation\"}");
        return;
    }

    const sql =
        \\SELECT m.id, m.conversation_id, m.sender_id, u.username as sender_username,
        \\  u.display_name as sender_display_name, m.content, m.media_urls, m.read, m.created_at
        \\FROM messages m
        \\JOIN users u ON m.sender_id = u.id
        \\WHERE m.conversation_id = ?
        \\ORDER BY m.created_at DESC
        \\LIMIT 50
    ;

    const rows = db.query(Message, allocator, sql, &[_][]const u8{conversation_id_str}) catch |err| {
        std.log.err("Failed to get messages: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get messages\"}");
        return;
    };
    defer db.freeRows(Message, allocator, rows);

    // Mark messages as read
    try db.execute(
        "UPDATE messages SET read = 1 WHERE conversation_id = ? AND sender_id != ? AND read = 0",
        &[_][]const u8{ conversation_id_str, user_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"messages\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_username = try json_utils.escapeJson(allocator, row.sender_username);
        defer allocator.free(escaped_username);
        try res.bodyWriter().print("{{\"id\":{d},\"conversation_id\":{d},\"sender_id\":{d},\"sender_username\":\"{s}\"", .{
            row.id, row.conversation_id, row.sender_id, escaped_username,
        });
        if (row.sender_display_name) |name| {
            const escaped_name = try json_utils.escapeJson(allocator, name);
            defer allocator.free(escaped_name);
            try res.bodyWriter().print(",\"sender_display_name\":\"{s}\"", .{escaped_name});
        }
        const escaped_content = try json_utils.escapeJson(allocator, row.content);
        defer allocator.free(escaped_content);
        try res.bodyWriter().print(",\"content\":\"{s}\"", .{escaped_content});
        if (row.media_urls) |urls| {
            const escaped_urls = try json_utils.escapeJson(allocator, urls);
            defer allocator.free(escaped_urls);
            try res.bodyWriter().print(",\"media_urls\":\"{s}\"", .{escaped_urls});
        }
        try res.bodyWriter().print(",\"read\":{d},\"created_at\":\"{s}\"}}", .{ row.read, row.created_at });
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn sendMessage(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const conversation_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing conversation ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Check if user is participant
    const check_sql = "SELECT 1 FROM conversation_participants WHERE conversation_id = ? AND user_id = ?";
    const check_rows = db.query(DummyRow, allocator, check_sql, &[_][]const u8{
        conversation_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to check participation: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check participation\"}");
        return;
    };
    defer db.freeRows(DummyRow, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not a participant in this conversation\"}");
        return;
    }

    const body = req.body;

    const parsed = std.json.parseFromSlice(struct { content: []const u8, media_urls: ?[]const u8 }, allocator, body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    try db.execute(
        "INSERT INTO messages (conversation_id, sender_id, content, media_urls) VALUES (?, ?, ?, ?)",
        &[_][]const u8{
            conversation_id_str,
            user_id_str,
            parsed.value.content,
            parsed.value.media_urls orelse "",
        },
    );

    // Update conversation timestamp
    try db.execute(
        "UPDATE conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        &[_][]const u8{conversation_id_str},
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"id\":{d},\"message\":\"Message sent\"}}", .{db.lastInsertRowId()});
}

pub fn getUnreadCount(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql =
        \\SELECT COUNT(*) as count
        \\FROM messages m
        \\JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
        \\WHERE cp.user_id = ? AND m.sender_id != ? AND m.read = 0
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(CountRow, allocator, sql, &[_][]const u8{
        user_id_str,
        user_id_str,
    }) catch |err| {
        std.log.err("Failed to get unread count: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get unread count\"}");
        return;
    };
    defer db.freeRows(CountRow, allocator, rows);

    const count = if (rows.len > 0) rows[0].count else 0;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"unread_count\":{d}}}", .{count});
}
