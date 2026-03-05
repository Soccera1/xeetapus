const std = @import("std");
const http = @import("http.zig");
const auth = @import("auth.zig");
const posts = @import("posts.zig");
const users = @import("users.zig");
const timeline = @import("timeline.zig");

pub fn registerRoutes(server: *http.Server) !void {
    // Auth routes
    try server.addRoute("POST", "/api/auth/register", auth.register);
    try server.addRoute("POST", "/api/auth/login", auth.login);
    try server.addRoute("GET", "/api/auth/me", auth.me);

    // Post routes
    try server.addRoute("POST", "/api/posts", posts.create);
    try server.addRoute("GET", "/api/posts", posts.list);
    try server.addRoute("GET", "/api/posts/:id", posts.get);
    try server.addRoute("DELETE", "/api/posts/:id", posts.delete);
    try server.addRoute("POST", "/api/posts/:id/like", posts.like);
    try server.addRoute("DELETE", "/api/posts/:id/like", posts.unlike);
    try server.addRoute("POST", "/api/posts/:id/comment", posts.comment);
    try server.addRoute("GET", "/api/posts/:id/comments", posts.getComments);

    // User routes
    try server.addRoute("GET", "/api/users/:username", users.getProfile);
    try server.addRoute("GET", "/api/users/:username/posts", users.getPosts);
    try server.addRoute("POST", "/api/users/:username/follow", users.follow);
    try server.addRoute("DELETE", "/api/users/:username/follow", users.unfollow);
    try server.addRoute("GET", "/api/users/:username/followers", users.getFollowers);
    try server.addRoute("GET", "/api/users/:username/following", users.getFollowing);

    // Timeline routes
    try server.addRoute("GET", "/api/timeline", timeline.getTimeline);
    try server.addRoute("GET", "/api/timeline/explore", timeline.getExplore);

    // Health check
    try server.addRoute("GET", "/api/health", healthCheck);
}

fn healthCheck(_: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    try res.json(.{ .status = "ok", .service = "xeetapus" });
}
