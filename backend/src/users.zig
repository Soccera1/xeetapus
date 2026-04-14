const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");
const notifications = @import("notifications.zig");
const validation = @import("validation.zig");

pub const Profile = struct {
    id: i64,
    username: []const u8,
    display_name: ?[]const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    created_at: []const u8,
    followers_count: i64,
    following_count: i64,
    posts_count: i64,
    is_following: bool,
};

pub fn getProfile(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT 
        \\    u.id, u.username, u.display_name, u.bio, u.avatar_url, u.created_at,
        \\    (SELECT COUNT(*) FROM follows WHERE following_id = u.id) as followers_count,
        \\    (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) as following_count,
        \\    (SELECT COUNT(*) FROM posts WHERE user_id = u.id) as posts_count,
        \\    CASE WHEN ? THEN (SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = u.id) > 0 ELSE 0 END as is_following
        \\FROM users u
        \\WHERE u.username = ?
    ;

    const current_user_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(current_user_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, current_user_str, username.? };

    const rows = db.query(Profile, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch profile\"}");
        return;
    };
    defer db.freeRows(Profile, allocator, rows);

    if (rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"User not found\"}");
        return;
    }

    const profile = rows[0];
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username = try json_utils.escapeJson(allocator, profile.username);
    defer allocator.free(escaped_username);
    const escaped_display_name = try json_utils.escapeJson(allocator, profile.display_name orelse "");
    defer allocator.free(escaped_display_name);
    const escaped_bio = try json_utils.escapeJson(allocator, profile.bio orelse "");
    defer allocator.free(escaped_bio);
    const escaped_avatar_url = try json_utils.escapeJson(allocator, profile.avatar_url orelse "");
    defer allocator.free(escaped_avatar_url);
    const escaped_created_at = try json_utils.escapeJson(allocator, profile.created_at);
    defer allocator.free(escaped_created_at);
    try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"bio\":\"{s}\",\"avatar_url\":\"{s}\",\"created_at\":\"{s}\",\"followers_count\":{d},\"following_count\":{d},\"posts_count\":{d},\"is_following\":{s}}}", .{ profile.id, escaped_username, escaped_display_name, escaped_bio, escaped_avatar_url, escaped_created_at, profile.followers_count, profile.following_count, profile.posts_count, if (profile.is_following) "true" else "false" });
}

pub fn getPosts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE u.username = ?
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
    };

    const current_user_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(current_user_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, current_user_str, has_user, current_user_str, username.? };

    const rows = db.query(Post, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch posts\"}");
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
        const escaped_media_urls = try json_utils.escapeJson(allocator, post.media_urls orelse "");
        defer allocator.free(escaped_media_urls);
        const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"media_urls\":\"{s}\",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{s},\"is_reposted\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_media_urls, escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false" });
    }

    try res.append("]");
}

pub fn follow(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const follower_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    // Get target user ID
    const target_sql = "SELECT id FROM users WHERE username = ?";
    const TargetUser = struct {
        id: i64,
    };

    const target_rows = db.query(TargetUser, allocator, target_sql, &[_][]const u8{username.?}) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(target_rows);

    if (target_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"User not found\"}");
        return;
    }

    const following_id = target_rows[0].id;

    if (follower_id == following_id) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Cannot follow yourself\"}");
        return;
    }

    const sql = "INSERT OR IGNORE INTO follows (follower_id, following_id) VALUES (?, ?)";
    const follower_str = try std.fmt.allocPrint(allocator, "{d}", .{follower_id});
    defer allocator.free(follower_str);
    const following_str = try std.fmt.allocPrint(allocator, "{d}", .{following_id});
    defer allocator.free(following_str);

    db.execute(sql, &[_][]const u8{ follower_str, following_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to follow user\"}");
        return;
    };

    // Create notification for followed user
    try notifications.create(following_id, follower_id, "follow", null);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"following\":true}");
}

pub fn unfollow(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const follower_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    // Get target user ID
    const target_sql = "SELECT id FROM users WHERE username = ?";
    const TargetUser = struct {
        id: i64,
    };

    const target_rows = db.query(TargetUser, allocator, target_sql, &[_][]const u8{username.?}) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(target_rows);

    if (target_rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"User not found\"}");
        return;
    }

    const following_id = target_rows[0].id;

    const sql = "DELETE FROM follows WHERE follower_id = ? AND following_id = ?";
    const follower_str = try std.fmt.allocPrint(allocator, "{d}", .{follower_id});
    defer allocator.free(follower_str);
    const following_str = try std.fmt.allocPrint(allocator, "{d}", .{following_id});
    defer allocator.free(following_str);

    db.execute(sql, &[_][]const u8{ follower_str, following_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to unfollow user\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"unfollowed\":true}");
}

