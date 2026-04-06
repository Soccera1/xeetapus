const std = @import("std");
const crypto = std.crypto;

// Legacy hash parameters (will be deprecated)
const LEGACY_BCRYPT_COST = 12;

// New secure hash parameters
const NEW_ITERATIONS = 32768;
const SALT_LEN = 32;
const HASH_LEN = 32;
const VERSION = "v2";

pub const PasswordHashError = error{
    InvalidHashFormat,
    HashMismatch,
    InvalidCost,
};

pub const HashType = enum {
    legacy_sha256,
    legacy_pbkdf2,
    modern_pbkdf2,
};

fn generateSalt() [SALT_LEN]u8 {
    var salt: [SALT_LEN]u8 = undefined;
    crypto.random.bytes(&salt);
    return salt;
}

/// PBKDF2-HMAC-SHA256 derivation function
/// Implements RFC 2898 PBKDF2 with HMAC-SHA256
fn pbkdf2HmacSha256(password: []const u8, salt: []const u8, iterations: u32, output: []u8) void {
    const block_count = (output.len + HASH_LEN - 1) / HASH_LEN;
    var offset: usize = 0;

    for (0..block_count) |block_num| {
        var block: [HASH_LEN]u8 = undefined;
        var u: [HASH_LEN]u8 = undefined;

        // U1 = HMAC-SHA256(password, salt || INT_32_BE(block_num))
        var salt_with_index: [128]u8 = undefined;
        @memcpy(salt_with_index[0..salt.len], salt);
        var block_num_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &block_num_bytes, @intCast(block_num + 1), .big);
        @memcpy(salt_with_index[salt.len .. salt.len + 4], &block_num_bytes);

        hmacSha256(password, salt_with_index[0 .. salt.len + 4], &u);
        block = u;

        // U_i for i = 2 to iterations
        var i: u32 = 1;
        while (i < iterations) : (i += 1) {
            hmacSha256(password, &u, &u);
            for (&block, 0..) |b, j| {
                block[j] = b ^ u[j];
            }
        }

        const copy_len = @min(HASH_LEN, output.len - offset);
        @memcpy(output[offset .. offset + copy_len], &block);
        offset += copy_len;
    }
}

/// HMAC-SHA256 implementation
fn hmacSha256(key: []const u8, message: []const u8, out: *[HASH_LEN]u8) void {
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
        var key_hash: [HASH_LEN]u8 = undefined;
        key_hasher.final(&key_hash);
        @memcpy(key_padded[0..HASH_LEN], &key_hash);
        @memset(key_padded[HASH_LEN..], 0);
    }

    for (key_padded, 0..) |k, i| {
        key_ipad[i] = k ^ 0x36;
        key_opad[i] = k ^ 0x5c;
    }

    var inner_hasher = crypto.hash.sha2.Sha256.init(.{});
    inner_hasher.update(&key_ipad);
    inner_hasher.update(message);
    var inner_hash: [HASH_LEN]u8 = undefined;
    inner_hasher.final(&inner_hash);

    var outer_hasher = crypto.hash.sha2.Sha256.init(.{});
    outer_hasher.update(&key_opad);
    outer_hasher.update(&inner_hash);
    outer_hasher.final(out);
}

/// Modern password hashing using PBKDF2-HMAC-SHA256
/// Returns a string in format: $pbkdf2-sha256$v2$iterations$base64(salt)$base64(hash)
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]u8 {
    const salt = generateSalt();
    var hash: [HASH_LEN]u8 = undefined;

    pbkdf2HmacSha256(password, &salt, NEW_ITERATIONS, &hash);

    const salt_b64_len = std.base64.standard.Encoder.calcSize(salt.len);
    const hash_b64_len = std.base64.standard.Encoder.calcSize(hash.len);

    const max_result_len = "$pbkdf2-sha256$v2$".len + 10 + 1 + salt_b64_len + 1 + hash_b64_len;
    const result = try allocator.alloc(u8, max_result_len);
    errdefer allocator.free(result);

    var stream = std.io.fixedBufferStream(result);
    const writer = stream.writer();

    try writer.writeAll("$pbkdf2-sha256$v2$");
    try writer.print("{d}$", .{NEW_ITERATIONS});

    var salt_b64_buf: [64]u8 = undefined;
    const salt_b64 = std.base64.standard.Encoder.encode(&salt_b64_buf, &salt);
    try writer.writeAll(salt_b64);
    try writer.writeByte('$');

    var hash_b64_buf: [64]u8 = undefined;
    const hash_b64 = std.base64.standard.Encoder.encode(&hash_b64_buf, &hash);
    try writer.writeAll(hash_b64);

    return allocator.realloc(result, stream.pos);
}

