const std = @import("std");
const http = @import("http.zig");
const config = @import("config.zig");

pub const AuditEvent = struct {
    timestamp: i64,
    action: []const u8,
    user_id: ?i64,
    ip_address: []const u8,
    user_agent: ?[]const u8,
    details: ?[]const u8,
    success: bool,
};

var log_file: ?std.fs.File = null;
var log_mutex: std.Thread.Mutex = .{};

pub fn init(log_path: []const u8) !void {
    log_mutex.lock();
    defer log_mutex.unlock();

    if (log_file != null) return;

    const file = try std.fs.cwd().createFile(log_path, .{ .read = true, .truncate = false });
    try file.seekFromEnd(0);
    log_file = file;
}

pub fn deinit() void {
    log_mutex.lock();
    defer log_mutex.unlock();

    if (log_file) |file| {
        file.close();
        log_file = null;
    }
}

pub fn log(
    allocator: std.mem.Allocator,
    action: []const u8,
    user_id: ?i64,
    req: *http.Request,
    details: ?[]const u8,
    success: bool,
) void {
    log_mutex.lock();
    defer log_mutex.unlock();

    // Only log in production, or for sensitive actions in development
    const is_sensitive = isSensitiveAction(action);
    if (!config.isProduction() and !is_sensitive) {
        return;
    }

    const timestamp = std.time.timestamp();

    // Get IP address from headers or fall back to remote address
    const ip_address = req.headers.get("X-Forwarded-For") orelse
        req.headers.get("X-Real-IP") orelse blk: {
        // Fall back to remote_addr from connection
        var addr_buf: [64]u8 = undefined;
        const addr_str = std.fmt.bufPrint(&addr_buf, "{}", .{req.remote_addr}) catch "unknown";
        break :blk addr_str;
    };
    const user_agent = req.headers.get("User-Agent");

    // Format log entry as JSON
    const entry = std.fmt.allocPrint(allocator, "{{\"timestamp\":{d},\"action\":\"{s}\",\"user_id\":{s},\"ip\":\"{s}\",\"user_agent\":{s},\"details\":{s},\"success\":{s}}}\n", .{
        timestamp,
        action,
        if (user_id) |id| std.fmt.allocPrint(allocator, "{d}", .{id}) catch "null" else "null",
        ip_address,
        if (user_agent) |ua| std.fmt.allocPrint(allocator, "\"{s}\"", .{ua}) catch "null" else "null",
        if (details) |d| std.fmt.allocPrint(allocator, "\"{s}\"", .{d}) catch "null" else "null",
        if (success) "true" else "false",
    }) catch return;
    defer allocator.free(entry);

    // Write to stdout in development, file in production
    if (config.isProduction()) {
        if (log_file) |file| {
            _ = file.write(entry) catch {};
        }
    } else {
        std.log.info("[AUDIT] {s}", .{entry});
    }
}

fn isSensitiveAction(action: []const u8) bool {
    const sensitive = [_][]const u8{
        "login",
        "register",
        "logout",
        "password_change",
        "password_reset",
        "email_change",
        "account_delete",
        "block",
        "unblock",
    };

    for (sensitive) |s| {
        if (std.mem.eql(u8, action, s)) {
            return true;
        }
    }
    return false;
}

pub fn logAuth(
    allocator: std.mem.Allocator,
    action: []const u8,
    user_id: ?i64,
    req: *http.Request,
    success: bool,
) void {
    log(allocator, action, user_id, req, null, success);
}

pub fn logPostAction(
    allocator: std.mem.Allocator,
    action: []const u8,
    user_id: i64,
    post_id: i64,
    req: *http.Request,
    success: bool,
) void {
    const details = std.fmt.allocPrint(allocator, "post_id:{d}", .{post_id}) catch return;
    defer allocator.free(details);
    log(allocator, action, user_id, req, details, success);
}

pub fn logUserAction(
    allocator: std.mem.Allocator,
    action: []const u8,
    user_id: i64,
    target_user_id: i64,
    req: *http.Request,
    success: bool,
) void {
    const details = std.fmt.allocPrint(allocator, "target_user_id:{d}", .{target_user_id}) catch return;
    defer allocator.free(details);
    log(allocator, action, user_id, req, details, success);
}