pub fn getFollowers(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url
        \\FROM users u
        \\JOIN follows f ON u.id = f.follower_id
        \\WHERE f.following_id = (SELECT id FROM users WHERE username = ?)
        \\ORDER BY f.created_at DESC
    ;

    const User = struct {
        id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
    };

    const rows = db.query(User, allocator, sql, &[_][]const u8{username.?}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch followers\"}");
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

pub fn getFollowing(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url
        \\FROM users u
        \\JOIN follows f ON u.id = f.following_id
        \\WHERE f.follower_id = (SELECT id FROM users WHERE username = ?)
        \\ORDER BY f.created_at DESC
    ;

    const User = struct {
        id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
    };

    const rows = db.query(User, allocator, sql, &[_][]const u8{username.?}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch following\"}");
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

pub fn getReplies(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE u.username = ? AND p.reply_to_id IS NOT NULL
        \\ORDER BY p.created_at DESC
        \\LIMIT 50
    ;

    const ReplyPost = struct {
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
    };

    const current_user_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(current_user_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, current_user_str, has_user, current_user_str, username.? };

    const rows = db.query(ReplyPost, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch replies\"}");
        return;
    };
    defer db.freeRows(ReplyPost, allocator, rows);

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
        const escaped_media_urls = try json_utils.escapeJson(allocator, post.media_urls orelse "");
        defer allocator.free(escaped_media_urls);
        const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
        defer allocator.free(escaped_created_at);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"media_urls\":\"{s}\",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{s},\"is_reposted\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_media_urls, escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false" });
    }

    try res.append("]");
}

pub fn getMediaPosts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract username from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var username: ?[]const u8 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            username = part;
            break;
        }
        i += 1;
    }

    if (username == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Username required\"}");
        return;
    }

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\       p.content, p.media_urls, p.reply_to_id, p.created_at,
        \\       (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\       (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\       (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM likes WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_liked,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM reposts WHERE post_id = p.id AND user_id = ?) > 0 ELSE 0 END as is_reposted
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE u.username = ? AND p.media_urls IS NOT NULL AND p.media_urls != ''
        \\ORDER BY p.created_at DESC
        \\LIMIT 50
    ;

    const MediaPost = struct {
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
    };

    const current_user_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(current_user_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, current_user_str, has_user, current_user_str, username.? };

    const rows = db.query(MediaPost, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch media posts\"}");
        return;
    };
    defer db.freeRows(MediaPost, allocator, rows);

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
        const escaped_media_urls = try json_utils.escapeJson(allocator, post.media_urls orelse "");
        defer allocator.free(escaped_media_urls);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"media_urls\":\"{s}\",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{s},\"is_reposted\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_media_urls, escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false" });
    }

    try res.append("]");
}

pub fn updateProfile(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const UpdateRequest = struct {
        display_name: ?[]const u8 = null,
        bio: ?[]const u8 = null,
        avatar_url: ?[]const u8 = null,
    };

    const parsed = try std.json.parseFromSlice(UpdateRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Validate bio length (max 160 characters)
    if (body.bio) |bio| {
        if (bio.len > 160) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Bio must be 160 characters or less\"}");
            return;
        }
    }

    // Validate display_name length (max 50 characters)
    if (body.display_name) |name| {
        if (name.len > 50) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Display name must be 50 characters or less\"}");
            return;
        }
    }

    if (body.avatar_url) |url| {
        if (!validation.isValidUrl(url) or !validation.isSafeUrl(url)) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Invalid avatar URL\"}");
            return;
        }
    }

    const sql = "UPDATE users SET display_name = COALESCE(?, display_name), bio = COALESCE(?, bio), avatar_url = COALESCE(?, avatar_url) WHERE id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    db.execute(sql, &[_][]const u8{ body.display_name orelse "", body.bio orelse "", body.avatar_url orelse "", user_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to update profile\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"updated\":true}");
}
