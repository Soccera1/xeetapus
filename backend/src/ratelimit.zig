const std = @import("std");

const RateLimitEntry = struct {
    count: u32,
    window_start: i64,
};

pub const RateLimiter = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(RateLimitEntry),
    max_requests: u32,
    window_seconds: i64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, max_requests: u32, window_seconds: i64) RateLimiter {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(RateLimitEntry).init(allocator),
            .max_requests = max_requests,
            .window_seconds = window_seconds,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *RateLimiter) void {
        var it = self.entries.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entries.deinit();
    }

    pub fn check(self: *RateLimiter, key: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        const entry = self.entries.getPtr(key);
        if (entry) |e| {
            if (now - e.window_start > self.window_seconds) {
                e.count = 1;
                e.window_start = now;
                return true;
            }

            if (e.count >= self.max_requests) {
                return false;
            }

            e.count += 1;
            return true;
        } else {
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);

            try self.entries.put(key_copy, .{
                .count = 1,
                .window_start = now,
            });
            return true;
        }
    }

    pub fn getStatus(self: *RateLimiter, key: []const u8) struct { allowed: bool, remaining: u32, reset_time: i64 } {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        const entry = self.entries.get(key);
        if (entry) |e| {
            if (now - e.window_start > self.window_seconds) {
                return .{
                    .allowed = true,
                    .remaining = self.max_requests,
                    .reset_time = now + self.window_seconds,
                };
            }

            const remaining = if (e.count >= self.max_requests) 0 else self.max_requests - e.count;
            return .{
                .allowed = e.count < self.max_requests,
                .remaining = remaining,
                .reset_time = e.window_start + self.window_seconds,
            };
        }

        return .{
            .allowed = true,
            .remaining = self.max_requests,
            .reset_time = now + self.window_seconds,
        };
    }

    pub fn cleanup(self: *RateLimiter) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var to_remove: std.ArrayListUnmanaged([]const u8) = .{};
        defer to_remove.deinit(self.allocator);

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (now - entry.value_ptr.window_start > self.window_seconds * 2) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            if (self.entries.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
            }
        }
    }
};

pub fn formatRemoteAddr(addr: std.net.Address, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "{}", .{addr}) catch "unknown";
}

pub fn getClientIp(remote_ip: []const u8, req_headers: std.StringHashMap([]const u8), trust_proxy: bool) []const u8 {
    if (trust_proxy) {
        if (req_headers.get("x-forwarded-for")) |forwarded| {
            if (std.mem.indexOf(u8, forwarded, ",")) |comma| {
                const first_ip = std.mem.trim(u8, forwarded[0..comma], " ");
                if (isValidIpv4(first_ip) or isValidIpv6(first_ip)) {
                    return first_ip;
                }
            }
            if (isValidIpv4(forwarded) or isValidIpv6(forwarded)) {
                return forwarded;
            }
        }

        if (req_headers.get("x-real-ip")) |real_ip| {
            if (isValidIpv4(real_ip) or isValidIpv6(real_ip)) {
                return real_ip;
            }
        }
    }

    if (remote_ip.len > 0 and !std.mem.eql(u8, remote_ip, "unknown")) {
        return remote_ip;
    }

    return "unknown";
}

fn isValidIpv4(ip: []const u8) bool {
    var octets: u8 = 0;
    var digit_count: u8 = 0;
    var current: u32 = 0;
    var has_digit = false;
    for (ip) |c| {
        if (c == '.') {
            if (!has_digit) return false;
            if (current > 255) return false;
            octets += 1;
            current = 0;
            digit_count = 0;
            has_digit = false;
        } else if (std.ascii.isDigit(c)) {
            digit_count += 1;
            if (digit_count > 3) return false;
            current = current * 10 + (c - '0');
            has_digit = true;
        } else {
            return false;
        }
    }
    if (!has_digit) return false;
    if (current > 255) return false;
    return octets == 3;
}

fn isValidIpv6(ip: []const u8) bool {
    if (ip.len < 2) return false;
    var colons: u8 = 0;
    var digit_count: u8 = 0;
    var has_double_colon = false;
    var i: usize = 0;
    while (i < ip.len) : (i += 1) {
        const c = ip[i];
        if (c == ':') {
            if (i + 1 < ip.len and ip[i + 1] == ':') {
                if (has_double_colon) return false;
                has_double_colon = true;
                i += 1;
                colons += 1;
                digit_count = 0;
            } else {
                colons += 1;
                digit_count = 0;
            }
        } else if (std.ascii.isHex(c)) {
            digit_count += 1;
            if (digit_count > 4) return false;
        } else if (c == '.' and i > 0) {
            break;
        } else {
            return false;
        }
    }
    if (!has_double_colon and colons < 2) return false;
    return true;
}
