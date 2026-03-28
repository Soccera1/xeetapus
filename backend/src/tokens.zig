const std = @import("std");
const crypto = std.crypto;

const TOKEN_BYTES = 32;
const TOKEN_STRING_LEN = TOKEN_BYTES * 2; // hex encoded

/// Generate a cryptographically secure random token
/// Returns a hex-encoded string
pub fn generateSecureToken(_: std.mem.Allocator) ![TOKEN_STRING_LEN]u8 {
    var bytes: [TOKEN_BYTES]u8 = undefined;
    crypto.random.bytes(&bytes);

    var hex_token: [TOKEN_STRING_LEN]u8 = undefined;
    const hex = std.fmt.bytesToHex(bytes, .lower);
    @memcpy(&hex_token, &hex);

    return hex_token;
}

/// Generate a secure random token as allocated string
pub fn generateSecureTokenAlloc(allocator: std.mem.Allocator) ![]u8 {
    const bytes: [TOKEN_BYTES]u8 = undefined;
    var mutable_bytes = bytes;
    crypto.random.bytes(&mutable_bytes);

    const hex_token = try allocator.alloc(u8, TOKEN_BYTES * 2);
    errdefer allocator.free(hex_token);

    const hex = std.fmt.bytesToHex(mutable_bytes, .lower);
    @memcpy(hex_token, &hex);

    return hex_token;
}

/// Generate a JWT-like token with signature
/// Format: base64(header).base64(payload).base64(signature)
/// For production, consider using a proper JWT library
pub fn generateSignedToken(
    allocator: std.mem.Allocator,
    secret: []const u8,
    user_id: i64,
    expires_in_seconds: i64,
) ![]u8 {
    // Create header
    const header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

    // Create payload with expiration
    const now = std.time.timestamp();
    const exp = now + expires_in_seconds;
    const payload = try std.fmt.allocPrint(allocator, "{{\"sub\":{d},\"iat\":{d},\"exp\":{d}}}", .{ user_id, now, exp });
    defer allocator.free(payload);

    // Base64 encode header and payload
    const header_b64_len = std.base64.url_safe_no_pad.Encoder.calcSize(header.len);
    const payload_b64_len = std.base64.url_safe_no_pad.Encoder.calcSize(payload.len);

    const header_b64 = try allocator.alloc(u8, header_b64_len);
    defer allocator.free(header_b64);
    _ = std.base64.url_safe_no_pad.Encoder.encode(header_b64, header);

    const payload_b64 = try allocator.alloc(u8, payload_b64_len);
    defer allocator.free(payload_b64);
    _ = std.base64.url_safe_no_pad.Encoder.encode(payload_b64, payload);

    // Create signing input
    const signing_input = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_b64, payload_b64 });
    defer allocator.free(signing_input);

    // Sign with HMAC-SHA256
    var signature: [32]u8 = undefined;
    hmacSha256(secret, signing_input, &signature);

    const sig_b64_len = std.base64.url_safe_no_pad.Encoder.calcSize(signature.len);
    const sig_b64 = try allocator.alloc(u8, sig_b64_len);
    defer allocator.free(sig_b64);
    _ = std.base64.url_safe_no_pad.Encoder.encode(sig_b64, &signature);

    // Combine into final token
    const token = try std.fmt.allocPrint(allocator, "{s}.{s}.{s}", .{ header_b64, payload_b64, sig_b64 });
    return token;
}

/// Verify and decode a signed token
/// Returns user_id if valid, null if invalid
pub fn verifySignedToken(
    allocator: std.mem.Allocator,
    secret: []const u8,
    token: []const u8,
) !?i64 {
    // Split token into parts
    var parts = std.mem.splitScalar(u8, token, '.');
    const header_b64 = parts.next() orelse return null;
    const payload_b64 = parts.next() orelse return null;
    const sig_b64 = parts.next() orelse return null;
    if (parts.next() != null) return null; // Too many parts

    // Verify signature
    const signing_input = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_b64, payload_b64 });
    defer allocator.free(signing_input);

    var expected_sig: [32]u8 = undefined;
    hmacSha256(secret, signing_input, &expected_sig);

    // Decode provided signature
    const sig_len = try std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(sig_b64);
    if (sig_len != expected_sig.len) return null;

    const sig = try allocator.alloc(u8, sig_len);
    defer allocator.free(sig);
    std.base64.url_safe_no_pad.Decoder.decode(sig, sig_b64) catch return null;

    // Constant-time comparison
    if (!crypto.utils.timingSafeEql([32]u8, expected_sig, sig[0..32].*)) {
        return null;
    }

    // Decode and parse payload
    const payload_len = try std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(payload_b64);
    const payload = try allocator.alloc(u8, payload_len);
    defer allocator.free(payload);
    std.base64.url_safe_no_pad.Decoder.decode(payload, payload_b64) catch return null;

    // Parse JSON payload to get user_id and check expiration
    const sub_key = "\"sub\":";
    const exp_key = "\"exp\":";

    const sub_pos = std.mem.indexOf(u8, payload, sub_key) orelse return null;
    const exp_pos = std.mem.indexOf(u8, payload, exp_key) orelse return null;

    const sub_start = sub_pos + sub_key.len;
    const exp_start = exp_pos + exp_key.len;

    var sub_end = sub_start;
    while (sub_end < payload.len and payload[sub_end] != ',' and payload[sub_end] != '}') : (sub_end += 1) {}

    var exp_end = exp_start;
    while (exp_end < payload.len and payload[exp_end] != ',' and payload[exp_end] != '}') : (exp_end += 1) {}

    const user_id = std.fmt.parseInt(i64, payload[sub_start..sub_end], 10) catch return null;
    const exp = std.fmt.parseInt(i64, payload[exp_start..exp_end], 10) catch return null;

    // Check expiration
    const now = std.time.timestamp();
    if (now > exp) return null; // Token expired

    return user_id;
}

