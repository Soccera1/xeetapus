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

const PUBLIC_DIR = "../frontend/public";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize database
    try db.init("xeetapus.db");
    defer db.deinit();

    // Run migrations
    try db.runMigrations();

    // Start HTTP server
    var server = try http.Server.init(allocator, 8080);
    defer server.deinit();

    // Register API routes
    try server.addRoute("POST", "/api/auth/register", auth.register);
    try server.addRoute("POST", "/api/auth/login", auth.login);
    try server.addRoute("GET", "/api/auth/me", auth.me);

    try server.addRoute("POST", "/api/posts", posts.create);
    try server.addRoute("GET", "/api/posts", posts.list);
    try server.addRoute("GET", "/api/posts/:id", posts.get);
    try server.addRoute("DELETE", "/api/posts/:id", posts.delete);
    try server.addRoute("POST", "/api/posts/:id/like", posts.like);
    try server.addRoute("DELETE", "/api/posts/:id/like", posts.unlike);
    try server.addRoute("POST", "/api/posts/:id/repost", posts.repost);
    try server.addRoute("DELETE", "/api/posts/:id/repost", posts.unrepost);
    try server.addRoute("POST", "/api/posts/:id/bookmark", posts.bookmark);
    try server.addRoute("DELETE", "/api/posts/:id/bookmark", posts.unbookmark);
    try server.addRoute("POST", "/api/posts/:id/comment", posts.comment);
    try server.addRoute("GET", "/api/posts/:id/comments", posts.getComments);
    try server.addRoute("POST", "/api/posts/:id/pin", posts.pinPost);
    try server.addRoute("DELETE", "/api/posts/:id/pin", posts.unpinPost);
    try server.addRoute("POST", "/api/posts/:id/view", posts.recordView);

    try server.addRoute("GET", "/api/users/:username", users.getProfile);
    try server.addRoute("GET", "/api/users/:username/posts", users.getPosts);
    try server.addRoute("POST", "/api/users/:username/follow", users.follow);
    try server.addRoute("DELETE", "/api/users/:username/follow", users.unfollow);
    try server.addRoute("GET", "/api/users/:username/followers", users.getFollowers);
    try server.addRoute("GET", "/api/users/:username/following", users.getFollowing);
    try server.addRoute("POST", "/api/users/:username/block", blocks.blockUser);
    try server.addRoute("DELETE", "/api/users/:username/block", blocks.unblockUser);
    try server.addRoute("POST", "/api/users/:username/mute", blocks.muteUser);
    try server.addRoute("DELETE", "/api/users/:username/mute", blocks.unmuteUser);

    try server.addRoute("GET", "/api/timeline", timeline.getTimeline);
    try server.addRoute("GET", "/api/timeline/explore", timeline.getExplore);

    try server.addRoute("GET", "/api/notifications", notifications.list);
    try server.addRoute("POST", "/api/notifications/:id/read", notifications.markAsRead);
    try server.addRoute("POST", "/api/notifications/read-all", notifications.markAllAsRead);
    try server.addRoute("GET", "/api/notifications/unread-count", notifications.getUnreadCount);

    try server.addRoute("GET", "/api/search/users", search.searchUsers);
    try server.addRoute("GET", "/api/search/posts", search.searchPosts);

    // Community routes
    try server.addRoute("GET", "/api/communities", communities.list);
    try server.addRoute("POST", "/api/communities", communities.create);
    try server.addRoute("GET", "/api/communities/:id", communities.get);
    try server.addRoute("POST", "/api/communities/:id/join", communities.join);
    try server.addRoute("DELETE", "/api/communities/:id/join", communities.leave);
    try server.addRoute("GET", "/api/communities/:id/posts", communities.getPosts);
    try server.addRoute("POST", "/api/communities/:id/posts", communities.createPost);
    try server.addRoute("GET", "/api/communities/:id/members", communities.getMembers);

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
    try server.addRoute("GET", "/api/hashtags/trending", hashtags.getTrending);
    try server.addRoute("GET", "/api/hashtags/:tag/posts", hashtags.getPostsByHashtag);

    // Polls routes
    try server.addRoute("POST", "/api/polls/:id/vote", polls.vote);
    try server.addRoute("GET", "/api/polls/:id/results", polls.getPollResults);

    // Blocks/Mutes routes
    try server.addRoute("GET", "/api/blocks", blocks.getBlockedUsers);
    try server.addRoute("GET", "/api/mutes", blocks.getMutedUsers);

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

    try server.addRoute("GET", "/api/health", healthCheck);

    // Register static file handler for all other routes
    try server.addRoute("GET", "/", serveStaticFiles);

    std.log.info("Xeetapus server starting on port 8080...", .{});
    try server.start();
}

fn healthCheck(_: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.appendSlice("{\"status\":\"ok\",\"service\":\"xeetapus\"}");
}

fn serveStaticFiles(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Remove leading slash
    const path = if (req.path.len > 1) req.path[1..] else "index.html";

    // Build full file path
    const full_path = std.fs.path.join(allocator, &[_][]const u8{ PUBLIC_DIR, path }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.body.appendSlice("Internal Server Error");
        return;
    };
    defer allocator.free(full_path);

    // Try to open the file
    const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
        // If file not found, serve index.html (SPA fallback)
        if (err == std.fs.File.OpenError.FileNotFound) {
            const index_path = std.fs.path.join(allocator, &[_][]const u8{ PUBLIC_DIR, "index.html" }) catch {
                res.status = 500;
                return;
            };
            defer allocator.free(index_path);

            const index_file = std.fs.cwd().openFile(index_path, .{}) catch {
                res.status = 404;
                res.headers.put("Content-Type", "text/plain") catch {};
                try res.body.appendSlice("Not Found");
                return;
            };
            defer index_file.close();

            const content = index_file.readToEndAlloc(allocator, 1024 * 1024) catch {
                res.status = 500;
                return;
            };
            defer allocator.free(content);

            res.headers.put("Content-Type", "text/html") catch {};
            try res.body.appendSlice(content);
            return;
        }

        res.status = 404;
        res.headers.put("Content-Type", "text/plain") catch {};
        try res.body.appendSlice("Not Found");
        return;
    };
    defer file.close();

    // Read file content
    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(content);

    // Set content type based on file extension
    const content_type = if (std.mem.endsWith(u8, path, ".html"))
        "text/html"
    else if (std.mem.endsWith(u8, path, ".css"))
        "text/css"
    else if (std.mem.endsWith(u8, path, ".js"))
        "application/javascript"
    else if (std.mem.endsWith(u8, path, ".json"))
        "application/json"
    else if (std.mem.endsWith(u8, path, ".png"))
        "image/png"
    else if (std.mem.endsWith(u8, path, ".jpg") or std.mem.endsWith(u8, path, ".jpeg"))
        "image/jpeg"
    else
        "text/plain";

    res.headers.put("Content-Type", content_type) catch {};
    try res.body.appendSlice(content);
}
