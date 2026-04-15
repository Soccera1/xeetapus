const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");

const HealthCheckRow = struct {
    status: []const u8,
    service: []const u8,
    response_ms: i64,
    checked_at: []const u8,
};

pub const HealthCheck = HealthCheckRow;

fn reverseRows(rows: []HealthCheckRow) void {
    var left: usize = 0;
    var right: usize = rows.len;

    if (right == 0) return;
    right -= 1;

    while (left < right) : ({
        left += 1;
        right -= 1;
    }) {
        const tmp = rows[left];
        rows[left] = rows[right];
        rows[right] = tmp;
    }
}

fn recordHealthCheck(allocator: std.mem.Allocator, status: []const u8, service: []const u8, response_ms: i64) void {
    const response_ms_str = std.fmt.allocPrint(allocator, "{d}", .{response_ms}) catch return;
    defer allocator.free(response_ms_str);

    db.execute(
        "INSERT INTO health_checks (status, service, response_ms) VALUES (?, ?, ?)",
        &[_][]const u8{ status, service, response_ms_str },
    ) catch |err| {
        std.log.warn("Failed to record health check: {}", .{err});
    };
}

fn fetchHistory(allocator: std.mem.Allocator) ![]HealthCheckRow {
    const sql =
        \\SELECT status, service, response_ms, checked_at
        \\FROM health_checks
        \\ORDER BY id DESC
        \\LIMIT 20
    ;

    const rows = try db.query(HealthCheckRow, allocator, sql, &[_][]const u8{});
    reverseRows(rows);
    return rows;
}

pub fn getHealth(allocator: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    const started_ms = std.time.milliTimestamp();
    const status = "ok";
    const service = "xeetapus";
    const response_ms = std.time.milliTimestamp() - started_ms;

    recordHealthCheck(allocator, status, service, response_ms);

    const empty_history = &[_]HealthCheckRow{};
    const history = fetchHistory(allocator) catch |err| {
        std.log.warn("Failed to load health history: {}", .{err});
        const payload = .{
            .status = status,
            .service = service,
            .checked_at = "",
            .response_ms = response_ms,
            .uptime_percentage = 100.0,
            .checks = @as(i64, 0),
            .history = empty_history[0..],
        };
        res.headers.put("Content-Type", "application/json") catch {};
        try res.json(payload);
        return;
    };
    defer db.freeRows(HealthCheckRow, allocator, history);

    var successful_checks: i64 = 0;
    for (history) |entry| {
        if (std.mem.eql(u8, entry.status, "ok")) {
            successful_checks += 1;
        }
    }

    const checks: i64 = @intCast(history.len);
    const uptime_percentage = if (checks == 0)
        100.0
    else
        (@as(f64, @floatFromInt(successful_checks)) / @as(f64, @floatFromInt(checks))) * 100.0;

    const latest_checked_at = if (history.len > 0) history[history.len - 1].checked_at else "";
    const payload = .{
        .status = status,
        .service = service,
        .checked_at = latest_checked_at,
        .response_ms = response_ms,
        .uptime_percentage = uptime_percentage,
        .checks = checks,
        .history = history,
    };

    res.headers.put("Content-Type", "application/json") catch {};
    try res.json(payload);
}
