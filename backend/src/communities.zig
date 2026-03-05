const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

pub const Community = struct {
    id: i64,
    name: []const u8,
    description: ?[]const u8,
    icon_url: ?[]const u8,
    banner_url: ?[]const u8,
    created_by: i64,
    created_at: []const u8,
    member_count: i64,
    post_count: i64,
    is_member: bool,
};

pub const CreateCommunityRequest = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    icon_url: ?[]const u8 = null,
    banner_url: ?[]const u8 = null,
};

pub fn list(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    const sql =
        \\SELECT c.id, c.name, c.description, c.icon_url, c.banner_url, c.created_by, c.created_at,
        \\       (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) as member_count,
        \\       (SELECT COUNT(*) FROM community_posts WHERE community_id = c.id) as post_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM community_members WHERE community_id = c.id AND user_id = ?) > 0 ELSE 0 END as is_member
        \\FROM communities c
        \\ORDER BY c.created_at DESC
    ;

    const user_id_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(user_id_str);
    const has_user = if (current_user_id != null) "1" else "0";

    const params = [_][]const u8{ has_user, user_id_str };

    const rows = db.query(Community, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to fetch communities\"}");
        return;
    };
    defer db.freeRows(Community, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("[");

    for (rows, 0..) |community, i| {
        if (i > 0) try res.body.appendSlice(",");
        const escaped_name = try json_utils.escapeJson(allocator, community.name);
        defer allocator.free(escaped_name);
        const escaped_description = try json_utils.escapeJson(allocator, community.description orelse "");
        defer allocator.free(escaped_description);
        const escaped_icon_url = try json_utils.escapeJson(allocator, community.icon_url orelse "");
        defer allocator.free(escaped_icon_url);
        const escaped_banner_url = try json_utils.escapeJson(allocator, community.banner_url orelse "");
        defer allocator.free(escaped_banner_url);
        const escaped_created_at = try json_utils.escapeJson(allocator, community.created_at);
        defer allocator.free(escaped_created_at);
        try res.body.writer().print("{{\"id\":{d},\"name\":\"{s}\",\"description\":\"{s}\",\"icon_url\":\"{s}\",\"banner_url\":\"{s}\",\"created_by\":{d},\"created_at\":\"{s}\",\"member_count\":{d},\"post_count\":{d},\"is_member\":{s}}}", .{ community.id, escaped_name, escaped_description, escaped_icon_url, escaped_banner_url, community.created_by, escaped_created_at, community.member_count, community.post_count, if (community.is_member) "true" else "false" });
    }

    try res.body.appendSlice("]");
}

pub fn get(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
        return;
    }

    const sql =
        \\SELECT c.id, c.name, c.description, c.icon_url, c.banner_url, c.created_by, c.created_at,
        \\       (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) as member_count,
        \\       (SELECT COUNT(*) FROM community_posts WHERE community_id = c.id) as post_count,
        \\       CASE WHEN ? THEN (SELECT COUNT(*) FROM community_members WHERE community_id = c.id AND user_id = ?) > 0 ELSE 0 END as is_member
        \\FROM communities c
        \\WHERE c.id = ?
    ;

    const user_id_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(user_id_str);
    const has_user = if (current_user_id != null) "1" else "0";
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    const params = [_][]const u8{ has_user, user_id_str, community_id_str };

    const rows = db.query(Community, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to fetch community\"}");
        return;
    };
    defer db.freeRows(Community, allocator, rows);

    if (rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Community not found\"}");
        return;
    }

    const community = rows[0];
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_name = try json_utils.escapeJson(allocator, community.name);
    defer allocator.free(escaped_name);
    const escaped_description = try json_utils.escapeJson(allocator, community.description orelse "");
    defer allocator.free(escaped_description);
    const escaped_icon_url = try json_utils.escapeJson(allocator, community.icon_url orelse "");
    defer allocator.free(escaped_icon_url);
    const escaped_banner_url = try json_utils.escapeJson(allocator, community.banner_url orelse "");
    defer allocator.free(escaped_banner_url);
    const escaped_created_at = try json_utils.escapeJson(allocator, community.created_at);
    defer allocator.free(escaped_created_at);
    try res.body.writer().print("{{\"id\":{d},\"name\":\"{s}\",\"description\":\"{s}\",\"icon_url\":\"{s}\",\"banner_url\":\"{s}\",\"created_by\":{d},\"created_at\":\"{s}\",\"member_count\":{d},\"post_count\":{d},\"is_member\":{s}}}", .{ community.id, escaped_name, escaped_description, escaped_icon_url, escaped_banner_url, community.created_by, escaped_created_at, community.member_count, community.post_count, if (community.is_member) "true" else "false" });
}

