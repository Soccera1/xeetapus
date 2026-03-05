const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");

const CountRow = struct { count: i64 };
const TotalViewsRow = struct { total_views: i64 };

pub fn recordView(allocator: std.mem.Allocator, post_id: i64, user_id: ?i64, ip_address: []const u8) !void {
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);

    var user_id_str: ?[]u8 = null;
    if (user_id) |uid| {
        user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{uid});
    }
    defer if (user_id_str) |s| allocator.free(s);

    try db.execute(
        "INSERT INTO post_views (post_id, user_id, ip_address) VALUES (?, ?, ?)",
        &[_][]const u8{
            post_id_str,
            user_id_str orelse "",
            ip_address,
        },
    );
}

pub fn getViewCount(allocator: std.mem.Allocator, post_id: i64) !i64 {
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);

    const sql = "SELECT COUNT(DISTINCT COALESCE(user_id, ip_address)) as count FROM post_views WHERE post_id = ?";
    const rows = db.query(CountRow, allocator, sql, &[_][]const u8{post_id_str}) catch |err| {
        std.log.err("Failed to get view count: {}", .{err});
        return 0;
    };
    defer db.freeRows(CountRow, allocator, rows);

    return if (rows.len > 0) rows[0].count else 0;
}

pub fn getPostViews(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const post_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing post ID\"}");
        return;
    };

    const sql = "SELECT COUNT(DISTINCT COALESCE(user_id, ip_address)) as count FROM post_views WHERE post_id = ?";
    const rows = db.query(CountRow, allocator, sql, &[_][]const u8{post_id_str}) catch |err| {
        std.log.err("Failed to get view count: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get view count\"}");
        return;
    };
    defer db.freeRows(CountRow, allocator, rows);

    const count = if (rows.len > 0) rows[0].count else 0;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"view_count\":{d}}}", .{count});
}

pub fn getUserAnalytics(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    // Get total views across all posts
    const views_sql =
        \\SELECT COUNT(DISTINCT COALESCE(pv.user_id, pv.ip_address)) as total_views
        \\FROM post_views pv
        \\JOIN posts p ON pv.post_id = p.id
        \\WHERE p.user_id = ?
    ;
    const views_rows = db.query(TotalViewsRow, allocator, views_sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get views: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get analytics\"}");
        return;
    };
    defer db.freeRows(TotalViewsRow, allocator, views_rows);

    // Get post counts
    const posts_sql = "SELECT COUNT(*) as count FROM posts WHERE user_id = ?";
    const posts_rows = db.query(CountRow, allocator, posts_sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get post count: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get analytics\"}");
        return;
    };
    defer db.freeRows(CountRow, allocator, posts_rows);

    // Get total likes received
    const likes_sql =
        \\SELECT COUNT(*) as count
        \\FROM likes l
        \\JOIN posts p ON l.post_id = p.id
        \\WHERE p.user_id = ?
    ;
    const likes_rows = db.query(CountRow, allocator, likes_sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get likes: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get analytics\"}");
        return;
    };
    defer db.freeRows(CountRow, allocator, likes_rows);

    // Get total reposts received
    const reposts_sql =
        \\SELECT COUNT(*) as count
        \\FROM reposts r
        \\JOIN posts p ON r.post_id = p.id
        \\WHERE p.user_id = ?
    ;
    const reposts_rows = db.query(CountRow, allocator, reposts_sql, &[_][]const u8{user_id_str}) catch |err| {
        std.log.err("Failed to get reposts: {}", .{err});
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to get analytics\"}");
        return;
    };
    defer db.freeRows(CountRow, allocator, reposts_rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"total_views\":{d},\"total_posts\":{d},\"total_likes_received\":{d},\"total_reposts_received\":{d}}}", .{
        if (views_rows.len > 0) views_rows[0].total_views else 0,
        if (posts_rows.len > 0) posts_rows[0].count else 0,
        if (likes_rows.len > 0) likes_rows[0].count else 0,
        if (reposts_rows.len > 0) reposts_rows[0].count else 0,
    });
}
