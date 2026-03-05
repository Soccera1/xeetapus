const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const json_utils = @import("json.zig");
const crypto = @import("std").crypto;

const JWT_SECRET = "xeetapus-secret-key-change-in-production";

pub const User = struct {
    id: i64,
    username: []const u8,
    email: []const u8,
    display_name: ?[]const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    created_at: []const u8,
};

pub const RegisterRequest = struct {
    username: []const u8,
    email: []const u8,
    password: []const u8,
};

pub const LoginRequest = struct {
    username: []const u8,
    password: []const u8,
};

pub fn register(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const parsed = try std.json.parseFromSlice(RegisterRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Validate input
    if (body.username.len < 3 or body.username.len > 30) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Username must be between 3 and 30 characters\"}");
        return;
    }

    if (body.password.len < 6) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Password must be at least 6 characters\"}");
        return;
    }

    // Hash password
    const password_hash = try hashPassword(allocator, body.password);
    defer allocator.free(password_hash);

    // Insert user
    const sql =
        \\INSERT INTO users (username, email, password_hash, display_name) 
        \\VALUES (?, ?, ?, ?)
    ;
    const params = [_][]const u8{ body.username, body.email, password_hash, body.username };

    db.execute(sql, &params) catch {
        res.status = 409;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Username or email already exists\"}");
        return;
    };

    const user_id = db.lastInsertRowId();

    // Generate token
    const token = try generateToken(allocator, user_id);
    defer allocator.free(token);

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username = try json_utils.escapeJson(allocator, body.username);
    defer allocator.free(escaped_username);
    const escaped_email = try json_utils.escapeJson(allocator, body.email);
    defer allocator.free(escaped_email);
    try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"token\":\"{s}\"}}", .{ user_id, escaped_username, escaped_email, token });
}

pub fn login(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const parsed = try std.json.parseFromSlice(LoginRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    // Query user
    const sql = "SELECT id, username, email, password_hash FROM users WHERE username = ?";
    const UserWithPassword = struct {
        id: i64,
        username: []const u8,
        email: []const u8,
        password_hash: []const u8,
    };

    const rows = db.query(UserWithPassword, allocator, sql, &[_][]const u8{body.username}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(UserWithPassword, allocator, rows);

    if (rows.len == 0) {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid credentials\"}");
        return;
    }

    const user = rows[0];

    // Verify password
    if (!try verifyPassword(allocator, body.password, user.password_hash)) {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid credentials\"}");
        return;
    }

    // Generate token
    const token = try generateToken(allocator, user.id);
    defer allocator.free(token);

    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username2 = try json_utils.escapeJson(allocator, user.username);
    defer allocator.free(escaped_username2);
    const escaped_email2 = try json_utils.escapeJson(allocator, user.email);
    defer allocator.free(escaped_email2);
    try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"token\":\"{s}\"}}", .{ user.id, escaped_username2, escaped_email2, token });
}

pub fn me(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql = "SELECT id, username, email, display_name, bio, avatar_url, created_at FROM users WHERE id = ?";
    const rows = db.query(User, allocator, sql, &[_][]const u8{try std.fmt.allocPrint(allocator, "{d}", .{user_id})}) catch {
        res.status = 500;
        return;
    };
    defer db.freeRows(User, allocator, rows);

    if (rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    }

    const user = rows[0];
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username3 = try json_utils.escapeJson(allocator, user.username);
    defer allocator.free(escaped_username3);
    const escaped_email3 = try json_utils.escapeJson(allocator, user.email);
    defer allocator.free(escaped_email3);
    const escaped_display_name = try json_utils.escapeJson(allocator, user.display_name orelse "");
    defer allocator.free(escaped_display_name);
    const escaped_bio = try json_utils.escapeJson(allocator, user.bio orelse "");
    defer allocator.free(escaped_bio);
    const escaped_avatar_url = try json_utils.escapeJson(allocator, user.avatar_url orelse "");
    defer allocator.free(escaped_avatar_url);
    const escaped_created_at = try json_utils.escapeJson(allocator, user.created_at);
    defer allocator.free(escaped_created_at);
    try res.body.writer().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"display_name\":\"{s}\",\"bio\":\"{s}\",\"avatar_url\":\"{s}\",\"created_at\":\"{s}\"}}", .{ user.id, escaped_username3, escaped_email3, escaped_display_name, escaped_bio, escaped_avatar_url, escaped_created_at });
}

fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]u8 {
    // Simple bcrypt-like hashing using SHA256 for demo
    var hash: [32]u8 = undefined;
    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.update("xeetapus-salt");
    hasher.final(&hash);

    const hex_hash = try allocator.alloc(u8, 64);
    _ = try std.fmt.bufPrint(hex_hash, "{s}", .{std.fmt.fmtSliceHexLower(&hash)});
    return hex_hash;
}

fn verifyPassword(allocator: std.mem.Allocator, password: []const u8, hash: []const u8) !bool {
    const computed = try hashPassword(allocator, password);
    defer allocator.free(computed);
    return std.mem.eql(u8, computed, hash);
}

fn generateToken(allocator: std.mem.Allocator, user_id: i64) ![]u8 {
    // Simple token generation
    const token = try std.fmt.allocPrint(allocator, "token_{d}_{d}", .{ user_id, std.time.timestamp() });
    return token;
}

pub fn getUserIdFromRequest(_: std.mem.Allocator, req: *http.Request) !?i64 {
    const auth_header = req.headers.get("Authorization") orelse return null;

    if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
        return null;
    }

    const token = auth_header[7..];

    // Simple token parsing (in production, use proper JWT)
    if (std.mem.startsWith(u8, token, "token_")) {
        var parts = std.mem.splitScalar(u8, token, '_');
        _ = parts.next(); // skip "token"
        if (parts.next()) |user_id_str| {
            return try std.fmt.parseInt(i64, user_id_str, 10);
        }
    }

    return null;
}
