const std = @import("std");
const http = @import("http.zig");
const auth = @import("auth.zig");
const db = @import("db.zig");

const MEDIA_DIR = "../database/media";
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB max file size

// Allowed file extensions and their corresponding MIME types
const ALLOWED_EXTENSIONS = .{
    .{ ".jpg", "image/jpeg" },
    .{ ".jpeg", "image/jpeg" },
    .{ ".png", "image/png" },
    .{ ".gif", "image/gif" },
    .{ ".webp", "image/webp" },
    .{ ".svg", "image/svg+xml" },
    .{ ".mp4", "video/mp4" },
    .{ ".webm", "video/webm" },
    .{ ".mov", "video/quicktime" },
};

pub fn upload(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Get user ID from request
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Unauthorized\"}");
        return;
    };

    // Get username for the user
    const username = try getUsernameById(allocator, user_id) orelse {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"User not found\"}");
        return;
    };
    defer allocator.free(username);

    // Parse multipart form data
    const content_type = req.headers.get("Content-Type") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Missing Content-Type header\"}");
        return;
    };

    // Extract boundary from Content-Type header
    const boundary_prefix = "boundary=";
    const boundary_start = std.mem.indexOf(u8, content_type, boundary_prefix) orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid Content-Type header\"}");
        return;
    };
    const boundary = content_type[boundary_start + boundary_prefix.len ..];

    // Parse multipart data
    const parsed = try parseMultipartForm(allocator, req.body, boundary);
    defer parsed.deinit();

    if (parsed.file_data == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"No file provided\"}");
        return;
    }

    const file_data = parsed.file_data.?;
    const is_profile = parsed.is_profile;

    // Validate file size
    if (file_data.len > MAX_FILE_SIZE) {
        res.status = 413;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"File too large\"}");
        return;
    }

    // Get original filename and extract extension
    const original_filename = parsed.filename orelse "file";
    const extension = std.fs.path.extension(original_filename);

    // Validate file extension
    if (!isValidExtension(extension)) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid file type\"}");
        return;
    }

    // Create user directory if it doesn't exist
    const user_dir = try std.fs.path.join(allocator, &[_][]const u8{ MEDIA_DIR, username });
    defer allocator.free(user_dir);

    std.fs.cwd().makePath(user_dir) catch |err| {
        std.log.err("Failed to create directory {s}: {s}", .{ user_dir, @errorName(err) });
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to create directory\"}");
        return;
    };

    // Generate filename
    const filename = if (is_profile)
        try std.fmt.allocPrint(allocator, "profile{s}", .{extension})
    else
        try std.fmt.allocPrint(allocator, "{d}{s}", .{ std.time.timestamp(), extension });
    defer allocator.free(filename);

    // Build full file path
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ user_dir, filename });
    defer allocator.free(file_path);

    // Write file to disk
    const file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
        std.log.err("Failed to create file {s}: {s}", .{ file_path, @errorName(err) });
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to save file\"}");
        return;
    };
    defer file.close();

    file.writeAll(file_data) catch |err| {
        std.log.err("Failed to write file {s}: {s}", .{ file_path, @errorName(err) });
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to write file\"}");
        return;
    };

    // Generate public URL for the file
    const public_url = try std.fmt.allocPrint(allocator, "/media/{s}/{s}", .{ username, filename });
    defer allocator.free(public_url);

    // If it's a profile picture, update the user's avatar_url in the database
    if (is_profile) {
        const update_sql = "UPDATE users SET avatar_url = ? WHERE id = ?";
        const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
        defer allocator.free(user_id_str);

        db.execute(update_sql, &[_][]const u8{ public_url, user_id_str }) catch |err| {
            std.log.err("Failed to update avatar_url: {s}", .{@errorName(err)});
            // Continue anyway, the file was saved successfully
        };
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.body.writer().print("{{\"url\":\"{s}\",\"filename\":\"{s}\"}}", .{ public_url, filename });
}

fn getUsernameById(allocator: std.mem.Allocator, user_id: i64) !?[]const u8 {
    const sql = "SELECT username FROM users WHERE id = ?";
    const UserResult = struct {
        username: []const u8,
    };

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    const rows = db.query(UserResult, allocator, sql, &[_][]const u8{user_id_str}) catch {
        return null;
    };
    defer db.freeRows(UserResult, allocator, rows);

    if (rows.len == 0) {
        return null;
    }

    return try allocator.dupe(u8, rows[0].username);
}

fn isValidExtension(ext: []const u8) bool {
    inline for (ALLOWED_EXTENSIONS) |allowed| {
        if (std.mem.eql(u8, ext, allowed[0])) {
            return true;
        }
    }
    return false;
}

