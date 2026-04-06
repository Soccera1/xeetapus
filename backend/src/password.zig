const std = @import("std");
const crypto = std.crypto;
const argon2 = crypto.pwhash.argon2;
const config = @import("config.zig");

pub const PasswordHashError = error{
    InvalidHashFormat,
    HashMismatch,
    InvalidCost,
    AllocatorRequired,
};

pub const HashType = enum {
    legacy_sha256,
    legacy_pbkdf2,
    modern_pbkdf2,
    modern_argon2id,
};

const LEGACY_HASH_LEN = 32;

pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]u8 {
    const cfg = try config.Config.get();

    const params = argon2.Params{
        .t = cfg.argon2_time_cost,
        .m = cfg.argon2_memory_cost,
        .p = cfg.argon2_parallelism,
    };

    var hash_buf: [256]u8 = undefined;
    const hash_str = try argon2.strHash(password, .{
        .allocator = allocator,
        .params = params,
        .mode = .argon2id,
    }, &hash_buf);

    return try allocator.dupe(u8, hash_str);
}

pub fn detectHashType(stored_hash: []const u8) HashType {
    if (stored_hash.len == 0) return .legacy_sha256;
    if (stored_hash[0] != '$') return .legacy_sha256;

    if (std.mem.startsWith(u8, stored_hash, "$argon2id$")) {
        return .modern_argon2id;
    }
    if (std.mem.startsWith(u8, stored_hash, "$pbkdf2-sha256$v2$")) {
        return .modern_pbkdf2;
    }
    if (std.mem.startsWith(u8, stored_hash, "$pbkdf2-sha256$")) {
        return .legacy_pbkdf2;
    }
    return .legacy_sha256;
}

pub fn isLegacyHash(stored_hash: []const u8) bool {
    const hash_type = detectHashType(stored_hash);
    return hash_type != .modern_argon2id;
}

pub fn isCriticalLegacyHash(stored_hash: []const u8) bool {
    const hash_type = detectHashType(stored_hash);
    return hash_type == .legacy_sha256;
}

pub fn verifyPassword(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    const hash_type = detectHashType(stored_hash);

    return switch (hash_type) {
        .modern_argon2id => verifyArgon2id(allocator, password, stored_hash),
        .modern_pbkdf2 => verifyPbkdf2V2(allocator, password, stored_hash),
        .legacy_pbkdf2 => verifyLegacyPbkdf2(allocator, password, stored_hash),
        .legacy_sha256 => verifyLegacySha256(password, stored_hash),
    };
}

fn verifyArgon2id(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    argon2.strVerify(stored_hash, password, .{
        .allocator = allocator,
    }) catch |err| {
        if (err == error.PasswordVerificationFailed) {
            return false;
        }
        return PasswordHashError.HashMismatch;
    };
    return true;
}

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

    var computed_hash: [LEGACY_HASH_LEN]u8 = undefined;
    pbkdf2HmacSha256(password, salt, iterations, &computed_hash);

    var result: u8 = 0;
    for (computed_hash, expected_hash[0..LEGACY_HASH_LEN]) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}

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

    var computed_hash: [LEGACY_HASH_LEN]u8 = undefined;

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
    for (computed_hash, expected_hash[0..LEGACY_HASH_LEN]) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}

fn verifyLegacySha256(password: []const u8, stored_hash: []const u8) bool {
    if (stored_hash.len != 64) return false;

    var expected_hash: [LEGACY_HASH_LEN]u8 = undefined;
    var i: usize = 0;
    while (i < 64) : (i += 2) {
        const high = std.fmt.charToDigit(stored_hash[i], 16) catch return false;
        const low = std.fmt.charToDigit(stored_hash[i + 1], 16) catch return false;
        expected_hash[i / 2] = @intCast(high * 16 + low);
    }

    var computed_hash: [LEGACY_HASH_LEN]u8 = undefined;
    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.final(&computed_hash);

    var result: u8 = 0;
    for (computed_hash, expected_hash) |a, b| {
        result |= a ^ b;
    }
    return result == 0;
}

fn pbkdf2HmacSha256(password: []const u8, salt: []const u8, iterations: u32, output: []u8) void {
    const block_count = (output.len + LEGACY_HASH_LEN - 1) / LEGACY_HASH_LEN;
    var offset: usize = 0;

    for (0..block_count) |block_num| {
        var block: [LEGACY_HASH_LEN]u8 = undefined;
        var u: [LEGACY_HASH_LEN]u8 = undefined;

        var salt_with_index: [128]u8 = undefined;
        @memcpy(salt_with_index[0..salt.len], salt);
        var block_num_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &block_num_bytes, @intCast(block_num + 1), .big);
        @memcpy(salt_with_index[salt.len .. salt.len + 4], &block_num_bytes);

        hmacSha256(password, salt_with_index[0 .. salt.len + 4], &u);
        block = u;

        var i: u32 = 1;
        while (i < iterations) : (i += 1) {
            hmacSha256(password, &u, &u);
            for (&block, 0..) |b, j| {
                block[j] = b ^ u[j];
            }
        }

        const copy_len = @min(LEGACY_HASH_LEN, output.len - offset);
        @memcpy(output[offset .. offset + copy_len], &block);
        offset += copy_len;
    }
}

fn hmacSha256(key: []const u8, message: []const u8, out: *[LEGACY_HASH_LEN]u8) void {
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
        var key_hash: [LEGACY_HASH_LEN]u8 = undefined;
        key_hasher.final(&key_hash);
        @memcpy(key_padded[0..LEGACY_HASH_LEN], &key_hash);
        @memset(key_padded[LEGACY_HASH_LEN..], 0);
    }

    for (key_padded, 0..) |k, i| {
        key_ipad[i] = k ^ 0x36;
        key_opad[i] = k ^ 0x5c;
    }

    var inner_hasher = crypto.hash.sha2.Sha256.init(.{});
    inner_hasher.update(&key_ipad);
    inner_hasher.update(message);
    var inner_hash: [LEGACY_HASH_LEN]u8 = undefined;
    inner_hasher.final(&inner_hash);

    var outer_hasher = crypto.hash.sha2.Sha256.init(.{});
    outer_hasher.update(&key_opad);
    outer_hasher.update(&inner_hash);
    outer_hasher.final(out);
}
