const std = @import("std");
const http = @import("http.zig");
const db = @import("db.zig");
const auth = @import("auth.zig");

pub const MoneroConfig = struct {
    wallet_address: []const u8,
    daemon_url: []const u8,
};

pub const FeePriority = enum(u8) {
    slow = 1, // ~1-2 hours
    normal = 2, // ~30 mins
    fast = 3, // ~10 mins
    fastest = 4, // ~5 mins

    pub fn fromString(s: []const u8) ?FeePriority {
        if (std.mem.eql(u8, s, "slow")) return .slow;
        if (std.mem.eql(u8, s, "normal")) return .normal;
        if (std.mem.eql(u8, s, "fast")) return .fast;
        if (std.mem.eql(u8, s, "fastest")) return .fastest;
        return null;
    }

    pub fn toString(self: FeePriority) []const u8 {
        return switch (self) {
            .slow => "slow",
            .normal => "normal",
            .fast => "fast",
            .fastest => "fastest",
        };
    }

    pub fn estimatedMinutes(self: FeePriority) u32 {
        return switch (self) {
            .slow => 90,
            .normal => 30,
            .fast => 10,
            .fastest => 5,
        };
    }
};

const PriceCache = struct {
    price_usd: f64,
    last_updated: i64,
    mutex: std.Thread.Mutex,
};

const FeeCache = struct {
    fee_per_byte: [4]u64,
    last_updated: i64,
    mutex: std.Thread.Mutex,
};

var monero_config: ?MoneroConfig = null;
var config_allocator: ?std.mem.Allocator = null;
var price_cache: PriceCache = .{
    .price_usd = 0,
    .last_updated = 0,
    .mutex = std.Thread.Mutex{},
};
var fee_cache: FeeCache = .{
    .fee_per_byte = [_]u64{ 0, 0, 0, 0 },
    .last_updated = 0,
    .mutex = std.Thread.Mutex{},
};

const CACHE_TTL_SECONDS: i64 = 7200; // 2 hours
const COINGECKO_API_URL = "https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd";

pub fn init(allocator: std.mem.Allocator) !void {
    config_allocator = allocator;

    const wallet_address = std.process.getEnvVarOwned(allocator, "XEETAPUS_MONERO_ADDRESS") catch blk: {
        std.log.warn("XEETAPUS_MONERO_ADDRESS not set, payments disabled", .{});
        break :blk try allocator.dupe(u8, "");
    };
    errdefer allocator.free(wallet_address);

    const daemon_url = std.process.getEnvVarOwned(allocator, "XEETAPUS_MONEROD_URL") catch blk: {
        std.log.info("XEETAPUS_MONEROD_URL not set, using default: http://localhost:18081", .{});
        break :blk try allocator.dupe(u8, "http://localhost:18081");
    };
    errdefer allocator.free(daemon_url);

    monero_config = MoneroConfig{
        .wallet_address = wallet_address,
        .daemon_url = daemon_url,
    };

    _ = fetchXmrPrice(allocator) catch |err| {
        std.log.warn("Failed to fetch initial XMR price: {}", .{err});
    };

    _ = fetchFeeEstimates(allocator) catch |err| {
        std.log.warn("Failed to fetch initial fee estimates: {}", .{err});
    };
}

pub fn deinit() void {
    if (config_allocator) |allocator| {
        if (monero_config) |*cfg| {
            allocator.free(cfg.wallet_address);
            allocator.free(cfg.daemon_url);
        }
        monero_config = null;
    }
}

fn fetchXmrPrice(allocator: std.mem.Allocator) !f64 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(COINGECKO_API_URL);
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &.{} });
    defer req.deinit();

    try req.send();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const monero_obj = parsed.value.object.get("monero") orelse return error.NoMoneroData;
    const usd_obj = monero_obj.object.get("usd") orelse return error.NoUsdPrice;

    const price: f64 = switch (usd_obj) {
        .float => |f| f,
        .integer => |i| @floatFromInt(i),
        else => return error.InvalidPriceFormat,
    };

    price_cache.mutex.lock();
    defer price_cache.mutex.unlock();

    price_cache.price_usd = price;
    price_cache.last_updated = std.time.timestamp();

    return price;
}

