const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");
const notifications = @import("notifications.zig");
const hashtags = @import("hashtags.zig");
const analytics = @import("analytics.zig");

const UserIdRow = struct { user_id: i64 };

pub const Post = struct {
    id: i64,
    user_id: i64,
    username: []const u8,
    display_name: []const u8,
    avatar_url: []const u8,
    content: []const u8,
    media_urls: ?[]const u8,
    reply_to_id: ?i64,
    quote_to_id: ?i64,
    poll_id: ?i64,
    created_at: []const u8,
    likes_count: i64,
    comments_count: i64,
    reposts_count: i64,
    view_count: i64,
    is_liked: bool,
    is_reposted: bool,
    is_bookmarked: bool,
    is_pinned: bool,
};

pub const CreatePostRequest = struct {
    content: []const u8,
    media_urls: ?[]const u8 = null,
    reply_to_id: ?i64 = null,
    quote_to_id: ?i64 = null,
    poll: ?CreatePollRequest = null,
};

pub const CreatePollRequest = struct {
    question: []const u8,
    options: [][]const u8,
    duration_minutes: i64,
};

pub fn create(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const parsed = try std.json.parseFromSlice(CreatePostRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Validate content
    if (body.content.len == 0 or body.content.len > 280) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Content must be between 1 and 280 characters\"}");
        return;
    }

    // Insert post
    const sql =
        \\INSERT INTO posts (user_id, content, media_urls, reply_to_id, quote_to_id) 
        \\VALUES (?, ?, ?, ?, ?)
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const reply_to_str = if (body.reply_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (body.reply_to_id != null) allocator.free(reply_to_str);

    const quote_to_str = if (body.quote_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (body.quote_to_id != null) allocator.free(quote_to_str);

    const params = [_][]const u8{
        user_id_str,
        body.content,
        body.media_urls orelse "",
        reply_to_str,
        quote_to_str,
    };

    db.execute(sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to create post\"}");
        return;
    };

    const post_id = db.lastInsertRowId();

    // Create poll if provided
    if (body.poll) |poll| {
        const poll_sql = "INSERT INTO polls (post_id, question, duration_minutes, ends_at) VALUES (?, ?, ?, datetime('now', '+' || ? || ' minutes'))";
        const poll_question = try json_utils.escapeJson(allocator, poll.question);
        defer allocator.free(poll_question);
        const duration_str = try std.fmt.allocPrint(allocator, "{d}", .{poll.duration_minutes});
        defer allocator.free(duration_str);

        const poll_params = [_][]const u8{
            try std.fmt.allocPrint(allocator, "{d}", .{post_id}),
            poll.question,
            duration_str,
            duration_str,
        };
        defer allocator.free(poll_params[0]);

        db.execute(poll_sql, &poll_params) catch |err| {
            std.log.err("Failed to create poll: {}", .{err});
        };

        const poll_id = db.lastInsertRowId();

        // Insert poll options
        const option_sql = "INSERT INTO poll_options (poll_id, option_text, position) VALUES (?, ?, ?)";
        for (poll.options, 0..) |option, i| {
            const position_str = try std.fmt.allocPrint(allocator, "{d}", .{i});
            defer allocator.free(position_str);
            const poll_id_str = try std.fmt.allocPrint(allocator, "{d}", .{poll_id});
            defer allocator.free(poll_id_str);

            const option_params = [_][]const u8{ poll_id_str, option, position_str };
            db.execute(option_sql, &option_params) catch |err| {
                std.log.err("Failed to create poll option: {}", .{err});
            };
        }

        // Update post with poll_id
        const update_sql = "UPDATE posts SET poll_id = ? WHERE id = ?";
        const poll_id_str = try std.fmt.allocPrint(allocator, "{d}", .{poll_id});
        defer allocator.free(poll_id_str);
        const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
        defer allocator.free(post_id_str);
        const update_params = [_][]const u8{ poll_id_str, post_id_str };
        db.execute(update_sql, &update_params) catch |err| {
            std.log.err("Failed to update post with poll_id: {}", .{err});
        };
    }

    // Extract and save hashtags
    try hashtags.extractAndSaveHashtags(allocator, post_id, body.content);

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_content_create = try json_utils.escapeJson(allocator, body.content);
    defer allocator.free(escaped_content_create);
    try res.bodyWriter().print("{{\"id\":{d},\"content\":\"{s}\",\"created\":true}}", .{ post_id, escaped_content_create });
}

