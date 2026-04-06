const std = @import("std");

pub const Config = struct {
    jwt_secret: []const u8,
    database_path: []const u8,
    media_path: []const u8,
    server_port: u16,
    allowed_origins: []const []const u8,
    bcrypt_cost: u6,
    max_request_size: usize,
    rate_limit_requests: u32,
    rate_limit_window_seconds: i64,
    environment: []const u8,
    cookie_secure: bool,
    cookie_http_only: bool,
    cookie_same_site: []const u8,
    csrf_secret: []const u8,

    var instance: ?Config = null;

    pub fn init(allocator: std.mem.Allocator) !void {
        if (instance != null) return;

        const jwt_secret = std.process.getEnvVarOwned(allocator, "XEETAPUS_JWT_SECRET") catch blk: {
            std.log.warn("XEETAPUS_JWT_SECRET not set, using default (INSECURE - CHANGE IN PRODUCTION)", .{});
            break :blk try allocator.dupe(u8, "INSECURE_DEFAULT_SECRET_CHANGE_ME");
        };
        errdefer allocator.free(jwt_secret);

        const db_path = std.process.getEnvVarOwned(allocator, "XEETAPUS_DB_PATH") catch blk: {
            const default_path = try allocator.dupe(u8, "xeetapus.db");
            break :blk default_path;
        };
        errdefer allocator.free(db_path);

        const media_path = std.process.getEnvVarOwned(allocator, "XEETAPUS_MEDIA_PATH") catch blk: {
            const default_path = try allocator.dupe(u8, "/var/www/xeetapus/media");
            break :blk default_path;
        };
        errdefer allocator.free(media_path);

        const port_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_PORT") catch null;
        const port = if (port_str) |s| blk: {
            const p = std.fmt.parseInt(u16, s, 10) catch 8080;
            allocator.free(s);
            break :blk p;
        } else 8080;

        const env = std.process.getEnvVarOwned(allocator, "XEETAPUS_ENV") catch blk: {
            break :blk try allocator.dupe(u8, "development");
        };
        errdefer allocator.free(env);

        const origins_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_ALLOWED_ORIGINS") catch blk: {
            break :blk try allocator.dupe(u8, "http://localhost:3000");
        };
        errdefer allocator.free(origins_str);

        var origins_list: std.ArrayListUnmanaged([]const u8) = .{};
        errdefer origins_list.deinit(allocator);

        var it = std.mem.splitScalar(u8, origins_str, ',');
        while (it.next()) |origin| {
            const trimmed = std.mem.trim(u8, origin, " ");
            if (trimmed.len > 0) {
                try origins_list.append(allocator, try allocator.dupe(u8, trimmed));
            }
        }
        allocator.free(origins_str);

        const csrf_secret = std.process.getEnvVarOwned(allocator, "XEETAPUS_CSRF_SECRET") catch blk: {
            std.log.warn("XEETAPUS_CSRF_SECRET not set, generating random value", .{});
            var buf: [32]u8 = undefined;
            std.crypto.random.bytes(&buf);
            const hex = std.fmt.bytesToHex(buf, .lower);
            break :blk try allocator.dupe(u8, hex[0..]);
        };
        errdefer allocator.free(csrf_secret);

        const bcrypt_cost_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_BCRYPT_COST") catch null;
        const bcrypt_cost: u6 = if (bcrypt_cost_str) |s| blk: {
            const c = std.fmt.parseInt(u6, s, 10) catch 12;
            allocator.free(s);
            break :blk c;
        } else 12;

        const max_size_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_MAX_REQUEST_SIZE") catch null;
        const max_request_size: usize = if (max_size_str) |s| blk: {
            const sz = std.fmt.parseInt(usize, s, 10) catch (10 * 1024 * 1024);
            allocator.free(s);
            break :blk sz;
        } else 10 * 1024 * 1024; // 10MB default

        const rate_limit_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_RATE_LIMIT_REQUESTS") catch null;
        const rate_limit_requests: u32 = if (rate_limit_str) |s| blk: {
            const rl = std.fmt.parseInt(u32, s, 10) catch 100;
            allocator.free(s);
            break :blk rl;
        } else 100;

        const rate_window_str = std.process.getEnvVarOwned(allocator, "XEETAPUS_RATE_LIMIT_WINDOW") catch null;
        const rate_limit_window: i64 = if (rate_window_str) |s| blk: {
            const rw = std.fmt.parseInt(i64, s, 10) catch 60;
            allocator.free(s);
            break :blk rw;
        } else 60;

        const cookie_secure = std.mem.eql(u8, env, "production");
        const cookie_http_only = true;

        instance = Config{
            .jwt_secret = jwt_secret,
            .database_path = db_path,
            .media_path = media_path,
            .server_port = port,
            .allowed_origins = try origins_list.toOwnedSlice(allocator),
            .bcrypt_cost = bcrypt_cost,
            .max_request_size = max_request_size,
            .rate_limit_requests = rate_limit_requests,
            .rate_limit_window_seconds = rate_limit_window,
            .environment = env,
            .cookie_secure = cookie_secure,
            .cookie_http_only = cookie_http_only,
            .cookie_same_site = "Lax",
            .csrf_secret = csrf_secret,
        };
    }

    pub fn get() !*const Config {
        if (instance) |*cfg| {
            return cfg;
        }
        return error.ConfigNotInitialized;
    }

    pub fn isOriginAllowed(origin: []const u8) bool {
        const cfg = instance orelse return true; // Allow all if not configured

        for (cfg.allowed_origins) |allowed| {
            if (std.mem.eql(u8, allowed, origin)) {
                return true;
            }
            // Support wildcard subdomains
            if (std.mem.startsWith(u8, allowed, "*.")) {
                const domain = allowed[2..];
                if (std.mem.endsWith(u8, origin, domain)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn deinit(allocator: std.mem.Allocator) void {
        if (instance) |*cfg| {
            allocator.free(cfg.jwt_secret);
            allocator.free(cfg.database_path);
            allocator.free(cfg.media_path);
            allocator.free(cfg.environment);
            allocator.free(cfg.csrf_secret);
            for (cfg.allowed_origins) |origin| {
                allocator.free(origin);
            }
            allocator.free(cfg.allowed_origins);
            instance = null;
        }
    }
};

pub fn isDevelopment() bool {
    if (Config.instance) |cfg| {
        return std.mem.eql(u8, cfg.environment, "development");
    }
    return true;
}

pub fn isProduction() bool {
    if (Config.instance) |cfg| {
        return std.mem.eql(u8, cfg.environment, "production");
    }
    return false;
}
