const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const json_utils = @import("json.zig");
const security = @import("security.zig");
const config = @import("config.zig");
const audit = @import("audit.zig");

// Token expiration: 24 hours
const TOKEN_EXPIRATION_SECONDS = 86400;

// Critical security migration deadline for legacy hashes (bcrypt/sha256)
// These old hashes are considered insecure and must be migrated
const LEGACY_MIGRATION_DEADLINE: i64 = 1775040000; // April 6, 2026

pub const User = struct {
    id: i64,
    username: []const u8,
    email: []const u8,
    display_name: ?[]const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    created_at: []const u8,
    password_migrated_at: ?[]const u8,
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

    // Validate username
    if (security.validation.validateUsername(body.username)) |err_msg| {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.bodyWriter().print("{{\"error\":\"{s}\"}}", .{err_msg});
        return;
    }

    // Validate password
    if (security.validation.validatePassword(body.password)) |err_msg| {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.bodyWriter().print("{{\"error\":\"{s}\"}}", .{err_msg});
        return;
    }

    // Validate email
    if (security.validation.validateEmail(body.email)) |err_msg| {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.bodyWriter().print("{{\"error\":\"{s}\"}}", .{err_msg});
        return;
    }

    // Hash password using argon2id
    const password_hash = try security.hashPassword(allocator, body.password);
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
        try res.append("{\"error\":\"Username or email already exists\"}");
        return;
    };

    const user_id = db.lastInsertRowId();

    // Get config for JWT secret
    const cfg = try config.Config.get();

    // Generate secure signed token
    const token = try security.generateSignedToken(allocator, cfg.jwt_secret, user_id, TOKEN_EXPIRATION_SECONDS);

    // Generate CSRF token bound to auth token
    const csrf_token = try security.tokens.generateCsrfToken(allocator, cfg.csrf_secret, token);

    // Set HTTP-only cookie with auth token
    const cookie_secure = if (cfg.cookie_secure) "; Secure" else "";
    const cookie_str = try std.fmt.allocPrint(allocator, "auth_token={s}; HttpOnly{s}; SameSite=Lax; Path=/; Max-Age={d}", .{
        token, cookie_secure, TOKEN_EXPIRATION_SECONDS,
    });
    res.headers.put("Set-Cookie", cookie_str) catch {};

    // Log successful registration
    audit.logAuth(allocator, "register", user_id, req, true);

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username = try json_utils.escapeJson(allocator, body.username);
    defer allocator.free(escaped_username);
    const escaped_email = try json_utils.escapeJson(allocator, body.email);
    defer allocator.free(escaped_email);
    const escaped_csrf = try json_utils.escapeJson(allocator, csrf_token);
    try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"token\":\"{s}\",\"csrf_token\":\"{s}\"}}", .{ user_id, escaped_username, escaped_email, token, escaped_csrf });
    allocator.free(escaped_csrf);
    allocator.free(csrf_token);
    // Note: cookie_str and token are stored in response headers and must not be freed here
    // They will be freed when the response is deallocated
}

pub fn login(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const parsed = try std.json.parseFromSlice(LoginRequest, allocator, req.body, .{});
    defer parsed.deinit();

    const body = parsed.value;

    const sql = "SELECT id, username, email, password_hash, legacy_password_hash, password_migrated_at FROM users WHERE username = ?";
    const UserWithPassword = struct {
        id: i64,
        username: []const u8,
        email: []const u8,
        password_hash: []const u8,
        legacy_password_hash: ?[]const u8,
        password_migrated_at: ?[]const u8,
    };

    const rows = db.query(UserWithPassword, allocator, sql, &[_][]const u8{body.username}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(UserWithPassword, allocator, rows);

    if (rows.len == 0) {
        audit.logAuth(allocator, "login", null, req, false);
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid credentials\"}");
        return;
    }

    const user = rows[0];

    if (!try security.verifyPassword(allocator, body.password, user.password_hash)) {
        audit.logAuth(allocator, "login", user.id, req, false);
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid credentials\"}");
        return;
    }

    const now = std.time.timestamp();
    var password_migrated = false;
    var migration_message: ?[]const u8 = null;
    defer if (migration_message) |msg| allocator.free(msg);

    // Check for critical legacy hashes (legacy_sha256) that must be migrated before deadline
    if (security.isCriticalLegacyHash(user.password_hash)) {
        if (now > LEGACY_MIGRATION_DEADLINE) {
            res.status = 403;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Password security upgrade required. Please reset your password.\",\"migration_required\":true}");
            return;
        }
    }

    // Check if password needs migration
    if (security.isLegacyPasswordHash(user.password_hash)) {
        // Migrate to argon2id on successful login
        const new_hash = try security.hashPassword(allocator, body.password);
        defer allocator.free(new_hash);

        const now_str = try std.fmt.allocPrint(allocator, "{d}", .{now});
        defer allocator.free(now_str);

        const update_sql =
            \\UPDATE users 
            \\SET password_hash = ?, 
            \\    password_migrated_at = ?
            \\WHERE id = ?
        ;
        const update_params = [_][]const u8{ new_hash, now_str, try std.fmt.allocPrint(allocator, "{d}", .{user.id}) };
        defer allocator.free(update_params[2]);

        db.execute(update_sql, &update_params) catch {
            std.log.err("Failed to migrate password for user {d}", .{user.id});
        };

        password_migrated = true;
        migration_message = try std.fmt.allocPrint(allocator, "Password hashing has been upgraded to argon2id for improved security.", .{});
        std.log.info("Migrated password for user {d} to argon2id", .{user.id});
    }

    const cfg = try config.Config.get();
    const token = try security.generateSignedToken(allocator, cfg.jwt_secret, user.id, TOKEN_EXPIRATION_SECONDS);

    const csrf_token = try security.tokens.generateCsrfToken(allocator, cfg.csrf_secret, token);

    const cookie_secure = if (cfg.cookie_secure) "; Secure" else "";
    const cookie_str = try std.fmt.allocPrint(allocator, "auth_token={s}; HttpOnly{s}; SameSite=Lax; Path=/; Max-Age={d}", .{
        token, cookie_secure, TOKEN_EXPIRATION_SECONDS,
    });
    res.headers.put("Set-Cookie", cookie_str) catch {};

    audit.logAuth(allocator, "login", user.id, req, true);

    res.headers.put("Content-Type", "application/json") catch {};
    const escaped_username2 = try json_utils.escapeJson(allocator, user.username);
    defer allocator.free(escaped_username2);
    const escaped_email2 = try json_utils.escapeJson(allocator, user.email);
    defer allocator.free(escaped_email2);
    const escaped_csrf = try json_utils.escapeJson(allocator, csrf_token);

    if (password_migrated) {
        const escaped_msg = try json_utils.escapeJson(allocator, migration_message.?);
        defer allocator.free(escaped_msg);
        try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"token\":\"{s}\",\"csrf_token\":\"{s}\",\"password_migrated\":true,\"migration_message\":\"{s}\"}}", .{
            user.id, escaped_username2, escaped_email2, token, escaped_csrf, escaped_msg,
        });
    } else {
        try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"token\":\"{s}\",\"csrf_token\":\"{s}\",\"password_migrated\":false}}", .{
            user.id, escaped_username2, escaped_email2, token, escaped_csrf,
        });
    }
    allocator.free(escaped_csrf);
    allocator.free(csrf_token);
}

