const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");
const posts = @import("posts.zig");
const users = @import("users.zig");
const timeline = @import("timeline.zig");
const notifications = @import("notifications.zig");
const search = @import("search.zig");
const communities = @import("communities.zig");
const messages = @import("messages.zig");
const lists = @import("lists.zig");
const hashtags = @import("hashtags.zig");
const polls = @import("polls.zig");
const blocks = @import("blocks.zig");
const drafts = @import("drafts.zig");
const scheduled = @import("scheduled.zig");
const analytics = @import("analytics.zig");
const media = @import("media.zig");
const config = @import("config.zig");
const audit = @import("audit.zig");
const llm = @import("llm.zig");
const payments = @import("payments.zig");

const PUBLIC_DIR = "./dist";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize configuration from environment
    try config.Config.init(allocator);
    defer config.Config.deinit(allocator);

    const cfg = try config.Config.get();

    // Initialize database
    try db.init(cfg.database_path);
    defer db.deinit();

    // Run migrations
    try db.runMigrations();

    // Initialize audit logging
    const audit_log_path = if (config.isProduction()) "/var/log/xeetapus.log" else "audit.log";
    try audit.init(audit_log_path);
    defer audit.deinit();

    // Initialize payments (Monero)
    try payments.init(allocator);
    defer payments.deinit();

    // Start HTTP server
    var server = try http.Server.init(allocator, cfg.server_port);
    defer server.deinit();

    // Register API routes
    try server.addPublicRoute("POST", "/api/auth/register", auth.register);
    try server.addPublicRoute("POST", "/api/auth/login", auth.login);
    try server.addRoute("POST", "/api/auth/logout", auth.logout);
    try server.addRoute("GET", "/api/auth/me", auth.me);

    try server.addRoute("POST", "/api/posts", posts.create);
    try server.addPublicRoute("GET", "/api/posts", posts.list);
    try server.addPublicRoute("GET", "/api/posts/:id", posts.get);
    try server.addRoute("DELETE", "/api/posts/:id", posts.delete);
    try server.addRoute("POST", "/api/posts/:id/like", posts.like);
    try server.addRoute("DELETE", "/api/posts/:id/like", posts.unlike);
    try server.addRoute("POST", "/api/posts/:id/repost", posts.repost);
    try server.addRoute("DELETE", "/api/posts/:id/repost", posts.unrepost);
    try server.addRoute("POST", "/api/posts/:id/bookmark", posts.bookmark);
    try server.addRoute("DELETE", "/api/posts/:id/bookmark", posts.unbookmark);
    try server.addRoute("POST", "/api/posts/:id/comment", posts.comment);
    try server.addPublicRoute("GET", "/api/posts/:id/comments", posts.getComments);
    try server.addRoute("POST", "/api/posts/:id/pin", posts.pinPost);
    try server.addRoute("DELETE", "/api/posts/:id/pin", posts.unpinPost);
    try server.addRoute("POST", "/api/posts/:id/view", posts.recordView);

    try server.addPublicRoute("GET", "/api/users/:username", users.getProfile);
    try server.addPublicRoute("GET", "/api/users/:username/posts", users.getPosts);
    try server.addPublicRoute("GET", "/api/users/:username/replies", users.getReplies);
    try server.addPublicRoute("GET", "/api/users/:username/media", users.getMediaPosts);
    try server.addRoute("POST", "/api/users/:username/follow", users.follow);
    try server.addRoute("DELETE", "/api/users/:username/follow", users.unfollow);
    try server.addPublicRoute("GET", "/api/users/:username/followers", users.getFollowers);
    try server.addPublicRoute("GET", "/api/users/:username/following", users.getFollowing);
    try server.addRoute("POST", "/api/users/:username/block", blocks.blockUser);
    try server.addRoute("DELETE", "/api/users/:username/block", blocks.unblockUser);
    try server.addRoute("POST", "/api/users/:username/mute", blocks.muteUser);
    try server.addRoute("DELETE", "/api/users/:username/mute", blocks.unmuteUser);
    try server.addRoute("PUT", "/api/users/me", users.updateProfile);

    try server.addRoute("GET", "/api/timeline", timeline.getTimeline);
    try server.addPublicRoute("GET", "/api/timeline/explore", timeline.getExplore);

    try server.addRoute("GET", "/api/notifications", notifications.list);
    try server.addRoute("POST", "/api/notifications/:id/read", notifications.markAsRead);
    try server.addRoute("POST", "/api/notifications/read-all", notifications.markAllAsRead);
    try server.addRoute("GET", "/api/notifications/unread-count", notifications.getUnreadCount);

    try server.addPublicRoute("GET", "/api/search/users", search.searchUsers);
    try server.addPublicRoute("GET", "/api/search/posts", search.searchPosts);

    // Community routes
    try server.addPublicRoute("GET", "/api/communities", communities.list);
    try server.addRoute("POST", "/api/communities", communities.create);
    try server.addPublicRoute("GET", "/api/communities/:id", communities.get);
    try server.addRoute("POST", "/api/communities/:id/join", communities.join);
    try server.addRoute("DELETE", "/api/communities/:id/join", communities.leave);
    try server.addPublicRoute("GET", "/api/communities/:id/posts", communities.getPosts);
    try server.addRoute("POST", "/api/communities/:id/posts", communities.createPost);
    try server.addPublicRoute("GET", "/api/communities/:id/members", communities.getMembers);

    // Direct Messages routes
    try server.addRoute("GET", "/api/messages/conversations", messages.getConversations);
    try server.addRoute("POST", "/api/messages/conversations", messages.createConversation);
    try server.addRoute("GET", "/api/messages/conversations/:id", messages.getMessages);
    try server.addRoute("POST", "/api/messages/conversations/:id", messages.sendMessage);
    try server.addRoute("GET", "/api/messages/unread-count", messages.getUnreadCount);

    // Lists routes
    try server.addRoute("GET", "/api/lists", lists.getMyLists);
    try server.addRoute("POST", "/api/lists", lists.createList);
    try server.addRoute("GET", "/api/lists/:id", lists.getList);
    try server.addRoute("DELETE", "/api/lists/:id", lists.deleteList);
    try server.addRoute("POST", "/api/lists/:id/members", lists.addMember);
    try server.addRoute("DELETE", "/api/lists/:id/members/:user_id", lists.removeMember);
    try server.addRoute("GET", "/api/lists/:id/timeline", lists.getListTimeline);

    // Hashtags routes
    try server.addPublicRoute("GET", "/api/hashtags/trending", hashtags.getTrending);
    try server.addPublicRoute("GET", "/api/hashtags/:tag/posts", hashtags.getPostsByHashtag);

    // Polls routes
    try server.addRoute("POST", "/api/polls/:id/vote", polls.vote);
    try server.addPublicRoute("GET", "/api/polls/:id/results", polls.getPollResults);

    // Blocks/Mutes routes
    try server.addRoute("GET", "/api/blocks", blocks.getBlockedUsers);
    try server.addRoute("GET", "/api/mutes", blocks.getMutedUsers);

    // LLM routes
    try server.addPublicRoute("GET", "/api/llm/providers", llm.getProviders);
    try server.addRoute("GET", "/api/llm/configs", llm.getConfigs);
    try server.addRoute("PUT", "/api/llm/configs/:provider", llm.updateConfig);
    try server.addRoute("DELETE", "/api/llm/configs/:provider", llm.deleteConfig);
    try server.addRoute("POST", "/api/llm/configs/:provider/reveal", llm.revealConfig);
    try server.addRoute("POST", "/api/llm/chat", llm.chat);

    // Drafts routes
    try server.addRoute("GET", "/api/drafts", drafts.getDrafts);
    try server.addRoute("POST", "/api/drafts", drafts.createDraft);
    try server.addRoute("PUT", "/api/drafts/:id", drafts.updateDraft);
    try server.addRoute("DELETE", "/api/drafts/:id", drafts.deleteDraft);

    // Scheduled posts routes
    try server.addRoute("GET", "/api/scheduled", scheduled.getScheduledPosts);
    try server.addRoute("POST", "/api/scheduled", scheduled.createScheduledPost);
    try server.addRoute("DELETE", "/api/scheduled/:id", scheduled.deleteScheduledPost);

    // Analytics routes
    try server.addRoute("GET", "/api/analytics/posts/:id/views", analytics.getPostViews);
    try server.addRoute("GET", "/api/analytics/me", analytics.getUserAnalytics);

    // Media routes
    try server.addRoute("POST", "/api/media/upload", media.upload);
    try server.addPublicRoute("GET", "/media/*", media.serveMedia);

    // Payment routes (Monero)
    try server.addRoute("POST", "/api/payments/invoices", payments.createInvoice);
    try server.addRoute("GET", "/api/payments/invoices/:id", payments.checkPayment);
    try server.addRoute("GET", "/api/payments/invoices", payments.getInvoices);
    try server.addRoute("GET", "/api/payments/balance", payments.getBalance);
    try server.addRoute("POST", "/api/payments/pay", payments.payInvoice);
    try server.addRoute("GET", "/api/payments/rate", payments.getExchangeRate);

    try server.addPublicRoute("GET", "/api/health", healthCheck);

    // Register static file handler as fallback for unmatched routes
    // The /* path with params will match all GET requests
    try server.addPublicRoute("GET", "/*", serveStaticFiles);

    std.log.info("Xeetapus server starting on port {d}...", .{cfg.server_port});
    try server.start();
}