pub fn create(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const parsed = try std.json.parseFromSlice(CreateCommunityRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Validate name
    if (body.name.len < 3 or body.name.len > 50) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Community name must be between 3 and 50 characters\"}");
        return;
    }

    // Insert community
    const sql =
        \\INSERT INTO communities (name, description, icon_url, banner_url, created_by)
        \\VALUES (?, ?, ?, ?, ?)
    ;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const params = [_][]const u8{
        body.name,
        body.description orelse "",
        body.icon_url orelse "",
        body.banner_url orelse "",
        user_id_str,
    };

    db.execute(sql, &params) catch {
        res.status = 409;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Community name already exists\"}");
        return;
    };

    const community_id = db.lastInsertRowId();

    // Automatically add creator as a member
    const member_sql = "INSERT INTO community_members (community_id, user_id) VALUES (?, ?)";
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id});
    defer allocator.free(community_id_str);

    db.execute(member_sql, &[_][]const u8{ community_id_str, user_id_str }) catch {};

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_name = try json_utils.escapeJson(allocator, body.name);
    defer allocator.free(escaped_name);
    try res.body.writer().print("{{\"id\":{d},\"name\":\"{s}\",\"created\":true}}", .{ community_id, escaped_name });
}

pub fn join(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
        return;
    }

    const sql = "INSERT OR IGNORE INTO community_members (community_id, user_id) VALUES (?, ?)";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    db.execute(sql, &[_][]const u8{ community_id_str, user_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to join community\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"joined\":true}");
}

pub fn leave(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
        return;
    }

    const sql = "DELETE FROM community_members WHERE community_id = ? AND user_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    db.execute(sql, &[_][]const u8{ community_id_str, user_id_str }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to leave community\"}");
        return;
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"left\":true}");
}

