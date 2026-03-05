const std = @import("std");
const net = std.net;

pub const Request = struct {
    method: []const u8,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    params: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.params.deinit();
        self.allocator.free(self.body);
    }
};

pub const Response = struct {
    status: u16 = 200,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Response {
        return .{
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
        self.body.deinit();
    }

    pub fn json(self: *Response, data: anytype) !void {
        self.headers.put("Content-Type", "application/json") catch {};
        try std.json.stringify(data, .{}, self.body.writer());
    }

    pub fn text(self: *Response, content: []const u8) !void {
        self.headers.put("Content-Type", "text/plain") catch {};
        try self.body.appendSlice(content);
    }

    pub fn send(self: *Response, stream: net.Stream) !void {
        const writer = stream.writer();

        // Status line
        const status_text = switch (self.status) {
            200 => "OK",
            201 => "Created",
            400 => "Bad Request",
            401 => "Unauthorized",
            404 => "Not Found",
            500 => "Internal Server Error",
            else => "Unknown",
        };

        try writer.print("HTTP/1.1 {d} {s}\r\n", .{ self.status, status_text });

        // Headers
        try writer.writeAll("Access-Control-Allow-Origin: *\r\n");
        try writer.writeAll("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n");
        try writer.writeAll("Access-Control-Allow-Headers: Content-Type, Authorization\r\n");

        var header_iter = self.headers.iterator();
        while (header_iter.next()) |entry| {
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
    segments: std.ArrayList([]const u8),
    has_params: bool,

    pub fn init(allocator: std.mem.Allocator, method: []const u8, path: []const u8, handler: Handler) !Route {
        var segments = std.ArrayList([]const u8).init(allocator);
        var has_params = false;

        var it = std.mem.splitScalar(u8, path, '/');
        while (it.next()) |segment| {
            if (segment.len == 0) continue;
            try segments.append(segment);
            if (segment[0] == ':') {
                has_params = true;
            }
        }

        return .{
            .method = method,
            .path = path,
            .handler = handler,
            .segments = segments,
            .has_params = has_params,
        };
    }

    pub fn deinit(self: *Route) void {
        self.segments.deinit();
    }

    pub fn matches(self: Route, request_path: []const u8, params: *std.StringHashMap([]const u8)) !bool {
        var req_segments = std.ArrayList([]const u8).init(params.allocator);
        defer req_segments.deinit();

        var it = std.mem.splitScalar(u8, request_path, '/');
        while (it.next()) |segment| {
            if (segment.len == 0) continue;
            try req_segments.append(segment);
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
    routes: std.ArrayList(Route),

    pub fn init(allocator: std.mem.Allocator, port: u16) !Server {
        return .{
            .allocator = allocator,
            .port = port,
            .routes = std.ArrayList(Route).init(allocator),
        };
    }

    pub fn deinit(self: *Server) void {
        self.routes.deinit();
    }

    pub fn addRoute(self: *Server, method: []const u8, path: []const u8, handler: Handler) !void {
        const route = try Route.init(self.allocator, method, path, handler);
        try self.routes.append(route);
    }

    pub fn start(self: *Server) !void {
        const address = try net.Address.parseIp4("0.0.0.0", self.port);
        var listener = try net.Address.listen(address, .{
            .reuse_address = true,
            .reuse_port = true,
        });
        defer listener.deinit();

        std.log.info("Server listening on port {d}", .{self.port});

        while (true) {
            const connection = try listener.accept();
            _ = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
        }
    }

    fn handleConnection(self: *Server, connection: net.Server.Connection) void {
        defer connection.stream.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buf) catch |err| {
            std.log.err("Failed to read from connection: {s}", .{@errorName(err)});
            return;
        };

        if (bytes_read == 0) return;

        var req = self.parseRequest(buf[0..bytes_read]) catch |err| {
            std.log.err("Failed to parse request: {s}", .{@errorName(err)});
            return;
        };
        defer req.deinit();

        var res = Response.init(self.allocator);
        defer res.deinit();

        // Handle CORS preflight
        if (std.mem.eql(u8, req.method, "OPTIONS")) {
            res.status = 204;
            res.send(connection.stream) catch {};
            return;
        }

        // Find matching route
        var found = false;
        var best_match: ?usize = null;

        // Try to find a route match
        for (self.routes.items, 0..) |route, idx| {
            if (!std.mem.eql(u8, route.method, req.method)) continue;

            if (route.has_params) {
                // Route has parameters, use segment matching
                var params = std.StringHashMap([]const u8).init(self.allocator);
                defer params.deinit();

                if (route.matches(req.path, &params) catch false) {
                    best_match = idx;
                    break;
                }
            } else {
                // Static route - check exact or prefix match
                if (std.mem.eql(u8, route.path, req.path)) {
                    best_match = idx;
                    break;
                }
                if (std.mem.startsWith(u8, req.path, route.path) and route.path.len > 1) {
                    const after_match = req.path[route.path.len..];
                    if (after_match.len == 0 or after_match[0] == '/') {
                        // For static prefix routes, prefer longer matches
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
                    // Copy params to request
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
                res.body.appendSlice(error_response) catch {};
            };
            found = true;
        }

        if (!found) {
            res.status = 404;
            const error_response = "{\"error\":\"Not Found\"}";
            res.headers.put("Content-Type", "application/json") catch {};
            res.body.appendSlice(error_response) catch {};
        }

        res.send(connection.stream) catch {};
    }

    fn parseRequest(self: *Server, data: []const u8) !Request {
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
                const key = trimmed[0..colon_pos];
                const value = trimmed[colon_pos + 2 ..];
                try headers.put(key, value);
            }
        }

        // Parse body
        const body_start = std.mem.indexOf(u8, data, "\r\n\r\n") orelse data.len;
        const body = if (body_start + 4 < data.len) data[body_start + 4 ..] else "";
        const body_copy = try self.allocator.dupe(u8, body);

        const params = std.StringHashMap([]const u8).init(self.allocator);

        return Request{
            .method = method,
            .path = path,
            .headers = headers,
            .body = body_copy,
            .params = params,
            .allocator = self.allocator,
        };
    }
};
