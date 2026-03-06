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
        // Free all keys
        var it = self.entries.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entries.deinit();
    }

    /// Check if request is allowed and increment counter
    /// Returns true if allowed, false if rate limited
    pub fn check(self: *RateLimiter, key: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        const entry = self.entries.getPtr(key);
        if (entry) |e| {
            // Check if window has expired
            if (now - e.window_start > self.window_seconds) {
                // Reset window
                e.count = 1;
                e.window_start = now;
                return true;
            }

            // Check if under limit
            if (e.count >= self.max_requests) {
                return false;
            }

            e.count += 1;
            return true;
        } else {
            // New entry
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);

            try self.entries.put(key_copy, .{
                .count = 1,
                .window_start = now,
            });
            return true;
        }
    }

    /// Get rate limit status for a key
    pub fn getStatus(self: *RateLimiter, key: []const u8) struct { allowed: bool, remaining: u32, reset_time: i64 } {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();

        const entry = self.entries.get(key);
        if (entry) |e| {
            if (now - e.window_start > self.window_seconds) {
                // Window expired
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

    /// Clean up expired entries (call periodically)
    pub fn cleanup(self: *RateLimiter) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (now - entry.value_ptr.window_start > self.window_seconds * 2) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            if (self.entries.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
            }
        }
    }
};

/// Get client IP from request, considering X-Forwarded-For header
pub fn getClientIp(req_headers: std.StringHashMap([]const u8), remote_addr: std.net.Address) []const u8 {
    // Check X-Forwarded-For header (for requests behind proxy)
    if (req_headers.get("x-forwarded-for")) |forwarded| {
        // Take the first IP in the chain
        if (std.mem.indexOf(u8, forwarded, ",")) |comma| {
            return std.mem.trim(u8, forwarded[0..comma], " ");
        }
        return forwarded;
    }

    // Check X-Real-IP header
    if (req_headers.get("x-real-ip")) |real_ip| {
        return real_ip;
    }

    // Fall back to remote address
    var addr_buf: [64]u8 = undefined;
    return std.fmt.bufPrint(&addr_buf, "{}", .{remote_addr}) catch "unknown";
}
