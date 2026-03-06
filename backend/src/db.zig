const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

var db: ?*c.sqlite3 = null;

pub fn init(path: []const u8) !void {
    const result = c.sqlite3_open(path.ptr, &db);
    if (result != c.SQLITE_OK) {
        std.log.err("Failed to open database: {s}", .{c.sqlite3_errmsg(db)});
        return error.DatabaseOpenFailed;
    }
    std.log.info("Database initialized at {s}", .{path});
}

pub fn deinit() void {
    if (db) |database| {
        _ = c.sqlite3_close(database);
        db = null;
    }
}

pub fn getDb() !*c.sqlite3 {
    if (db) |database| {
        return database;
    }
    return error.DatabaseNotInitialized;
}

pub fn runMigrations() !void {
    const migrations = [_][]const u8{
        // Users table
        \\CREATE TABLE IF NOT EXISTS users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    username TEXT UNIQUE NOT NULL,
        \\    email TEXT UNIQUE NOT NULL,
        \\    password_hash TEXT NOT NULL,
        \\    display_name TEXT,
        \\    bio TEXT,
        \\    avatar_url TEXT,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        \\);
        ,
        // Posts (Xeets) table
        \\CREATE TABLE IF NOT EXISTS posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL,
        \\    media_urls TEXT,
        \\    reply_to_id INTEGER,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (reply_to_id) REFERENCES posts(id) ON DELETE CASCADE
        \\);
        ,
        // Likes table
        \\CREATE TABLE IF NOT EXISTS likes (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(user_id, post_id)
        \\);
        ,
        // Follows table
        \\CREATE TABLE IF NOT EXISTS follows (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    follower_id INTEGER NOT NULL,
        \\    following_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(follower_id, following_id)
        \\);
        ,
        // Comments table
        \\CREATE TABLE IF NOT EXISTS comments (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        \\);
        ,
        // Reposts table
        \\CREATE TABLE IF NOT EXISTS reposts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(user_id, post_id)
        \\);
        ,
        // Bookmarks table
        \\CREATE TABLE IF NOT EXISTS bookmarks (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(user_id, post_id)
        \\);
        ,
        // Notifications table
        \\CREATE TABLE IF NOT EXISTS notifications (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    actor_id INTEGER NOT NULL,
        \\    type TEXT NOT NULL,
        \\    post_id INTEGER,
        \\    read INTEGER DEFAULT 0,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        \\);
        ,
        // Communities table
        \\CREATE TABLE IF NOT EXISTS communities (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT UNIQUE NOT NULL,
        \\    description TEXT,
        \\    icon_url TEXT,
        \\    banner_url TEXT,
        \\    created_by INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
        \\);
        ,
        // Community members table
        \\CREATE TABLE IF NOT EXISTS community_members (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    community_id INTEGER NOT NULL,
        \\    user_id INTEGER NOT NULL,
        \\    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(community_id, user_id)
        \\);
        ,
        // Community posts table (links posts to communities)
        \\CREATE TABLE IF NOT EXISTS community_posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    community_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(community_id, post_id)
        \\);
        ,
        // Conversations table for DMs
        \\CREATE TABLE IF NOT EXISTS conversations (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        \\);
        ,
        // Conversation participants
        \\CREATE TABLE IF NOT EXISTS conversation_participants (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    conversation_id INTEGER NOT NULL,
        \\    user_id INTEGER NOT NULL,
        \\    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(conversation_id, user_id)
        \\);
        ,
        // Direct messages
        \\CREATE TABLE IF NOT EXISTS messages (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    conversation_id INTEGER NOT NULL,
        \\    sender_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL,
        \\    media_urls TEXT,
        \\    read INTEGER DEFAULT 0,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
        \\);
        ,
        // User lists
        \\CREATE TABLE IF NOT EXISTS user_lists (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    owner_id INTEGER NOT NULL,
        \\    name TEXT NOT NULL,
        \\    description TEXT,
        \\    is_private INTEGER DEFAULT 0,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        \\);
        ,
        // List members
        \\CREATE TABLE IF NOT EXISTS list_members (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    list_id INTEGER NOT NULL,
        \\    user_id INTEGER NOT NULL,
        \\    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (list_id) REFERENCES user_lists(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(list_id, user_id)
        \\);
        ,
        // Hashtags
        \\CREATE TABLE IF NOT EXISTS hashtags (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    tag TEXT UNIQUE NOT NULL,
        \\    use_count INTEGER DEFAULT 1,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        \\);
        ,
        // Post hashtags
        \\CREATE TABLE IF NOT EXISTS post_hashtags (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    post_id INTEGER NOT NULL,
        \\    hashtag_id INTEGER NOT NULL,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (hashtag_id) REFERENCES hashtags(id) ON DELETE CASCADE,
        \\    UNIQUE(post_id, hashtag_id)
        \\);
        ,
        // Polls
        \\CREATE TABLE IF NOT EXISTS polls (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    post_id INTEGER NOT NULL,
        \\    question TEXT NOT NULL,
        \\    duration_minutes INTEGER DEFAULT 1440,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    ends_at DATETIME,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
        \\);
        ,
        // Poll options
        \\CREATE TABLE IF NOT EXISTS poll_options (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    poll_id INTEGER NOT NULL,
        \\    option_text TEXT NOT NULL,
        \\    position INTEGER NOT NULL,
        \\    vote_count INTEGER DEFAULT 0,
        \\    FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE
        \\);
        ,
        // Poll votes
        \\CREATE TABLE IF NOT EXISTS poll_votes (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    poll_id INTEGER NOT NULL,
        \\    option_id INTEGER NOT NULL,
        \\    user_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (option_id) REFERENCES poll_options(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(poll_id, user_id)
        \\);
        ,
        // Quote posts
        \\CREATE TABLE IF NOT EXISTS quote_posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    post_id INTEGER NOT NULL,
        \\    quoted_post_id INTEGER NOT NULL,
        \\    comment TEXT,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (quoted_post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(post_id, quoted_post_id)
        \\);
        ,
        // Post views (analytics)
        \\CREATE TABLE IF NOT EXISTS post_views (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    post_id INTEGER NOT NULL,
        \\    user_id INTEGER,
        \\    ip_address TEXT,
        \\    viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        \\);
        ,
        // User blocks
        \\CREATE TABLE IF NOT EXISTS blocks (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    blocker_id INTEGER NOT NULL,
        \\    blocked_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (blocker_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (blocked_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(blocker_id, blocked_id)
        \\);
        ,
        // User mutes
        \\CREATE TABLE IF NOT EXISTS mutes (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    muter_id INTEGER NOT NULL,
        \\    muted_id INTEGER NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (muter_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (muted_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(muter_id, muted_id)
        \\);
        ,
        // Drafts
        \\CREATE TABLE IF NOT EXISTS drafts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL,
        \\    media_urls TEXT,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        \\);
        ,
        // Scheduled posts
        \\CREATE TABLE IF NOT EXISTS scheduled_posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL,
        \\    media_urls TEXT,
        \\    scheduled_at DATETIME NOT NULL,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    is_posted INTEGER DEFAULT 0,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        \\);
        ,
        // Pinned posts
        \\CREATE TABLE IF NOT EXISTS pinned_posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    post_id INTEGER NOT NULL,
        \\    pinned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
        \\    UNIQUE(user_id)
        \\);
        ,
        // Per-user LLM provider settings
        \\CREATE TABLE IF NOT EXISTS llm_provider_configs (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    provider TEXT NOT NULL,
        \\    api_key TEXT NOT NULL,
        \\    model TEXT NOT NULL,
        \\    base_url TEXT,
        \\    is_default INTEGER DEFAULT 0,
        \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        \\    UNIQUE(user_id, provider)
        \\);
        ,
    };

    // Schema migrations (ALTER TABLE statements)
    const schema_migrations = [_][]const u8{
        // Add quote_to_id column to posts
        "ALTER TABLE posts ADD COLUMN quote_to_id INTEGER REFERENCES posts(id) ON DELETE CASCADE",
        // Add poll_id column to posts
        "ALTER TABLE posts ADD COLUMN poll_id INTEGER REFERENCES polls(id) ON DELETE SET NULL",
    };

    const database = try getDb();

    // Run schema migrations (ignore errors if columns already exist)
    for (schema_migrations) |migration| {
        _ = c.sqlite3_exec(database, migration.ptr, null, null, null);
    }

    for (migrations) |migration| {
        var err_msg: [*c]u8 = null;
        const result = c.sqlite3_exec(database, migration.ptr, null, null, &err_msg);
        if (result != c.SQLITE_OK) {
            if (err_msg) |msg| {
                std.log.err("Migration failed: {s}", .{msg});
                c.sqlite3_free(msg);
            }
            return error.MigrationFailed;
        }
    }

    std.log.info("Database migrations completed", .{});
}

pub fn execute(sql: []const u8, params: []const []const u8) !void {
    const database = try getDb();
    var stmt: ?*c.sqlite3_stmt = null;

    const result = c.sqlite3_prepare_v2(database, sql.ptr, @intCast(sql.len), &stmt, null);
    if (result != c.SQLITE_OK) {
        std.log.err("Failed to prepare statement: {s}", .{c.sqlite3_errmsg(database)});
        return error.PrepareFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    for (params, 0..) |param, i| {
        _ = c.sqlite3_bind_text(stmt, @intCast(i + 1), param.ptr, @intCast(param.len), c.SQLITE_STATIC);
    }

    const step_result = c.sqlite3_step(stmt);
    if (step_result != c.SQLITE_DONE) {
        std.log.err("Failed to execute statement: {d}", .{step_result});
        return error.ExecuteFailed;
    }
}

pub fn query(comptime T: type, allocator: std.mem.Allocator, sql: []const u8, params: []const []const u8) ![]T {
    const database = try getDb();
    var stmt: ?*c.sqlite3_stmt = null;

    const result = c.sqlite3_prepare_v2(database, sql.ptr, @intCast(sql.len), &stmt, null);
    if (result != c.SQLITE_OK) {
        std.log.err("Failed to prepare statement: {s}", .{c.sqlite3_errmsg(database)});
        return error.PrepareFailed;
    }
    defer _ = c.sqlite3_finalize(stmt);

    for (params, 0..) |param, i| {
        _ = c.sqlite3_bind_text(stmt, @intCast(i + 1), param.ptr, @intCast(param.len), c.SQLITE_STATIC);
    }

    var rows = std.ArrayList(T).init(allocator);
    errdefer rows.deinit();

    while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
        const row = try rowToStruct(T, allocator, stmt.?);
        try rows.append(row);
    }

    return rows.toOwnedSlice();
}

fn rowToStruct(comptime T: type, allocator: std.mem.Allocator, stmt: *c.sqlite3_stmt) !T {
    var result: T = undefined;
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |s| {
            inline for (s.fields, 0..) |field, i| {
                const col_type = c.sqlite3_column_type(stmt, @intCast(i));

                switch (field.type) {
                    i32, i64 => {
                        if (col_type == c.SQLITE_INTEGER) {
                            @field(result, field.name) = c.sqlite3_column_int(stmt, @intCast(i));
                        } else {
                            @field(result, field.name) = 0;
                        }
                    },
                    ?i32, ?i64 => {
                        if (col_type == c.SQLITE_INTEGER) {
                            @field(result, field.name) = c.sqlite3_column_int(stmt, @intCast(i));
                        } else {
                            @field(result, field.name) = null;
                        }
                    },
                    []const u8 => {
                        if (col_type == c.SQLITE_TEXT) {
                            const text = c.sqlite3_column_text(stmt, @intCast(i));
                            const len = c.sqlite3_column_bytes(stmt, @intCast(i));
                            const copy = try allocator.alloc(u8, @intCast(len));
                            @memcpy(copy, text[0..@intCast(len)]);
                            @field(result, field.name) = copy;
                        } else {
                            @field(result, field.name) = "";
                        }
                    },
                    ?[]const u8 => {
                        if (col_type == c.SQLITE_TEXT) {
                            const text = c.sqlite3_column_text(stmt, @intCast(i));
                            const len = c.sqlite3_column_bytes(stmt, @intCast(i));
                            const copy = try allocator.alloc(u8, @intCast(len));
                            @memcpy(copy, text[0..@intCast(len)]);
                            @field(result, field.name) = copy;
                        } else {
                            @field(result, field.name) = null;
                        }
                    },
                    bool => {
                        @field(result, field.name) = c.sqlite3_column_int(stmt, @intCast(i)) != 0;
                    },
                    else => {},
                }
            }
        },
        else => @compileError("T must be a struct"),
    }

    return result;
}

pub fn freeRows(comptime T: type, allocator: std.mem.Allocator, rows: []T) void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |s| {
            for (rows) |row| {
                inline for (s.fields) |field| {
                    switch (field.type) {
                        []const u8 => {
                            const value = @field(row, field.name);
                            if (value.len > 0) {
                                allocator.free(value);
                            }
                        },
                        ?[]const u8 => {
                            const value = @field(row, field.name);
                            if (value) |v| {
                                allocator.free(v);
                            }
                        },
                        else => {},
                    }
                }
            }
        },
        else => {},
    }
    allocator.free(rows);
}

pub fn lastInsertRowId() i64 {
    if (db) |database| {
        return c.sqlite3_last_insert_rowid(database);
    }
    return 0;
}