fn getXmrPrice(allocator: std.mem.Allocator) !f64 {
    price_cache.mutex.lock();
    const cached_price = price_cache.price_usd;
    const cached_time = price_cache.last_updated;
    price_cache.mutex.unlock();

    const now = std.time.timestamp();

    if (cached_price > 0 and (now - cached_time) < CACHE_TTL_SECONDS) {
        return cached_price;
    }

    return fetchXmrPrice(allocator);
}

fn fetchFeeEstimates(allocator: std.mem.Allocator) ![4]u64 {
    if (monero_config == null) return error.NoConfig;

    const daemon_url = monero_config.?.daemon_url;

    const request_body = "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_fee_estimate\"}";

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var uri = try std.Uri.parse(daemon_url);
    uri.path = std.Uri.Component{ .raw = "/json_rpc" };

    var headers_buf: [1024]u8 = undefined;
    var req = try client.open(.POST, uri, .{
        .server_header_buffer = &headers_buf,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = request_body.len };
    try req.send();
    try req.writer().writeAll(request_body);
    try req.finish();

    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 16384);
    defer allocator.free(body);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const result = parsed.value.object.get("result") orelse return error.NoResult;
    const fees = result.object.get("fees") orelse return error.NoFees;

    var fee_per_byte: [4]u64 = [_]u64{ 0, 0, 0, 0 };

    if (fees.array.items.len >= 4) {
        for (0..4) |i| {
            fee_per_byte[i] = switch (fees.array.items[i]) {
                .integer => |v| @intCast(v),
                else => 0,
            };
        }
    }

    fee_cache.mutex.lock();
    defer fee_cache.mutex.unlock();

    fee_cache.fee_per_byte = fee_per_byte;
    fee_cache.last_updated = std.time.timestamp();

    return fee_per_byte;
}

fn getXmrFees(allocator: std.mem.Allocator) ![4]u64 {
    fee_cache.mutex.lock();
    const cached_fees = fee_cache.fee_per_byte;
    const cached_time = fee_cache.last_updated;
    fee_cache.mutex.unlock();

    const now = std.time.timestamp();

    if (cached_fees[0] > 0 and (now - cached_time) < CACHE_TTL_SECONDS) {
        return cached_fees;
    }

    return fetchFeeEstimates(allocator);
}

fn estimateTxFee(priority: FeePriority, fee_per_byte: [4]u64) u64 {
    const idx: usize = @intFromEnum(priority) - 1;
    const base_fee = fee_per_byte[idx];
    const typical_tx_size: u64 = 13000; // ~13KB for typical Monero tx
    return base_fee * typical_tx_size;
}

pub fn fiatToXmr(allocator: std.mem.Allocator, fiat_amount: f64, fiat_currency: []const u8) !f64 {
    _ = fiat_currency; // Currently only USD supported

    const xmr_price = try getXmrPrice(allocator);
    if (xmr_price <= 0) return error.InvalidPrice;

    return fiat_amount / xmr_price;
}

pub fn xmrToFiat(allocator: std.mem.Allocator, xmr_amount: f64, fiat_currency: []const u8) !f64 {
    _ = fiat_currency; // Currently only USD supported

    const xmr_price = try getXmrPrice(allocator);
    if (xmr_price <= 0) return error.InvalidPrice;

    return xmr_amount * xmr_price;
}