/// Generate a CSRF token
pub fn generateCsrfToken(allocator: std.mem.Allocator, secret: []const u8, session_id: []const u8) ![]u8 {
    const timestamp = std.time.timestamp();
    const nonce = try generateSecureTokenAlloc(allocator);
    defer allocator.free(nonce);

    // Create HMAC of session_id + timestamp + nonce
    var sig: [32]u8 = undefined;

    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(secret);
    hasher.update(session_id);
    const ts_bytes = std.mem.asBytes(&timestamp);
    hasher.update(ts_bytes);
    hasher.update(nonce);
    hasher.final(&sig);

    const sig_hex = std.fmt.bytesToHex(sig, .lower);

    const token = try std.fmt.allocPrint(allocator, "{d}:{s}:{s}", .{ timestamp, nonce, sig_hex });
    return token;
}

/// Verify a CSRF token
pub fn verifyCsrfToken(secret: []const u8, session_id: []const u8, token: []const u8) bool {
    var parts = std.mem.splitScalar(u8, token, ':');
    const timestamp_str = parts.next() orelse return false;
    const nonce = parts.next() orelse return false;
    const sig_hex = parts.next() orelse return false;
    if (parts.next() != null) return false;

    const timestamp = std.fmt.parseInt(i64, timestamp_str, 10) catch return false;

    // Check if token is not too old (24 hours)
    const now = std.time.timestamp();
    if (now - timestamp > 86400) return false;

    // Recompute signature
    var expected_sig: [32]u8 = undefined;

    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(secret);
    hasher.update(session_id);
    const ts_bytes = std.mem.asBytes(&timestamp);
    hasher.update(ts_bytes);
    hasher.update(nonce);
    hasher.final(&expected_sig);

    // Hex encode expected_sig for comparison
    const expected_sig_hex = std.fmt.bytesToHex(expected_sig, .lower);

    // Constant-time comparison
    if (sig_hex.len != expected_sig_hex.len) return false;
    return crypto.utils.timingSafeEql(u8, sig_hex, expected_sig_hex);
}

/// Simple HMAC-SHA256 implementation
fn hmacSha256(key: []const u8, message: []const u8, out: *[32]u8) void {
    const block_size = 64;
    var key_ipad: [block_size]u8 = undefined;
    var key_opad: [block_size]u8 = undefined;

    var key_padded: [block_size]u8 = undefined;
    if (key.len <= block_size) {
        @memcpy(key_padded[0..key.len], key);
        @memset(key_padded[key.len..], 0);
    } else {
        var key_hasher = crypto.hash.sha2.Sha256.init(.{});
        key_hasher.update(key);
        var key_hash: [32]u8 = undefined;
        key_hasher.final(&key_hash);
        @memcpy(key_padded[0..32], &key_hash);
        @memset(key_padded[32..], 0);
    }

    for (key_padded, 0..) |k, i| {
        key_ipad[i] = k ^ 0x36;
        key_opad[i] = k ^ 0x5c;
    }

    // Inner hash
    var inner_hasher = crypto.hash.sha2.Sha256.init(.{});
    inner_hasher.update(&key_ipad);
    inner_hasher.update(message);
    var inner_hash: [32]u8 = undefined;
    inner_hasher.final(&inner_hash);

    // Outer hash
    var outer_hasher = crypto.hash.sha2.Sha256.init(.{});
    outer_hasher.update(&key_opad);
    outer_hasher.update(&inner_hash);
    outer_hasher.final(out);
}