/// Detect the type of password hash
pub fn detectHashType(stored_hash: []const u8) HashType {
    if (stored_hash.len == 0) return .legacy_sha256;
    if (stored_hash[0] != '$') return .legacy_sha256;

    if (std.mem.startsWith(u8, stored_hash, "$pbkdf2-sha256$v2$")) {
        return .modern_pbkdf2;
    }
    if (std.mem.startsWith(u8, stored_hash, "$pbkdf2-sha256$")) {
        return .legacy_pbkdf2;
    }
    return .legacy_sha256;
}

/// Check if hash is a legacy format (needs migration)
pub fn isLegacyHash(stored_hash: []const u8) bool {
    const hash_type = detectHashType(stored_hash);
    return hash_type != .modern_pbkdf2;
}

/// Verify password against stored hash
/// Supports multiple hash formats for backward compatibility
pub fn verifyPassword(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    const hash_type = detectHashType(stored_hash);

    return switch (hash_type) {
        .modern_pbkdf2 => verifyPbkdf2V2(allocator, password, stored_hash),
        .legacy_pbkdf2 => verifyLegacyPbkdf2(allocator, password, stored_hash),
        .legacy_sha256 => verifyLegacySha256(password, stored_hash),
    };
}

/// Verify modern PBKDF2 v2 hash format
fn verifyPbkdf2V2(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    var parts = std.mem.splitScalar(u8, stored_hash, '$');
    _ = parts.next();
    const scheme = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const version = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const iterations_str = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const salt_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const hash_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;

    if (!std.mem.eql(u8, scheme, "pbkdf2-sha256")) return PasswordHashError.InvalidHashFormat;
    if (!std.mem.eql(u8, version, "v2")) return PasswordHashError.InvalidHashFormat;

    const iterations = std.fmt.parseInt(u32, iterations_str, 10) catch return PasswordHashError.InvalidHashFormat;

    const salt_len = try std.base64.standard.Decoder.calcSizeForSlice(salt_b64);
    const salt = try allocator.alloc(u8, salt_len);
    defer allocator.free(salt);
    try std.base64.standard.Decoder.decode(salt, salt_b64);

    const expected_hash_len = try std.base64.standard.Decoder.calcSizeForSlice(hash_b64);
    const expected_hash = try allocator.alloc(u8, expected_hash_len);
    defer allocator.free(expected_hash);
    try std.base64.standard.Decoder.decode(expected_hash, hash_b64);

    var computed_hash: [HASH_LEN]u8 = undefined;
    pbkdf2HmacSha256(password, salt, iterations, &computed_hash);

    var result: u8 = 0;
    for (computed_hash, expected_hash[0..HASH_LEN]) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}

/// Verify legacy PBKDF2 (v1, iterative SHA256, not true PBKDF2)
fn verifyLegacyPbkdf2(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    var parts = std.mem.splitScalar(u8, stored_hash, '$');
    _ = parts.next();
    const scheme = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const cost_str = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const salt_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const hash_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;

    if (!std.mem.eql(u8, scheme, "pbkdf2-sha256")) return PasswordHashError.InvalidHashFormat;

    const cost = std.fmt.parseInt(u32, cost_str, 10) catch return PasswordHashError.InvalidHashFormat;

    const salt_len = try std.base64.standard.Decoder.calcSizeForSlice(salt_b64);
    const salt = try allocator.alloc(u8, salt_len);
    defer allocator.free(salt);
    try std.base64.standard.Decoder.decode(salt, salt_b64);

    const expected_hash_len = try std.base64.standard.Decoder.calcSizeForSlice(hash_b64);
    const expected_hash = try allocator.alloc(u8, expected_hash_len);
    defer allocator.free(expected_hash);
    try std.base64.standard.Decoder.decode(expected_hash, hash_b64);

    var computed_hash: [HASH_LEN]u8 = undefined;

    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.update(salt);
    hasher.final(&computed_hash);

    const iterations = std.math.pow(u32, 2, cost);
    var i: u32 = 1;
    while (i < iterations) : (i += 1) {
        hasher = crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&computed_hash);
        hasher.final(&computed_hash);
    }

    var result: u8 = 0;
    for (computed_hash, expected_hash[0..HASH_LEN]) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}

/// Verify legacy SHA256 hash (simple hash, no salt)
fn verifyLegacySha256(password: []const u8, stored_hash: []const u8) bool {
    if (stored_hash.len != 64) return false;

    var expected_hash: [HASH_LEN]u8 = undefined;
    var i: usize = 0;
    while (i < 64) : (i += 2) {
        const high = std.fmt.charToDigit(stored_hash[i], 16) catch return false;
        const low = std.fmt.charToDigit(stored_hash[i + 1], 16) catch return false;
        expected_hash[i / 2] = @intCast(high * 16 + low);
    }

    var computed_hash: [HASH_LEN]u8 = undefined;
    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.final(&computed_hash);

    var result: u8 = 0;
    for (computed_hash, expected_hash) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}