pub fn getExchangeRate(allocator: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    const price_result = getXmrPrice(allocator);
    const price: f64 = price_result catch 0;

    const fees = getXmrFees(allocator) catch {
        res.status = 503;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to fetch fee estimates from monerod\"}");
        return;
    };

    price_cache.mutex.lock();
    const last_updated = price_cache.last_updated;
    price_cache.mutex.unlock();

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.append('{');

    if (price > 0) {
        try response.writer().print("\"xmr_usd\":{d:.2},\"last_updated\":{d},\"cache_ttl_seconds\":{d},\"fees\":{{", .{ price, last_updated, CACHE_TTL_SECONDS });
    } else {
        try response.writer().print("\"xmr_usd\":null,\"last_updated\":0,\"cache_ttl_seconds\":{d},\"fees\":{{", .{CACHE_TTL_SECONDS});
    }

    const priority_names = [_][]const u8{ "slow", "normal", "fast", "fastest" };
    const priority_minutes = [_]u32{ 90, 30, 10, 5 };

    for (0..4) |i| {
        if (i > 0) try response.append(',');
        const fee_atomic = estimateTxFee(@as(FeePriority, @enumFromInt(i + 1)), fees);
        const fee_xmr = @as(f64, @floatFromInt(fee_atomic)) / 1_000_000_000_000.0;
        if (price > 0) {
            const fee_usd = fee_xmr * price;
            try response.writer().print("\"{s}\":{{\"fee_per_byte\":{d},\"estimated_tx_fee_xmr\":{d:.12},\"estimated_tx_fee_usd\":{d:.4},\"estimated_minutes\":{d}}}", .{ priority_names[i], fees[i], fee_xmr, fee_usd, priority_minutes[i] });
        } else {
            try response.writer().print("\"{s}\":{{\"fee_per_byte\":{d},\"estimated_tx_fee_xmr\":{d:.12},\"estimated_tx_fee_usd\":null,\"estimated_minutes\":{d}}}", .{ priority_names[i], fees[i], fee_xmr, priority_minutes[i] });
        }
    }

    try response.append('}');

    try response.append('}');

    res.status = 200;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append(response.items);
}