pub fn logout(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Get user ID before clearing cookie
    const user_id = try getUserIdFromRequest(allocator, req);

    // Clear the auth cookie
    res.headers.put("Set-Cookie", "auth_token=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0") catch {};
    res.headers.put("Content-Type", "application/json") catch {};

    // Log logout
    audit.logAuth(allocator, "logout", user_id, req, true);

    try res.append("{\"message\":\"Logged out successfully\"}");
}

pub fn me(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const sql = "SELECT id, username, email, display_name, bio, avatar_url, created_at, password_hash, password_migrated_at FROM users WHERE id = ?";
    const UserWithMigration = struct {
        id: i64,
        username: []const u8,
        email: []const u8,
        display_name: ?[]const u8,
        bio: ?[]const u8,
        avatar_url: ?[]const u8,
        created_at: []const u8,
        password_hash: []const u8,
        password_migrated_at: ?[]const u8,
    };

    const rows = db.query(UserWithMigration, allocator, sql, &[_][]const u8{try std.fmt.allocPrint(allocator, "{d}", .{user_id})}) catch {
        res.status = 500;
        return;
    };
    defer db.freeRows(UserWithMigration, allocator, rows);

    if (rows.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"User not found\"}");
        return;
    }

    const user = rows[0];

    // Check if user has a critical legacy hash past deadline - force logout
    const now = std.time.timestamp();
    if (security.isCriticalLegacyHash(user.password_hash) and now > LEGACY_MIGRATION_DEADLINE) {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        res.headers.put("Set-Cookie", "auth_token=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0") catch {};
        try res.append("{\"error\":\"Password security upgrade required. Please log in to update your password.\",\"migration_required\":true}");
        return;
    }

    // Check if password needs migration
    const needs_migration = user.password_migrated_at == null or (user.password_migrated_at != null and user.password_migrated_at.?.len == 0);

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

    const migration_status = if (needs_migration) "pending" else "completed";
    try res.bodyWriter().print("{{\"id\":{d},\"username\":\"{s}\",\"email\":\"{s}\",\"display_name\":\"{s}\",\"bio\":\"{s}\",\"avatar_url\":\"{s}\",\"created_at\":\"{s}\",\"password_migration_status\":\"{s}\"}}", .{
        user.id, escaped_username3, escaped_email3, escaped_display_name, escaped_bio, escaped_avatar_url, escaped_created_at, migration_status,
    });
}

pub fn getUserIdFromRequest(allocator: std.mem.Allocator, req: *http.Request) !?i64 {
    std.log.debug("getUserIdFromRequest: checking for cookie header", .{});
    if (req.headers.get("cookie")) |cookie_header| {
        std.log.debug("getUserIdFromRequest: cookie header found: {s}", .{cookie_header});
        var it = std.mem.splitScalar(u8, cookie_header, ';');
        while (it.next()) |cookie| {
            const trimmed = std.mem.trim(u8, cookie, " ");
            std.log.debug("getUserIdFromRequest: checking cookie: {s}", .{trimmed});
            if (std.mem.startsWith(u8, trimmed, "auth_token=")) {
                const token = trimmed[11..];
                std.log.debug("getUserIdFromRequest: found auth_token, verifying...", .{});
                const cfg = try config.Config.get();
                const result = security.verifySignedToken(allocator, cfg.jwt_secret, token) catch |err| {
                    std.log.debug("getUserIdFromRequest: token verification failed: {s}", .{@errorName(err)});
                    return null;
                };
                std.log.debug("getUserIdFromRequest: token verified, user_id={?}", .{result});
                return result;
            }
        }
        std.log.debug("getUserIdFromRequest: no auth_token cookie found", .{});
    } else {
        std.log.debug("getUserIdFromRequest: no cookie header at all", .{});
    }

    std.log.debug("getUserIdFromRequest: checking Authorization header", .{});
    const auth_header = req.headers.get("authorization") orelse return null;

    if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
        return null;
    }

    const token = auth_header[7..];

    // Verify signed token
    const cfg = try config.Config.get();
    return try security.verifySignedToken(allocator, cfg.jwt_secret, token);
}
