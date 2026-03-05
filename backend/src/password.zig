const std = @import("std");
const crypto = std.crypto;

// bcrypt-like cost factor (2^cost iterations)
const BCRYPT_COST = 12;

// Salt length in bytes
const SALT_LEN = 16;

// Hash length in bytes (SHA256 output)
const HASH_LEN = 32;

pub const PasswordHashError = error{
    InvalidHashFormat,
    HashMismatch,
    InvalidCost,
};

/// Generate a cryptographically secure random salt
fn generateSalt() [SALT_LEN]u8 {
    var salt: [SALT_LEN]u8 = undefined;
    crypto.random.bytes(&salt);
    return salt;
}

/// Simple password hashing using iterative SHA-256 (PBKDF2-like)
/// In production, use a proper PBKDF2 implementation
/// Returns a string in format: $pbkdf2-sha256$cost$salt$hash
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]u8 {
    const salt = generateSalt();
    var hash: [HASH_LEN]u8 = undefined;

    // Simple iterative hashing (PBKDF2-like)
    // First hash: password + salt
    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.update(&salt);
    hasher.final(&hash);

    // Subsequent iterations: hash previous result
    const iterations = std.math.pow(u32, 2, BCRYPT_COST);
    var i: u32 = 1;
    while (i < iterations) : (i += 1) {
        hasher = crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&hash);
        hasher.final(&hash);
    }

    // Encode to format: $pbkdf2-sha256$cost$base64(salt)$base64(hash)
    const salt_b64_len = std.base64.standard.Encoder.calcSize(salt.len);
    const hash_b64_len = std.base64.standard.Encoder.calcSize(hash.len);

    const result = try allocator.alloc(u8, 16 + 2 + 2 + salt_b64_len + 1 + hash_b64_len);
    errdefer allocator.free(result);

    var stream = std.io.fixedBufferStream(result);
    const writer = stream.writer();

    try writer.writeAll("$pbkdf2-sha256$");
    try writer.print("{d}$", .{BCRYPT_COST});

    var salt_b64_buf: [64]u8 = undefined;
    const salt_b64 = std.base64.standard.Encoder.encode(&salt_b64_buf, &salt);
    try writer.writeAll(salt_b64);
    try writer.writeByte('$');

    var hash_b64_buf: [64]u8 = undefined;
    const hash_b64 = std.base64.standard.Encoder.encode(&hash_b64_buf, &hash);
    try writer.writeAll(hash_b64);

    return result;
}

/// Verify password against stored hash
pub fn verifyPassword(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    // Parse the stored hash
    var parts = std.mem.splitScalar(u8, stored_hash, '$');
    _ = parts.next(); // empty before first $
    const scheme = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const cost_str = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const salt_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;
    const hash_b64 = parts.next() orelse return PasswordHashError.InvalidHashFormat;

    if (!std.mem.eql(u8, scheme, "pbkdf2-sha256")) {
        return PasswordHashError.InvalidHashFormat;
    }

    const cost = std.fmt.parseInt(u32, cost_str, 10) catch return PasswordHashError.InvalidHashFormat;

    // Decode salt
    const salt_len = try std.base64.standard.Decoder.calcSizeForSlice(salt_b64);
    const salt = try allocator.alloc(u8, salt_len);
    defer allocator.free(salt);
    try std.base64.standard.Decoder.decode(salt, salt_b64);

    // Decode expected hash
    const expected_hash_len = try std.base64.standard.Decoder.calcSizeForSlice(hash_b64);
    const expected_hash = try allocator.alloc(u8, expected_hash_len);
    defer allocator.free(expected_hash);
    try std.base64.standard.Decoder.decode(expected_hash, hash_b64);

    // Compute hash with same parameters
    var computed_hash: [HASH_LEN]u8 = undefined;

    // First hash: password + salt
    var hasher = crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.update(salt);
    hasher.final(&computed_hash);

    // Subsequent iterations: hash previous result
    const iterations = std.math.pow(u32, 2, cost);
    var i: u32 = 1;
    while (i < iterations) : (i += 1) {
        hasher = crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&computed_hash);
        hasher.final(&computed_hash);
    }

    // Constant-time comparison
    return crypto.utils.timingSafeEql([HASH_LEN]u8, computed_hash, expected_hash[0..HASH_LEN].*);
}