fn healthCheck(_: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"status\":\"ok\",\"service\":\"xeetapus\"}");
}

fn serveStaticFiles(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Get path from params (wildcard route) or request path
    const path_param = req.params.get("path");
    const path = if (path_param) |p| p else if (req.path.len > 1) req.path[1..] else "index.html";

    // SECURITY: Prevent path traversal attacks
    // Check for path traversal sequences
    if (std.mem.indexOf(u8, path, "..") != null or
        std.mem.indexOf(u8, path, "~") != null or
        std.mem.startsWith(u8, path, "/") or
        std.mem.indexOf(u8, path, "\\") != null)
    {
        res.status = 403;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Forbidden");
        return;
    }

    // Build full file path with canonicalization
    const full_path = std.fs.path.join(allocator, &[_][]const u8{ PUBLIC_DIR, path }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Internal Server Error");
        return;
    };
    defer allocator.free(full_path);

    // Resolve to absolute path and verify it's within PUBLIC_DIR
    const abs_path = std.fs.cwd().realpathAlloc(allocator, full_path) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound) {
            // Try serving index.html for SPA routing
            return serveIndexHtml(allocator, res);
        }
        res.status = 500;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Internal Server Error");
        return;
    };
    defer allocator.free(abs_path);

    const public_dir_abs = std.fs.cwd().realpathAlloc(allocator, PUBLIC_DIR) catch {
        res.status = 500;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Internal Server Error");
        return;
    };
    defer allocator.free(public_dir_abs);

    // Ensure the resolved path is within the public directory
    if (!std.mem.startsWith(u8, abs_path, public_dir_abs)) {
        res.status = 403;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Forbidden");
        return;
    }

    // Try to open the file
    const file = std.fs.cwd().openFile(abs_path, .{}) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound or
            err == std.fs.File.OpenError.IsDir)
        {
            return serveIndexHtml(allocator, res);
        }

        res.status = 404;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Not Found");
        return;
    };
    defer file.close();

    // Get file metadata for size check
    const stat = file.stat() catch {
        res.status = 500;
        return;
    };

    // Limit file size to 10MB
    const MAX_FILE_SIZE = 10 * 1024 * 1024;
    if (stat.size > MAX_FILE_SIZE) {
        res.status = 413;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("File too large");
        return;
    }

    // Read file content
    const content = file.readToEndAlloc(allocator, MAX_FILE_SIZE) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(content);

    // Set content type based on file extension
    const content_type = getContentType(path);

    res.headers.put("Content-Type", content_type) catch {};
    try res.append(content);
}

