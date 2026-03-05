const std = @import("std");

pub fn escapeJson(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    for (input) |char| {
        switch (char) {
            '"' => try result.appendSlice("\\\""),
            '\\' => try result.appendSlice("\\\\"),
            '\n' => try result.appendSlice("\\n"),
            '\r' => try result.appendSlice("\\r"),
            '\t' => try result.appendSlice("\\t"),
            '\x00'...'\x08', '\x0B', '\x0C', '\x0E'...'\x1F', '\x7F' => continue,
            else => try result.append(char),
        }
    }

    return result.toOwnedSlice();
}

test "escapeJson escapes double quotes" {
    const allocator = std.testing.allocator;
    const input = "Hello \"World\"";
    const expected = "Hello \\\"World\\\"";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson escapes backslashes" {
    const allocator = std.testing.allocator;
    const input = "C:\\Users\\test";
    const expected = "C:\\\\Users\\\\test";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson escapes newlines" {
    const allocator = std.testing.allocator;
    const input = "Line 1\nLine 2";
    const expected = "Line 1\\nLine 2";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson escapes carriage returns" {
    const allocator = std.testing.allocator;
    const input = "Line 1\rLine 2";
    const expected = "Line 1\\rLine 2";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson escapes tabs" {
    const allocator = std.testing.allocator;
    const input = "Col1\tCol2";
    const expected = "Col1\\tCol2";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson removes control characters" {
    const allocator = std.testing.allocator;
    const input = "Hello\x00World\x01Test";
    const expected = "HelloWorldTest";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson handles empty string" {
    const allocator = std.testing.allocator;
    const input = "";
    const expected = "";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson handles string without special characters" {
    const allocator = std.testing.allocator;
    const input = "Hello World 123";
    const expected = "Hello World 123";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson handles mixed special characters" {
    const allocator = std.testing.allocator;
    const input = "Say \"Hello\"\\nAnd \"Goodbye\"";
    const expected = "Say \\\"Hello\\\"\\\\nAnd \\\"Goodbye\\\"";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "escapeJson handles unicode characters" {
    const allocator = std.testing.allocator;
    const input = "Hello 🎉 World";
    const expected = "Hello 🎉 World";

    const result = try escapeJson(allocator, input);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}