pub fn createInvoice(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = (try auth.getUserIdFromRequest(allocator, req)) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    if (req.body.len == 0) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Request body required\"}");
        return;
    }

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const priority_str = if (parsed.value.object.get("priority")) |p| switch (p) {
        .string => |s| s,
        else => "normal",
    } else "normal";

    const priority = FeePriority.fromString(priority_str) orelse .normal;

    if (monero_config == null or monero_config.?.wallet_address.len == 0) {
        res.status = 503;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Monero wallet not configured\"}");
        return;
    }

    const fees = getXmrFees(allocator) catch {
        res.status = 503;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get network fee estimates\"}");
        return;
    };

    const network_fee_atomic = estimateTxFee(priority, fees);
    const network_fee_xmr = @as(f64, @floatFromInt(network_fee_atomic)) / 1_000_000_000_000.0;

    var xmr_amount: f64 = undefined;
    var fiat_amount: f64 = 0;
    var currency: []const u8 = "XMR";
    var price_usd: f64 = 0;
    var using_fixed_xmr = false;

    if (parsed.value.object.get("xmr_amount")) |xmr_val| {
        using_fixed_xmr = true;
        xmr_amount = switch (xmr_val) {
            .integer => |i| @floatFromInt(i),
            .float => |f| f,
            else => {
                res.status = 400;
                res.headers.put("Content-Type", "application/json") catch {};
                try res.append("{\"error\":\"Invalid xmr_amount\"}");
                return;
            },
        };
        if (xmr_amount <= 0) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"xmr_amount must be positive\"}");
            return;
        }
    } else if (parsed.value.object.get("amount")) |amount_val| {
        const fiat_amt: f64 = switch (amount_val) {
            .integer => |i| @floatFromInt(i),
            .float => |f| f,
            else => {
                res.status = 400;
                res.headers.put("Content-Type", "application/json") catch {};
                try res.append("{\"error\":\"Invalid amount\"}");
                return;
            },
        };
        if (fiat_amt <= 0) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"amount must be positive\"}");
            return;
        }

        currency = if (parsed.value.object.get("currency")) |c| switch (c) {
            .string => |s| s,
            else => "USD",
        } else "USD";

        xmr_amount = fiatToXmr(allocator, fiat_amt, currency) catch {
            res.status = 503;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Failed to get XMR exchange rate. Use xmr_amount to specify XMR directly.\"}");
            return;
        };

        fiat_amount = fiat_amt;
        price_usd = getXmrPrice(allocator) catch 0;
    } else {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Either amount or xmr_amount required\"}");
        return;
    }

    const total_xmr = xmr_amount + network_fee_xmr;
    const xmr_atomic = @as(i64, @intFromFloat(total_xmr * 1_000_000_000_000));
    const network_fee_usd = network_fee_xmr * price_usd;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const amount_str = try std.fmt.allocPrint(allocator, "{d}", .{xmr_atomic});
    defer allocator.free(amount_str);

    const insert_sql = "INSERT INTO invoices (user_id, amount, invoice, status) VALUES (?, ?, ?, 'pending')";
    db.execute(insert_sql, &[_][]const u8{ user_id_str, amount_str, monero_config.?.wallet_address }) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };

    const invoice_id = db.lastInsertRowId();
    const invoice_id_str = try std.fmt.allocPrint(allocator, "{d}", .{invoice_id});
    defer allocator.free(invoice_id_str);

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    if (using_fixed_xmr) {
        try response.writer().print("{{\"id\":{},\"address\":\"{s}\",\"xmr_amount\":{d:.12},\"network_fee\":{d:.12},\"total_xmr\":{d:.12},\"priority\":\"{s}\",\"estimated_minutes\":{d},\"status\":\"pending\"}}", .{ invoice_id, monero_config.?.wallet_address, xmr_amount, network_fee_xmr, total_xmr, priority.toString(), priority.estimatedMinutes() });
    } else {
        try response.writer().print("{{\"id\":{},\"address\":\"{s}\",\"xmr_amount\":{d:.12},\"network_fee\":{d:.12},\"total_xmr\":{d:.12},\"fiat_amount\":{d:.2},\"fiat_currency\":\"{s}\",\"network_fee_usd\":{d:.4},\"xmr_price_usd\":{d:.2},\"priority\":\"{s}\",\"estimated_minutes\":{d},\"status\":\"pending\"}}", .{ invoice_id, monero_config.?.wallet_address, xmr_amount, network_fee_xmr, total_xmr, fiat_amount, currency, network_fee_usd, price_usd, priority.toString(), priority.estimatedMinutes() });
    }

    res.status = 201;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append(response.items);
}

pub fn checkPayment(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    _ = (try auth.getUserIdFromRequest(allocator, req)) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const invoice_id_str = req.params.get("id") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invoice ID required\"}");
        return;
    };

    _ = std.fmt.parseInt(i64, invoice_id_str, 10) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid invoice ID\"}");
        return;
    };

    const InvoiceRow = struct {
        id: i64,
        user_id: i64,
        amount: i64,
        status: []const u8,
        invoice: []const u8,
        created_at: []const u8,
        paid_at: ?[]const u8,
    };

    const query_sql = "SELECT id, user_id, amount, status, invoice, created_at, paid_at FROM invoices WHERE id = ?";
    const invoices = db.query(InvoiceRow, allocator, query_sql, &[_][]const u8{invoice_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(InvoiceRow, allocator, invoices);

    if (invoices.len == 0) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invoice not found\"}");
        return;
    }

    const invoice = invoices[0];

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.writer().print("{{\"id\":{},\"amount\":{},\"status\":\"{s}\",\"created_at\":\"{s}\"", .{ invoice.id, invoice.amount, invoice.status, invoice.created_at });

    if (invoice.paid_at) |paid_at| {
        try response.writer().print(",\"paid_at\":\"{s}\"", .{paid_at});
    }

    try response.append('}');

    res.status = 200;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append(response.items);
}