pub fn getPosts(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const current_user_id = auth.getUserIdFromRequest(allocator, req) catch null;

    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
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
        \\JOIN community_posts cp ON p.id = cp.post_id
        \\WHERE cp.community_id = ?
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

    const user_id_str = if (current_user_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else "";
    defer if (current_user_id != null) allocator.free(user_id_str);
    const has_user = if (current_user_id != null) "1" else "0";
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    const params = [_][]const u8{ has_user, user_id_str, has_user, user_id_str, has_user, user_id_str, community_id_str };

    const rows = db.query(Post, allocator, sql, &params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to fetch community posts\"}");
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("[");

    for (rows, 0..) |post, idx| {
        if (idx > 0) try res.body.appendSlice(",");
        const escaped_content = try json_utils.escapeJson(allocator, post.content);
        defer allocator.free(escaped_content);
        const escaped_username = try json_utils.escapeJson(allocator, post.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, post.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_created_at = try json_utils.escapeJson(allocator, post.created_at);
        defer allocator.free(escaped_created_at);
        try res.body.writer().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"content\":\"{s}\",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{s},\"is_reposted\":{s},\"is_bookmarked\":{s}}}", .{ post.id, post.user_id, escaped_username, escaped_display_name, escaped_content, escaped_created_at, post.likes_count, post.comments_count, post.reposts_count, if (post.is_liked) "true" else "false", if (post.is_reposted) "true" else "false", if (post.is_bookmarked) "true" else "false" });
    }

    try res.body.appendSlice("]");
}

pub fn createPost(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
        return;
    }

    // Check if user is a member
    const check_sql = "SELECT 1 FROM community_members WHERE community_id = ? AND user_id = ?";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    const CheckResult = struct { dummy: i32 };
    const check_rows = db.query(CheckResult, allocator, check_sql, &[_][]const u8{ community_id_str, user_id_str }) catch {
        res.status = 500;
        return;
    };
    defer db.freeRows(CheckResult, allocator, check_rows);

    if (check_rows.len == 0) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Must be a community member to post\"}");
        return;
    }

    const CreatePostRequest = struct {
        content: []const u8,
        media_urls: ?[]const u8 = null,
    };

    const parsed = try std.json.parseFromSlice(CreatePostRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Validate content
    if (body.content.len == 0 or body.content.len > 280) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Content must be between 1 and 280 characters\"}");
        return;
    }

    // Insert post
    const post_sql =
        \\INSERT INTO posts (user_id, content, media_urls)
        \\VALUES (?, ?, ?)
    ;

    const post_params = [_][]const u8{
        user_id_str,
        body.content,
        body.media_urls orelse "",
    };

    db.execute(post_sql, &post_params) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to create post\"}");
        return;
    };

    const post_id = db.lastInsertRowId();

    // Link post to community
    const link_sql = "INSERT INTO community_posts (community_id, post_id) VALUES (?, ?)";
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);

    db.execute(link_sql, &[_][]const u8{ community_id_str, post_id_str }) catch {
        // If linking fails, we should ideally rollback the post creation
        // For simplicity, we'll just return an error
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to link post to community\"}");
        return;
    };

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_content = try json_utils.escapeJson(allocator, body.content);
    defer allocator.free(escaped_content);
    try res.body.writer().print("{{\"id\":{d},\"content\":\"{s}\",\"created\":true}}", .{ post_id, escaped_content });
}

pub fn getMembers(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract community ID from path
    const path_parts = std.mem.splitScalar(u8, req.path, '/');
    var community_id: ?i64 = null;

    var i: usize = 0;
    var iter = path_parts;
    while (iter.next()) |part| {
        if (i == 3) {
            community_id = std.fmt.parseInt(i64, part, 10) catch null;
            break;
        }
        i += 1;
    }

    if (community_id == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid community ID\"}");
        return;
    }

    const sql =
        \\SELECT u.id, u.username, u.display_name, u.avatar_url
        \\FROM users u
        \\JOIN community_members cm ON u.id = cm.user_id
        \\WHERE cm.community_id = ?
        \\ORDER BY cm.joined_at DESC
    ;

    const User = struct {
        id: i64,
        username: []const u8,
        display_name: []const u8,
        avatar_url: []const u8,
    };

    const community_id_str = try std.fmt.allocPrint(allocator, "{d}", .{community_id.?});
    defer allocator.free(community_id_str);

    const rows = db.query(User, allocator, sql, &[_][]const u8{community_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to fetch members\"}");
        return;
    };
    defer db.freeRows(User, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("[");

    for (rows, 0..) |user, idx| {
        if (idx > 0) try res.body.appendSlice(",");
        const escaped_username = try json_utils.escapeJson(allocator, user.username);
        defer allocator.free(escaped_username);
        const escaped_display_name = try json_utils.escapeJson(allocator, user.display_name);
        defer allocator.free(escaped_display_name);
        const escaped_avatar_url = try json_utils.escapeJson(allocator, user.avatar_url);
        defer allocator.free(escaped_avatar_url);
        try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\",\"display_name\":\"{s}\",\"avatar_url\":\"{s}\"}}", .{ user.id, escaped_username, escaped_display_name, escaped_avatar_url });
    }

    try res.body.appendSlice("]");
}
