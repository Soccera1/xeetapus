const std = @import("std");
const net = std.net;
const config = @import("config.zig");
const ratelimit = @import("ratelimit.zig");

pub const Request = struct {
    method: []const u8,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    params: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,
    remote_addr: net.Address,

    pub fn deinit(self: *Request) void {
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.headers.deinit();
        self.params.deinit();
        self.allocator.free(self.body);
    }
};

pub const Response = struct {
    status: u16 = 200,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Response {
        return .{
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
        self.body.deinit(self.allocator);
    }

    pub fn json(self: *Response, data: anytype) !void {
        self.headers.put("Content-Type", "application/json") catch {};
        try std.json.stringify(data, .{}, self.body.writer());
    }

    pub fn text(self: *Response, content: []const u8) !void {
        self.headers.put("Content-Type", "text/plain") catch {};
        try self.body.appendSlice(self.allocator, content);
    }

    pub fn append(self: *Response, slice: []const u8) !void {
        try self.body.appendSlice(self.allocator, slice);
    }

    pub fn bodyWriter(self: *Response) std.ArrayListUnmanaged(u8).Writer {
        return self.body.writer(self.allocator);
    }

    /// Add security headers to response
    pub fn addSecurityHeaders(self: *Response, is_production: bool) void {
        // Prevent clickjacking
        self.headers.put("X-Frame-Options", "DENY") catch {};

        // Prevent MIME type sniffing
        self.headers.put("X-Content-Type-Options", "nosniff") catch {};

        // XSS Protection
        self.headers.put("X-XSS-Protection", "1; mode=block") catch {};

        // Referrer Policy
        self.headers.put("Referrer-Policy", "strict-origin-when-cross-origin") catch {};

        // Permissions Policy
        self.headers.put("Permissions-Policy", "geolocation=(), microphone=(), camera=()") catch {};

        // Content Security Policy
        self.headers.put("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';") catch {};

        // HSTS in production
        if (is_production) {
            self.headers.put("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload") catch {};
        }
    }

    pub fn send(self: *Response, stream: net.Stream, request_origin: ?[]const u8) !void {
        var writer = stream.writer();

        // Status line
        const status_text = switch (self.status) {
            200 => "OK",
            201 => "Created",
            204 => "No Content",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            429 => "Too Many Requests",
            500 => "Internal Server Error",
            503 => "Service Unavailable",
            else => "Unknown",
        };

        try writer.print("HTTP/1.1 {d} {s}\r\n", .{ self.status, status_text });

        // CORS headers - only allow specific origins
        if (request_origin) |origin| {
            std.log.debug("Checking origin: {s}", .{origin});
            if (config.Config.isOriginAllowed(origin)) {
                std.log.debug("Origin allowed, adding CORS headers", .{});
                try writer.print("Access-Control-Allow-Origin: {s}\r\n", .{origin});
                try writer.writeAll("Access-Control-Allow-Credentials: true\r\n");
            } else {
                std.log.debug("Origin NOT allowed: {s}", .{origin});
            }
        }
        try writer.writeAll("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n");
        try writer.writeAll("Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token\r\n");
        try writer.writeAll("Access-Control-Max-Age: 86400\r\n");

        // Security headers
        var sec_header_iter = self.headers.iterator();
        while (sec_header_iter.next()) |entry| {
            try writer.print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        try writer.print("Content-Length: {d}\r\n", .{self.body.items.len});
        try writer.writeAll("\r\n");

        // Body
        if (self.body.items.len > 0) {
            try writer.writeAll(self.body.items);
        }
    }
};

pub const Handler = *const fn (allocator: std.mem.Allocator, req: *Request, res: *Response) anyerror!void;

pub const Route = struct {
    method: []const u8,
    path: []const u8,
    handler: Handler,
    segments: std.ArrayListUnmanaged([]const u8),
    has_params: bool,
    require_auth: bool,
    rate_limit: bool,

    pub fn init(allocator: std.mem.Allocator, method: []const u8, path: []const u8, handler: Handler, require_auth: bool, rate_limit: bool) !Route {
        var segments: std.ArrayListUnmanaged([]const u8) = .{};
        var has_params = false;

        var it = std.mem.splitScalar(u8, path, '/');
        while (it.next()) |segment| {
            if (segment.len == 0) continue;
            try segments.append(allocator, segment);
            if (segment[0] == ':' or std.mem.eql(u8, segment, "*")) {
                has_params = true;
            }
        }

        return .{
            .method = method,
            .path = path,
            .handler = handler,
            .segments = segments,
            .has_params = has_params,
            .require_auth = require_auth,
            .rate_limit = rate_limit,
        };
    }

    pub fn deinit(self: *Route, allocator: std.mem.Allocator) void {
        self.segments.deinit(allocator);
    }

    pub fn matches(self: Route, request_path: []const u8, params: *std.StringHashMap([]const u8)) !bool {
        var req_segments: std.ArrayListUnmanaged([]const u8) = .{};
        defer req_segments.deinit(params.allocator);

        var it = std.mem.splitScalar(u8, request_path, '/');
        while (it.next()) |segment| {
            if (segment.len == 0) continue;
            try req_segments.append(params.allocator, segment);
        }

        // Check for wildcard route (last segment is *)
        const is_wildcard = self.segments.items.len > 0 and
            std.mem.eql(u8, self.segments.items[self.segments.items.len - 1], "*");

        if (is_wildcard) {
            const non_wildcard_count = self.segments.items.len - 1;
            if (req_segments.items.len < non_wildcard_count) {
                return false;
            }
            for (self.segments.items[0..non_wildcard_count], req_segments.items[0..non_wildcard_count]) |route_seg, req_seg| {
                if (route_seg[0] == ':') {
                    const param_name = route_seg[1..];
                    try params.put(param_name, req_seg);
                } else if (!std.mem.eql(u8, route_seg, req_seg)) {
                    return false;
                }
            }
            if (req_segments.items.len > non_wildcard_count) {
                var offset: usize = 1;
                for (req_segments.items[0..non_wildcard_count]) |seg| {
                    offset += seg.len + 1;
                }
                if (offset < request_path.len) {
                    try params.put("path", request_path[offset..]);
                }
            }
            return true;
        }

        if (req_segments.items.len != self.segments.items.len) {
            return false;
        }

        for (self.segments.items, req_segments.items) |route_seg, req_seg| {
            if (route_seg[0] == ':') {
                // It's a parameter
                const param_name = route_seg[1..];
                try params.put(param_name, req_seg);
            } else if (!std.mem.eql(u8, route_seg, req_seg)) {
                return false;
            }
        }

        return true;
    }
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    port: u16,
    bind_addr: []const u8,
    routes: std.ArrayListUnmanaged(Route),
    rate_limiter: ratelimit.RateLimiter,
    auth_rate_limiter: ratelimit.RateLimiter,
    max_request_size: usize,
    is_production: bool,
    trust_proxy: bool,
    csrf_secret: []const u8,

    pub fn init(allocator: std.mem.Allocator, port: u16) !Server {
        const cfg = config.Config.get() catch {
            return .{
                .allocator = allocator,
                .port = port,
                .bind_addr = "0.0.0.0",
                .routes = .{},
                .rate_limiter = ratelimit.RateLimiter.init(allocator, 100, 60),
                .auth_rate_limiter = ratelimit.RateLimiter.init(allocator, 5, 300),
                .max_request_size = 10 * 1024 * 1024,
                .is_production = false,
                .trust_proxy = false,
                .csrf_secret = "",
            };
        };

        return .{
            .allocator = allocator,
            .port = port,
            .bind_addr = cfg.bind_addr,
            .routes = .{},
            .rate_limiter = ratelimit.RateLimiter.init(allocator, cfg.rate_limit_requests, cfg.rate_limit_window_seconds),
            .auth_rate_limiter = ratelimit.RateLimiter.init(allocator, cfg.auth_rate_limit_requests, cfg.auth_rate_limit_window_seconds),
            .max_request_size = cfg.max_request_size,
            .is_production = config.isProduction(),
            .trust_proxy = cfg.trust_proxy,
            .csrf_secret = cfg.csrf_secret,
        };
    }

    pub fn deinit(self: *Server) void {
        for (self.routes.items) |*route| {
            route.deinit(self.allocator);
        }
        self.routes.deinit(self.allocator);
        self.rate_limiter.deinit();
        self.auth_rate_limiter.deinit();
    }

    pub fn addRoute(self: *Server, method: []const u8, path: []const u8, handler: Handler) !void {
        // By default, require auth for POST/PUT/DELETE
        const require_auth = std.mem.eql(u8, method, "POST") or
            std.mem.eql(u8, method, "PUT") or
            std.mem.eql(u8, method, "DELETE");
        const rate_limit = true;

        const route = try Route.init(self.allocator, method, path, handler, require_auth, rate_limit);
        try self.routes.append(self.allocator, route);
    }

    pub fn addPublicRoute(self: *Server, method: []const u8, path: []const u8, handler: Handler) !void {
        const route = try Route.init(self.allocator, method, path, handler, false, true);
        try self.routes.append(self.allocator, route);
    }

    pub fn addUnlimitedRoute(self: *Server, method: []const u8, path: []const u8, handler: Handler) !void {
        const require_auth = std.mem.eql(u8, method, "POST") or
            std.mem.eql(u8, method, "PUT") or
            std.mem.eql(u8, method, "DELETE");
        const route = try Route.init(self.allocator, method, path, handler, require_auth, false);
        try self.routes.append(self.allocator, route);
    }

    pub fn start(self: *Server) !void {
        const address = try net.Address.parseIp4(self.bind_addr, self.port);
        var listener = try net.Address.listen(address, .{
            .reuse_address = true,
        });
        defer listener.deinit();

        std.log.info("Server listening on port {d}", .{self.port});

        while (true) {
            const connection = try listener.accept();

            // Spawn a thread to handle the connection
            const thread = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
            thread.detach();
        }
    }

    fn handleConnection(self: *Server, connection: net.Server.Connection) void {
        defer connection.stream.close();

        const request_data = self.readRequestData(connection.stream) catch |err| {
            if (err == error.RequestTooLarge) {
                var res = Response.init(self.allocator);
                defer res.deinit();
                res.status = 413;
                res.headers.put("Content-Type", "text/plain") catch {};
                res.append("Request entity too large") catch {};
                res.addSecurityHeaders(self.is_production);
                res.send(connection.stream, null) catch |send_err| {
                    std.log.debug("Failed to send 413 response: {s}", .{@errorName(send_err)});
                };
                return;
            }

            std.log.err("Failed to read from connection: {s}", .{@errorName(err)});
            return;
        };
        defer self.allocator.free(request_data);

        if (request_data.len == 0) return;

        var req = self.parseRequest(request_data, connection.address) catch |err| {
            std.log.err("Failed to parse request: {s}", .{@errorName(err)});
            return;
        };
        defer req.deinit();

        var res = Response.init(self.allocator);
        defer res.deinit();

        // Add security headers
        res.addSecurityHeaders(self.is_production);

        // Get origin for CORS
        const origin = req.headers.get("origin");

        // Handle CORS preflight
        if (std.mem.eql(u8, req.method, "OPTIONS")) {
            res.status = 204;
            res.send(connection.stream, origin) catch |err| {
                std.log.debug("Failed to send CORS preflight: {s}", .{@errorName(err)});
            };
            return;
        }

        // Check rate limit
        var remote_ip_buf: [64]u8 = undefined;
        const remote_ip = ratelimit.formatRemoteAddr(connection.address, &remote_ip_buf);
        const client_ip = ratelimit.getClientIp(remote_ip, req.headers, self.trust_proxy);
        var rate_key_buf: [512]u8 = undefined;
        const rate_key = std.fmt.bufPrint(&rate_key_buf, "{s}:{s}", .{ client_ip, req.path }) catch client_ip;

        const allowed = self.rate_limiter.check(rate_key) catch {
            res.status = 500;
            res.append("Rate limiter error") catch {};
            res.send(connection.stream, origin) catch |err| {
                std.log.debug("Failed to send rate limiter error: {s}", .{@errorName(err)});
            };
            return;
        };

        if (!allowed) {
            res.status = 429;
            const status = self.rate_limiter.getStatus(rate_key);
            var limit_buf: [32]u8 = undefined;
            var reset_buf: [32]u8 = undefined;
            var retry_buf: [32]u8 = undefined;
            res.headers.put("X-RateLimit-Limit", std.fmt.bufPrint(&limit_buf, "{d}", .{self.rate_limiter.max_requests}) catch "100") catch {};
            res.headers.put("X-RateLimit-Remaining", "0") catch {};
            res.headers.put("X-RateLimit-Reset", std.fmt.bufPrint(&reset_buf, "{d}", .{status.reset_time}) catch "0") catch {};
            res.headers.put("Retry-After", std.fmt.bufPrint(&retry_buf, "{d}", .{status.reset_time - std.time.timestamp()}) catch "60") catch {};
            res.append("{\"error\":\"Rate limit exceeded\"}") catch {};
            res.send(connection.stream, origin) catch |err| {
                std.log.debug("Failed to send rate limit response: {s}", .{@errorName(err)});
            };
            return;
        }

        // Stricter rate limiting for authentication endpoints
        const is_auth_endpoint = std.mem.eql(u8, req.path, "/api/auth/register") or
            std.mem.eql(u8, req.path, "/api/auth/login");
        if (is_auth_endpoint) {
            var auth_key_buf: [512]u8 = undefined;
            const auth_key = std.fmt.bufPrint(&auth_key_buf, "auth:{s}", .{client_ip}) catch client_ip;
            const auth_allowed = self.auth_rate_limiter.check(auth_key) catch {
                res.status = 500;
                res.append("Rate limiter error") catch {};
                res.send(connection.stream, origin) catch {};
                return;
            };
            if (!auth_allowed) {
                res.status = 429;
                res.headers.put("Content-Type", "application/json") catch {};
                res.append("{\"error\":\"Too many authentication attempts. Please try again later.\"}") catch {};
                res.send(connection.stream, origin) catch {};
                return;
            }
        }

        // CSRF token validation for state-changing requests
        const is_state_changing = std.mem.eql(u8, req.method, "POST") or
            std.mem.eql(u8, req.method, "PUT") or
            std.mem.eql(u8, req.method, "DELETE");
        if (is_state_changing) {
            const auth_cookie = blk: {
                if (req.headers.get("cookie")) |cookie_header| {
                    var it = std.mem.splitScalar(u8, cookie_header, ';');
                    while (it.next()) |cookie| {
                        const trimmed = std.mem.trim(u8, cookie, " ");
                        if (std.mem.startsWith(u8, trimmed, "auth_token=")) {
                            break :blk trimmed[11..];
                        }
                    }
                }
                break :blk @as(?[]const u8, null);
            };

            if (auth_cookie) |token| {
                const csrf_header = req.headers.get("x-csrf-token") orelse {
                    res.status = 403;
                    res.headers.put("Content-Type", "application/json") catch {};
                    res.append("{\"error\":\"CSRF token required\"}") catch {};
                    res.send(connection.stream, origin) catch {};
                    return;
                };
                if (!@import("tokens.zig").verifyCsrfToken(self.csrf_secret, token, csrf_header)) {
                    res.status = 403;
                    res.headers.put("Content-Type", "application/json") catch {};
                    res.append("{\"error\":\"Invalid CSRF token\"}") catch {};
                    res.send(connection.stream, origin) catch {};
                    return;
                }
            }
        }

        // Find matching route
        var found = false;
        var best_match: ?usize = null;

        for (self.routes.items, 0..) |route, idx| {
            if (!std.mem.eql(u8, route.method, req.method)) continue;

            if (route.has_params) {
                var params = std.StringHashMap([]const u8).init(self.allocator);
                defer params.deinit();

                if (route.matches(req.path, &params) catch false) {
                    best_match = idx;
                    break;
                }
            } else {
                if (std.mem.eql(u8, route.path, req.path)) {
                    best_match = idx;
                    break;
                }
                if (std.mem.startsWith(u8, req.path, route.path) and route.path.len > 1) {
                    const after_match = req.path[route.path.len..];
                    if (after_match.len == 0 or after_match[0] == '/') {
                        if (best_match == null or route.path.len > self.routes.items[best_match.?].path.len) {
                            best_match = idx;
                        }
                    }
                }
            }
        }

        // Execute the best matching route
        if (best_match) |idx| {
            const route = self.routes.items[idx];

            // Populate params if route has them
            if (route.has_params) {
                var params = std.StringHashMap([]const u8).init(self.allocator);
                defer params.deinit();
                if (route.matches(req.path, &params) catch false) {
                    var iter = params.iterator();
                    while (iter.next()) |entry| {
                        req.params.put(entry.key_ptr.*, entry.value_ptr.*) catch {};
                    }
                }
            }

            route.handler(self.allocator, &req, &res) catch |err| {
                std.log.err("Handler error: {s}", .{@errorName(err)});
                res.status = 500;
                const error_response = "{\"error\":\"Internal Server Error\"}";
                res.headers.put("Content-Type", "application/json") catch {};
                res.append(error_response) catch {};
            };
            found = true;
        }

        if (!found) {
            res.status = 404;
            const error_response = "{\"error\":\"Not Found\"}";
            res.headers.put("Content-Type", "application/json") catch {};
            res.append(error_response) catch {};
        }

        res.send(connection.stream, origin) catch |err| {
            std.log.debug("Failed to send response: {s}", .{@errorName(err)});
        };
    }

    fn readRequestData(self: *Server, stream: net.Stream) ![]u8 {
        var data = std.ArrayListUnmanaged(u8){};
        errdefer data.deinit(self.allocator);

        var chunk: [4096]u8 = undefined;
        var header_end: ?usize = null;
        var content_length: ?usize = null;
        var expects_body = false;

        while (true) {
            const bytes_read = try stream.read(&chunk);
            if (bytes_read == 0) break;

            try data.appendSlice(self.allocator, chunk[0..bytes_read]);
            if (data.items.len > self.max_request_size) {
                return error.RequestTooLarge;
            }

            if (header_end == null) {
                if (std.mem.indexOf(u8, data.items, "\r\n\r\n")) |idx| {
                    header_end = idx;
                    expects_body = requestExpectsBody(data.items[0..idx]);
                    content_length = parseContentLength(data.items[0..idx]) catch null;

                    if (!expects_body or content_length == 0) {
                        break;
                    }
                }
            }

            if (header_end) |idx| {
                if (content_length) |len| {
                    const total_needed = idx + 4 + len;
                    if (data.items.len >= total_needed) {
                        break;
                    }
                }
            }
        }

        return try data.toOwnedSlice(self.allocator);
    }

    fn parseRequest(self: *Server, data: []const u8, remote_addr: net.Address) !Request {
        var lines = std.mem.splitScalar(u8, data, '\n');

        // Parse request line
        const request_line = lines.next() orelse return error.InvalidRequest;
        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method = parts.next() orelse return error.InvalidRequest;
        const path = parts.next() orelse return error.InvalidRequest;

        // Parse headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer headers.deinit();

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, "\r\n ");
            if (trimmed.len == 0) break;

            if (std.mem.indexOf(u8, trimmed, ": ")) |colon_pos| {
                const key_raw = trimmed[0..colon_pos];
                // Use a fixed-size buffer for keys up to 63 chars
                if (key_raw.len < 64) {
                    var key_buf: [64]u8 = undefined;
                    for (key_raw, 0..) |c, i| {
                        key_buf[i] = std.ascii.toLower(c);
                    }
                    const key_lower = key_buf[0..key_raw.len];
                    const value = trimmed[colon_pos + 2 ..];

                    // Check if key already exists before duplicating
                    if (!headers.contains(key_lower)) {
                        const key = try self.allocator.dupe(u8, key_lower);
                        // Use putNoClobber to catch duplicate insertion attempts
                        headers.putNoClobber(key, value) catch {
                            // Key already exists (race condition or hash collision), free and continue
                            self.allocator.free(key);
                        };
                    }
                }
                // Skip headers with keys >= 64 chars
            }
        }

        // Parse body
        const body_start = std.mem.indexOf(u8, data, "\r\n\r\n") orelse data.len;
        const body = if (body_start + 4 < data.len) data[body_start + 4 ..] else "";

        // Limit body size
        if (body.len > self.max_request_size) {
            return error.RequestTooLarge;
        }

        const body_copy = try self.allocator.dupe(u8, body);

        const params = std.StringHashMap([]const u8).init(self.allocator);

        return Request{
            .method = method,
            .path = path,
            .headers = headers,
            .body = body_copy,
            .params = params,
            .allocator = self.allocator,
            .remote_addr = remote_addr,
        };
    }
};

fn requestExpectsBody(request_head: []const u8) bool {
    var lines = std.mem.splitSequence(u8, request_head, "\r\n");
    const request_line = lines.next() orelse return false;
    var parts = std.mem.splitScalar(u8, request_line, ' ');
    const method = parts.next() orelse return false;

    return std.mem.eql(u8, method, "POST") or
        std.mem.eql(u8, method, "PUT") or
        std.mem.eql(u8, method, "PATCH");
}

fn parseContentLength(request_head: []const u8) !usize {
    var lines = std.mem.splitSequence(u8, request_head, "\r\n");
    _ = lines.next();

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.indexOfScalar(u8, line, ':')) |colon_idx| {
            const key = std.mem.trim(u8, line[0..colon_idx], " ");
            const value = std.mem.trim(u8, line[colon_idx + 1 ..], " ");
            if (std.ascii.eqlIgnoreCase(key, "Content-Length")) {
                return std.fmt.parseInt(usize, value, 10);
            }
        }
    }

    return 0;
}