const MultipartForm = struct {
    file_data: ?[]const u8,
    filename: ?[]const u8,
    is_profile: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: MultipartForm) void {
        if (self.file_data) |data| {
            self.allocator.free(data);
        }
        if (self.filename) |name| {
            self.allocator.free(name);
        }
    }
};

fn parseMultipartForm(allocator: std.mem.Allocator, body: []const u8, boundary: []const u8) !MultipartForm {
    var result = MultipartForm{
        .file_data = null,
        .filename = null,
        .is_profile = false,
        .allocator = allocator,
    };

    const boundary_marker = try std.fmt.allocPrint(allocator, "--{s}", .{boundary});
    defer allocator.free(boundary_marker);

    var parts = std.mem.splitSequence(u8, body, boundary_marker);

    while (parts.next()) |part| {
        // Skip empty parts and the final boundary marker
        if (part.len == 0 or std.mem.eql(u8, part, "--\r\n")) continue;

        // Find the headers and body separation
        const header_end = std.mem.indexOf(u8, part, "\r\n\r\n");
        if (header_end == null) continue;

        const headers = part[0..header_end.?];
        const content = part[header_end.? + 4 ..];

        // Remove trailing \r\n from content
        const trimmed_content = if (std.mem.endsWith(u8, content, "\r\n"))
            content[0 .. content.len - 2]
        else
            content;

        // Check if this is a file upload
        if (std.mem.indexOf(u8, headers, "filename=") != null) {
            // Extract filename
            const filename_start = std.mem.indexOf(u8, headers, "filename=\"");
            if (filename_start != null) {
                const filename_content = headers[filename_start.? + 10 ..];
                const filename_end = std.mem.indexOf(u8, filename_content, "\"");
                if (filename_end != null) {
                    const filename = filename_content[0..filename_end.?];
                    result.filename = try allocator.dupe(u8, filename);
                    result.file_data = try allocator.dupe(u8, trimmed_content);
                }
            }
        }

        // Check if this is the is_profile field
        if (std.mem.indexOf(u8, headers, "name=\"is_profile\"") != null) {
            if (std.mem.eql(u8, std.mem.trim(u8, trimmed_content, " \r\n"), "true")) {
                result.is_profile = true;
            }
        }
    }

    return result;
}

// Serve media files from the database/media directory
pub fn serveMedia(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    // Extract username and filename from path
    // Path format: /media/:username/:filename
    const path = req.path;
    const prefix = "/media/";

    if (!std.mem.startsWith(u8, path, prefix)) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid path\"}");
        return;
    }

    const remaining = path[prefix.len..];
    const slash_idx = std.mem.indexOf(u8, remaining, "/");
    if (slash_idx == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Invalid path\"}");
        return;
    }

    const username = remaining[0..slash_idx.?];
    const filename = remaining[slash_idx.? + 1 ..];

    // SECURITY: Validate path components
    if (std.mem.indexOf(u8, username, "..") != null or
        std.mem.indexOf(u8, username, "/") != null or
        std.mem.indexOf(u8, username, "\\") != null or
        std.mem.indexOf(u8, filename, "..") != null or
        std.mem.indexOf(u8, filename, "/") != null or
        std.mem.indexOf(u8, filename, "\\") != null)
    {
        res.status = 403;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Forbidden\"}");
        return;
    }

    // Build file path
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ MEDIA_DIR, username, filename });
    defer allocator.free(file_path);

    // Open and serve file
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound) {
            res.status = 404;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.body.appendSlice("{\"error\":\"File not found\"}");
            return;
        }
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"Failed to open file\"}");
        return;
    };
    defer file.close();

    // Get file stats
    const stat = file.stat() catch {
        res.status = 500;
        return;
    };

    // Limit file size
    if (stat.size > MAX_FILE_SIZE) {
        res.status = 413;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.body.appendSlice("{\"error\":\"File too large\"}");
        return;
    }

    // Read file content
    const content = file.readToEndAlloc(allocator, MAX_FILE_SIZE) catch {
        res.status = 500;
        return;
    };
    defer allocator.free(content);

    // Set content type based on file extension
    const extension = std.fs.path.extension(filename);
    const content_type = getContentType(extension);

    res.headers.put("Content-Type", content_type) catch {};
    try res.body.appendSlice(content);
}

fn getContentType(ext: []const u8) []const u8 {
    inline for (ALLOWED_EXTENSIONS) |allowed| {
        if (std.mem.eql(u8, ext, allowed[0])) {
            return allowed[1];
        }
    }
    return "application/octet-stream";
}