pub fn list(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.quote_to_id, p.poll_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       (SELECT COUNT(*) FROM post_views WHERE post_id = p.id) as view_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM bookmarks WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_bookmarked,
        \\       0 as is_pinned
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\ORDER BY p.created_at DESC
        \\LIMIT 50
    ;

    const user_id_str = if (user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (user_id != null) allocator.free(user_id_str);

    const has_user = if (user_id != null) "1" else "0";
    const params = [_][]const u8{ has_user, user_id_str, has_user, user_id_str, has_user, user_id_str };

    const rows = db.query(Post, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch posts\"}");
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    // Build JSON response manually
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("[");

    for (rows, 0..) |post, i| {
        if (i > 0) try res.append(",");
        const escaped_content = try json_utils.escapeJson(allocator, post.content);
        defer allocator.free(escaped_content);
        const escaped_username = try json_utils.escapeJson(allocator, post.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, post.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_media_urls = try json_utils.escapeJson(allocator, post.media_urls orelse "");
        defer allocator.free(escaped_media_urls);
        const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"media_urls\":\"{s}\",\"reply_to_id\":{s},\"quote_to_id\":{s},\"poll_id\":{s},\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"view_count\":{d},\"is_liked\":{s},\"is_reposted\":{s},\"is_bookmarked\":{s},\"is_pinned\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_media_urls, if (post.reply_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", if (post.quote_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", if (post.poll_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, post.view_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false", if (post.is_bookmarked) "true" else "false", if (post.is_pinned) "true" else "false" });
    }

    try res.append("]");
}

pub fn get(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract post ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.quote_to_id, p.poll_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       (SELECT COUNT(*) FROM post_views WHERE post_id = p.id) as view_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM bookmarks WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_bookmarked,
        \\       0 as is_pinned
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE p.id = ?
    ;

    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    const user_id_str = if (user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (user_id != null) allocator.free(user_id_str);

    const has_user = if (user_id != null) "1" else "0";
    const params = [_][]const u8{ has_user, user_id_str, has_user, user_id_str, has_user, user_id_str, post_id_str };

    const rows = db.query(Post, allocator, sql, &params) catch {
        res.status = 500;
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    if (rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Post not found\"}");
        return;
    }

    const post = rows[0];
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_content = try json_utils.escapeJson(allocator, post.content);
    defer allocator.free(escaped_content);
    const escaped_username = try json_utils.escapeJson(allocator, post.username);
    defer allocator.free(escaped_username);
    const escaped_display_name = try json_utils.escapeJson(allocator, post.display_name);
    defer allocator.free(escaped_display_name);
    const escaped_media_urls = try json_utils.escapeJson(allocator, post.media_urls orelse "");
    defer allocator.free(escaped_media_urls);
    const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
    defer allocator.free(escaped_created_at);
    try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"media_urls\":\"{s}\",\"reply_to_id\":{s},\"quote_to_id\":{s},\"poll_id\":{s},\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"view_count\":{d},\"is_liked\":{s},\"is_reposted\":{s},\"is_bookmarked\":{s},\"is_pinned\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_media_urls, if (post.reply_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", if (post.quote_to_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", if (post.poll_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "null", escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, post.view_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false", if (post.is_bookmarked) "true" else "false", if (post.is_pinned) "true" else "false" });
}

pub fn delete(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "DELETE FROM posts WHERE id = ? AND user_id = ?";
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    db.execute(sql, &[_][]const u8{ post_id_str, user_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to delete post\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"deleted\":true}");
}

pub fn like(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "INSERT OR IGNORE INTO likes (user_id, post_id) VALUES (?, ?)";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to like post\"}");
        return;
    };

    // Create notification for post owner
    const post_owner_sql = "SELECT user_id FROM posts WHERE id = ?";
    const PostOwner = struct {
        user_id: i64,
    };
    const owner_rows = db.query(PostOwner, allocator, post_owner_sql, &[_][]const u8{post_id_str}) catch null;
    if (owner_rows) |rows| {
        defer db.freeRows(PostOwner, allocator, rows);
        if (rows.len > 0 and rows[0].user_id != user_id) {
            try notifications.create(rows[0].user_id, user_id, "like", post_id.?);
        }
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"liked\":true}");
}

pub fn unlike(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "DELETE FROM likes WHERE user_id = ? AND post_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to unlike post\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"unliked\":true}");
}