fn serveIndexHtml(allocator: std.mem.Allocator, res: *http.Response) !void {
    const index_path = std.fs.path.join(allocator, &[_][]const u8{ PUBLIC_DIR, "index.html" }) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(index_path);

    const index_file = std.fs.cwd().openFile(index_path, .{}) catch {
        res.status = 404;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.append("Not Found");
        return;
    };
    defer index_file.close();

    const content = index_file.readToEndAlloc(allocator, 1024 * 1024) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(content);

    res.headers.put("Content-Type", "text/html") catch {};
    try res.append(content);
}

fn getContentType(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".html")) return "text/html";
    if (std.mem.eql(u8, ext, ".css")) return "text/css";
    if (std.mem.eql(u8, ext, ".js")) return "application/javascript";
    if (std.mem.eql(u8, ext, ".json")) return "application/json";
    if (std.mem.eql(u8, ext, ".png")) return "image/png";
    if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) return "image/jpeg";
    if (std.mem.eql(u8, ext, ".gif")) return "image/gif";
    if (std.mem.eql(u8, ext, ".svg")) return "image/svg+xml";
    if (std.mem.eql(u8, ext, ".ico")) return "image/x-icon";
    if (std.mem.eql(u8, ext, ".woff")) return "font/woff";
    if (std.mem.eql(u8, ext, ".woff2")) return "font/woff2";
    if (std.mem.eql(u8, ext, ".ttf")) return "font/ttf";
    if (std.mem.eql(u8, ext, ".eot")) return "application/vnd.ms-fontobject";
    return "application/octet-stream";
}
