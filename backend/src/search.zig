const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

pub fn searchUsers(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract query from URL
    const query_start = std.mem.indexOf(u8, req.path, "?q=");
    if (query_start == null) {
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("[]");
        return;
    }

    const query = req.path[query_start.? + 3 ..];
    if (query.len == 0) {
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("[]");
        return;
    }

    const sql =
        \\SELECT id, username, display_name, avatar_url
        \\FROM users
        \\WHERE username LIKE ? OR display_name LIKE ?
        \\ORDER BY username
        \\LIMIT 20
    ;

    const User = struct {
        id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
    };

    const search_pattern = try std.fmt.allocPrint(allocator, "%{s}%", .{query});
    defer allocator.free(search_pattern);

    const params = [_][]const u8{ search_pattern, search_pattern };

    const rows = db.query(User, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to search users\"}");
        return;
    };
    defer db.freeRows(User, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("[");

    for (rows, 0..) |user, idx| {
        if (idx > 0) try res.append(",");
        const escaped_username = try json_utils.escapeJson(allocator, user.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, user.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_avatar_url = try json_utils.escapeJson(allocator, user.avatar_url);
        defer allocator.free(escaped_avatar_url);
        try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"avatar_url\":\"{s}\"}}", .{ user.id, escaped_username, escaped_display_name, escaped_avatar_url });
    }

    try res.append("]");
}

pub fn searchPosts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract query from URL
    const query_start = std.mem.indexOf(u8, req.path, "?q=");
    if (query_start == null) {
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("[]");
        return;
    }

    const query = req.path[query_start.? + 3 ..];
    if (query.len == 0) {
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("[]");
        return;
    }

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM bookmarks WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_bookmarked
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE p.content LIKE ?
        \\ORDER BY p.created_at DESC
        \\LIMIT 50
    ;

    const Post = struct {
        id: i64,
        user_id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
        content: []const u8,
        media_urls: ?[]const u8,
        reply_to_id: ?i64,
        created_at: []const u8,
        likes_count: i64,
        comments_count: i64,
        reposts_count: i64,
        is_liked: bool,
        is_reposted: bool,
        is_bookmarked: bool,
    };

    const search_pattern = try std.fmt.allocPrint(allocator, "%{s}%", .{query});
    defer allocator.free(search_pattern);

    const current_user_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(current_user_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, current_user_str, has_user, current_user_str, has_user, current_user_str, search_pattern };

    const rows = db.query(Post, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to search posts\"}");
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("[");

    for (rows, 0..) |post, idx| {
        if (idx > 0) try res.append(",");
        const escaped_content = try json_utils.escapeJson(allocator, post.content);
        defer allocator.free(escaped_content);
        const escaped_username = try json_utils.escapeJson(allocator, post.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, post.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{s},\"is_reposted\":{s},\"is_bookmarked\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false", if (post.is_bookmarked) "true" else "false" });
    }

    try res.append("]");
}