pub fn getInvoices(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = (try auth.getUserIdFromRequest(allocator, req)) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const InvoiceRow = struct {
        id: i64,
        amount: i64,
        status: []const u8,
        invoice: []const u8,
        created_at: []const u8,
    };

    const query_sql = "SELECT id, amount, status, invoice, created_at FROM invoices WHERE user_id = ? ORDER BY created_at DESC";
    const invoices = db.query(InvoiceRow, allocator, query_sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(InvoiceRow, allocator, invoices);

    var invoices_list = std.ArrayList(u8).init(allocator);
    defer invoices_list.deinit();

    try invoices_list.append('[');

    for (invoices, 0..) |invoice, i| {
        if (i > 0) try invoices_list.append(',');
        try invoices_list.writer().print("{{\"id\":{},\"amount\":{},\"status\":\"{s}\",\"invoice\":\"{s}\",\"created_at\":\"{s}\"}}", .{ invoice.id, invoice.amount, invoice.status, invoice.invoice, invoice.created_at });
    }

    try invoices_list.append(']');

    res.status = 200;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append(invoices_list.items);
}

pub fn getBalance(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = (try auth.getUserIdFromRequest(allocator, req)) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const BalanceRow = struct {
        balance: i64,
    };

    const query_sql = "SELECT COALESCE(SUM(amount), 0) as balance FROM invoices WHERE user_id = ? AND status = 'paid'";
    const rows = db.query(BalanceRow, allocator, query_sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(BalanceRow, allocator, rows);

    if (rows.len == 0) {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to get balance\"}");
        return;
    }

    const balance = rows[0].balance;

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    try response.writer().print("{{\"balance\":{}}}", .{balance});

    res.status = 200;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append(response.items);
}

pub fn payInvoice(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = (try auth.getUserIdFromRequest(allocator, req)) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return;
    };

    if (req.body.len == 0) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Request body required\"}");
        return;
    }

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid JSON\"}");
        return;
    };
    defer parsed.deinit();

    const invoice_opt = parsed.value.object.get("invoice");
    if (invoice_opt == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invoice required\"}");
        return;
    }

    const invoice_val = invoice_opt.?;
    const invoice = switch (invoice_val) {
        .string => |s| s,
        else => {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Invalid invoice\"}");
            return;
        },
    };

    const decoded = try decodeInvoice(allocator, invoice);
    if (decoded == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid Monero address\"}");
        return;
    }
    const amount = decoded.?.amount;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const BalanceRow = struct {
        balance: i64,
    };

    const balance_sql = "SELECT COALESCE(SUM(amount), 0) as balance FROM invoices WHERE user_id = ? AND status = 'paid'";
    const balance_rows = db.query(BalanceRow, allocator, balance_sql, &[_][]const u8{user_id_str}) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Database error\"}");
        return;
    };
    defer db.freeRows(BalanceRow, allocator, balance_rows);

    if (balance_rows.len == 0) {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to check balance\"}");
        return;
    }

    const current_balance = balance_rows[0].balance;

    if (current_balance < amount) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Insufficient balance\"}");
        return;
    }

    // TODO: Integrate with Monero wallet to verify payments
    res.status = 503;
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"error\":\"Payment processing not yet implemented\"}");
}

fn decodeInvoice(allocator: std.mem.Allocator, invoice: []const u8) !?struct {
    amount: i64,
    memo: []const u8,
} {
    _ = allocator;

    // Validate Monero integrated address format (starts with '4' and is 95 chars)
    // or subaddress format (starts with '8' and is 95 chars)
    const is_valid = (std.mem.startsWith(u8, invoice, "4") or std.mem.startsWith(u8, invoice, "8")) and invoice.len == 95;

    if (!is_valid) {
        return null;
    }

    // Monero addresses don't have amounts embedded, so we return 0
    // In production, you'd need a separate mechanism to specify the amount
    return .{
        .amount = 0,
        .memo = "",
    };
}
