const std = @import("std");

/// Validate and sanitize a username
pub fn validateUsername(username: []const u8) ?[]const u8 {
    // Length check
    if (username.len < 3 or username.len > 30) {
        return "Username must be between 3 and 30 characters";
    }

    // Character validation - alphanumeric, underscore, hyphen
    for (username) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
            return "Username can only contain letters, numbers, underscores, and hyphens";
        }
    }

    // Must start with letter
    if (!std.ascii.isAlphabetic(username[0])) {
        return "Username must start with a letter";
    }

    return null;
}

/// Validate password strength
pub fn validatePassword(password: []const u8) ?[]const u8 {
    if (password.len < 8) {
        return "Password must be at least 8 characters long";
    }

    if (password.len > 128) {
        return "Password must not exceed 128 characters";
    }

    var has_upper = false;
    var has_lower = false;
    var has_digit = false;
    var has_special = false;

    for (password) |c| {
        if (std.ascii.isUpper(c)) has_upper = true;
        if (std.ascii.isLower(c)) has_lower = true;
        if (std.ascii.isDigit(c)) has_digit = true;
        if (!std.ascii.isAlphanumeric(c)) has_special = true;
    }

    if (!has_upper or !has_lower or !has_digit) {
        return "Password must contain at least one uppercase letter, one lowercase letter, and one digit";
    }

    // Optional: require special character
    // if (!has_special) {
    //     return "Password must contain at least one special character";
    // }

    return null;
}

/// Simple email validation
pub fn validateEmail(email: []const u8) ?[]const u8 {
    if (email.len < 5 or email.len > 254) {
        return "Invalid email length";
    }

    // Basic format check
    const at_pos = std.mem.indexOf(u8, email, "@") orelse return "Invalid email format";
    if (at_pos == 0 or at_pos == email.len - 1) {
        return "Invalid email format";
    }

    const dot_pos = std.mem.indexOf(u8, email[at_pos..], ".") orelse return "Invalid email format";
    if (dot_pos <= 1 or at_pos + dot_pos == email.len - 1) {
        return "Invalid email format";
    }

    // Check for consecutive dots
    if (std.mem.indexOf(u8, email, "..") != null) {
        return "Invalid email format";
    }

    // Character validation
    for (email) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '@' and c != '.' and c != '_' and c != '-' and c != '+') {
            return "Email contains invalid characters";
        }
    }

    return null;
}

/// Sanitize content to prevent XSS (basic)
pub fn sanitizeContent(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    // Calculate required size
    var size: usize = 0;
    for (content) |c| {
        switch (c) {
            '<' => size += 4, // &lt;
            '>' => size += 4, // &gt;
            '&' => size += 5, // &amp;
            '"' => size += 6, // &quot;
            '\'' => size += 6, // &#x27;
            '/' => size += 6, // &#x2F;
            else => size += 1,
        }
    }

    var result = try allocator.alloc(u8, size);
    errdefer allocator.free(result);

    var i: usize = 0;
    for (content) |c| {
        switch (c) {
            '<' => {
                @memcpy(result[i..][0..4], "&lt;");
                i += 4;
            },
            '>' => {
                @memcpy(result[i..][0..4], "&gt;");
                i += 4;
            },
            '&' => {
                @memcpy(result[i..][0..5], "&amp;");
                i += 5;
            },
            '"' => {
                @memcpy(result[i..][0..6], "&quot;");
                i += 6;
            },
            '\'' => {
                @memcpy(result[i..][0..6], "&#x27;");
                i += 6;
            },
            '/' => {
                @memcpy(result[i..][0..6], "&#x2F;");
                i += 6;
            },
            else => {
                result[i] = c;
                i += 1;
            },
        }
    }

    return result;
}

/// Check if content is within acceptable length
pub fn validateContentLength(content: []const u8, min: usize, max: usize) ?[]const u8 {
    if (content.len < min) {
        return "Content too short";
    }
    if (content.len > max) {
        return "Content too long";
    }
    return null;
}
