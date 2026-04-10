const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const json_utils = @import("json.zig");

const HashtagIdRow = struct { id: i64 };

const Hashtag = struct {
    id: i64,
    tag: []const u8,
    use_count: i64,
};

pub fn getTrending(allocator: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    const sql =
        \\SELECT id, tag, use_count
        \\FROM hashtags
        \\ORDER BY use_count DESC, created_at DESC
        \\LIMIT 20
    ;

    const rows = db.query(Hashtag, allocator, sql, &[_][]const u8{}) catch |err| {
        std.log.err("Failed to get trending: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get trending\"}");
        return;
    };
    defer db.freeRows(Hashtag, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"trending\":[", .{});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_tag = try json_utils.escapeJson(allocator, row.tag);
        defer allocator.free(escaped_tag);
        try res.bodyWriter().print("{{\"id\":{d},\"tag\":\"{s}\",\"use_count\":{d}}}", .{
            row.id, escaped_tag, row.use_count,
        });
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn getPostsByHashtag(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id_opt = auth.getUserIdFromRequest(allocator, req) catch null;

    const hashtag = req.params.get("tag") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Missing hashtag\"}");
        return;
    };

    const sql =
        \\SELECT p.id, p.user_id, u.username, u.display_name, u.avatar_url,
        \\  p.content, p.media_urls, p.created_at,
        \\  (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
        \\  (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
        \\  (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count,
        \\  EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = ?) as is_liked,
        \\  EXISTS(SELECT 1 FROM reposts WHERE post_id = p.id AND user_id = ?) as is_reposted
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\JOIN post_hashtags ph ON p.id = ph.post_id
        \\JOIN hashtags h ON ph.hashtag_id = h.id
        \\WHERE h.tag = ?
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
        created_at: []const u8,
        likes_count: i64,
        comments_count: i64,
        reposts_count: i64,
        is_liked: i64,
        is_reposted: i64,
    };

    const user_id_str = if (user_id_opt) |uid| try std.fmt.allocPrint(allocator, "{d}", .{uid}) else "0";
    defer if (user_id_opt != null) allocator.free(user_id_str);

    const rows = db.query(Post, allocator, sql, &[_][]const u8{
        user_id_str,
        user_id_str,
        hashtag,
    }) catch |err| {
        std.log.err("Failed to get posts by hashtag: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get posts\"}");
        return;
    };
    defer db.freeRows(Post, allocator, rows);

    const escaped_hashtag = try json_utils.escapeJson(allocator, hashtag);
    defer allocator.free(escaped_hashtag);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"hashtag\":\"{s}\",\"posts\":[", .{escaped_hashtag});
    for (rows, 0..) |row, i| {
        if (i > 0) try res.bodyWriter().print(",", .{});
        const escaped_username2 = try json_utils.escapeJson(allocator, row.username);
        defer allocator.free(escaped_username2);
        try res.bodyWriter().print("{{\"id\":{d},\"user_id\":{d},\"username\":\"{s}\"", .{
            row.id, row.user_id, escaped_username2,
        });
        if (row.display_name) |name| {
            const escaped_name = try json_utils.escapeJson(allocator, name);
            defer allocator.free(escaped_name);
            try res.bodyWriter().print(",\"display_name\":\"{s}\"", .{escaped_name});
        }
        if (row.avatar_url) |url| {
            const escaped_url = try json_utils.escapeJson(allocator, url);
            defer allocator.free(escaped_url);
            try res.bodyWriter().print(",\"avatar_url\":\"{s}\"", .{escaped_url});
        }
        const escaped_content = try json_utils.escapeJson(allocator, row.content);
        defer allocator.free(escaped_content);
        try res.bodyWriter().print(",\"content\":\"{s}\"", .{escaped_content});
        if (row.media_urls) |urls| {
            const escaped_urls = try json_utils.escapeJson(allocator, urls);
            defer allocator.free(escaped_urls);
            try res.bodyWriter().print(",\"media_urls\":\"{s}\"", .{escaped_urls});
        } else {
            try res.bodyWriter().print(",\"media_urls\":\"\"", .{});
        }
        const escaped_created = try json_utils.escapeJson(allocator, row.created_at);
        defer allocator.free(escaped_created);
        try res.bodyWriter().print(",\"created_at\":\"{s}\",\"likes_count\":{d},\"comments_count\":{d},\"reposts_count\":{d},\"is_liked\":{d},\"is_reposted\":{d}}}", .{
            escaped_created, row.likes_count, row.comments_count, row.reposts_count, row.is_liked, row.is_reposted,
        });
    }
    try res.bodyWriter().print("]}}", .{});
}

pub fn extractAndSaveHashtags(allocator: std.mem.Allocator, post_id: i64, content: []const u8) !void {
    // Simple hashtag extraction - find words starting with #
    var i: usize = 0;
    while (i < content.len) {
        if (content[i] == '#') {
            var end = i + 1;
            while (end < content.len and std.ascii.isAlphanumeric(content[end])) {
                end += 1;
            }
            if (end > i + 1) {
                const tag = content[i + 1 .. end];

                // Insert or update hashtag
                try db.execute(
                    "INSERT INTO hashtags (tag) VALUES (?) ON CONFLICT(tag) DO UPDATE SET use_count = use_count + 1",
                    &[_][]const u8{tag},
                );

                // Get hashtag id
                const hashtag_rows = db.query(
                    HashtagIdRow,
                    allocator,
                    "SELECT id FROM hashtags WHERE tag = ?",
                    &[_][]const u8{tag},
                ) catch |err| {
                    std.log.err("Failed to get hashtag id: {}", .{err});
                    continue;
                };
                defer db.freeRows(HashtagIdRow, allocator, hashtag_rows);

                if (hashtag_rows.len > 0) {
                    const hashtag_id = hashtag_rows[0].id;
                    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
                    defer allocator.free(post_id_str);
                    const hashtag_id_str = try std.fmt.allocPrint(allocator, "{d}", .{hashtag_id});
                    defer allocator.free(hashtag_id_str);
                    try db.execute(
                        "INSERT INTO post_hashtags (post_id, hashtag_id) VALUES (?, ?)",
                        &[_][]const u8{ post_id_str, hashtag_id_str },
                    );
                }
            }
            i = end;
        } else {
            i += 1;
        }
    }
}