pub fn comment(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const CommentRequest = struct {
        content: []const u8,
    };

    const parsed = try std.json.parseFromSlice(CommentRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    if (body.content.len == 0 or body.content.len > 280) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Content must be between 1 and 280 characters\"}");
        return;
    }

    const sql = "INSERT INTO comments (user_id, post_id, content) VALUES (?, ?, ?)";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str, body.content }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to add comment\"}");
        return;
    };

    const comment_id = db.lastInsertRowId();

    // Create notification for post owner
    const post_owner_sql = "SELECT user_id FROM posts WHERE id = ?";
    const PostOwner = struct {
        user_id: i64,
    };
    const owner_rows = db.query(PostOwner, allocator, post_owner_sql, &[_][]const u8{post_id_str}) catch null;
    if (owner_rows) |rows| {
        defer db.freeRows(PostOwner, allocator, rows);
        if (rows.len > 0 and rows[0].user_id != user_id) {
            try notifications.create(rows[0].user_id, user_id, "comment", post_id.?);
        }
    }

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"id\":{d},\"created\":true}}", .{comment_id});
}

pub fn getComments(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql =
        \\SELECT c.id, c.user_id, u.username, u.display_name, u.avatar_url,
        \\       c.content, c.created_at
        \\FROM comments c
        \\JOIN users u ON c.user_id = u.id
        \\WHERE c.post_id = ?
        \\ORDER BY c.created_at DESC
    ;

    const Comment = struct {
        id: i64,
        user_id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
        content: []const u8,
        created_at: []const u8,
    };

    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    const rows = db.query(Comment, allocator, sql, &[_][]const u8{post_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch comments\"}");
        return;
    };
    defer db.freeRows(Comment, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("[");

    for (rows, 0..) |row, idx| {
        if (idx > 0) try res.append(",");
        const escaped_content = try json_utils.escapeJson(allocator, row.content);
        defer allocator.free(escaped_content);
        const escaped_username = try json_utils.escapeJson(allocator, row.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, row.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_created_at = try json_utils.escapeJson(allocator, row.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"created_at\":\"{s}\"}}", .{ row.id, row.user_id, escaped_username, escaped_display_name, escaped_content, escaped_created_at });
    }

    try res.append("]");
}

pub fn repost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "INSERT OR IGNORE INTO reposts (user_id, post_id) VALUES (?, ?)";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to repost\"}");
        return;
    };

    // Create notification for post owner
    const post_owner_sql = "SELECT user_id FROM posts WHERE id = ?";
    const PostOwner = struct {
        user_id: i64,
    };
    const owner_rows = db.query(PostOwner, allocator, post_owner_sql, &[_][]const u8{post_id_str}) catch null;
    if (owner_rows) |rows| {
        defer db.freeRows(PostOwner, allocator, rows);
        if (rows.len > 0 and rows[0].user_id != user_id) {
            try notifications.create(rows[0].user_id, user_id, "repost", post_id.?);
        }
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"reposted\":true}");
}

pub fn unrepost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "DELETE FROM reposts WHERE user_id = ? AND post_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to unrepost\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"unreposted\":true}");
}

pub fn bookmark(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "INSERT OR IGNORE INTO bookmarks (user_id, post_id) VALUES (?, ?)";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to bookmark\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"bookmarked\":true}");
}

pub fn unbookmark(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract post ID
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var post_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            post_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (post_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    }

    const sql = "DELETE FROM bookmarks WHERE user_id = ? AND post_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id.?});
    defer allocator.free(post_id_str);

    db.execute(sql, &[_][]const u8{ user_id_str, post_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to unbookmark\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"unbookmarked\":true}");
}

pub fn pinPost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const post_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Verify ownership
    const check_sql = "SELECT user_id FROM posts WHERE id = ?";
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
        try res.append("{\"error\":\"Post not found\"}");
        return;
    }

    if (check_rows[0].user_id != user_id) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Not authorized to pin this post\"}");
        return;
    }

    // Remove any existing pinned post for this user
    try db.execute(
        "DELETE FROM pinned_posts WHERE user_id = ?",
        &[_][]const u8{user_id_str},
    );

    // Pin the new post
    try db.execute(
        "INSERT INTO pinned_posts (user_id, post_id) VALUES (?, ?)",
        &[_][]const u8{ user_id_str, post_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"pinned\":true}");
}

pub fn unpinPost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const post_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    try db.execute(
        "DELETE FROM pinned_posts WHERE user_id = ? AND post_id = ?",
        &[_][]const u8{ user_id_str, post_id_str },
    );

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"unpinned\":true}");
}

pub fn recordView(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    const post_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    };

    const post_id = std.fmt.parseInt(i64, post_id_str, 10) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid post ID\"}");
        return;
    };

    // Get client IP
    const ip_address = req.headers.get("x-forwarded-for") orelse req.headers.get("x-real-ip") orelse "unknown";

    try analytics.recordView(allocator, post_id, user_id, ip_address);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"recorded\":true}");
}
