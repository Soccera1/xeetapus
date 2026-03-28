const std = @import("std");
const http = @import("http.zig");
const auth = @import("auth.zig");
const db = @import("db.zig");
const json_utils = @import("json.zig");

const ProviderKind = enum {
    openai_compatible,
    anthropic,
    gemini,
};

const ProviderSpec = struct {
    id: []const u8,
    label: []const u8,
    description: []const u8,
    default_model: []const u8,
    default_endpoint: []const u8,
    allow_custom_base_url: bool,
    kind: ProviderKind,
};

const providers = [_]ProviderSpec{
    .{
        .id = "openai",
        .label = "OpenAI",
        .description = "OpenAI chat models via the Responses-compatible chat endpoint.",
        .default_model = "gpt-4.1-mini",
        .default_endpoint = "https://api.openai.com/v1/chat/completions",
        .allow_custom_base_url = true,
        .kind = .openai_compatible,
    },
    .{
        .id = "anthropic",
        .label = "Anthropic",
        .description = "Claude models via the Anthropic Messages API.",
        .default_model = "claude-3-5-haiku-latest",
        .default_endpoint = "https://api.anthropic.com/v1/messages",
        .allow_custom_base_url = true,
        .kind = .anthropic,
    },
    .{
        .id = "openrouter",
        .label = "OpenRouter",
        .description = "OpenRouter using an OpenAI-compatible chat API.",
        .default_model = "openrouter/auto",
        .default_endpoint = "https://openrouter.ai/api/v1/chat/completions",
        .allow_custom_base_url = true,
        .kind = .openai_compatible,
    },
    .{
        .id = "groq",
        .label = "Groq",
        .description = "Groq-hosted open-weight models over an OpenAI-compatible API.",
        .default_model = "llama-3.3-70b-versatile",
        .default_endpoint = "https://api.groq.com/openai/v1/chat/completions",
        .allow_custom_base_url = true,
        .kind = .openai_compatible,
    },
    .{
        .id = "google",
        .label = "Google Gemini",
        .description = "Gemini models via the Google Generative Language API.",
        .default_model = "gemini-2.0-flash",
        .default_endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
        .allow_custom_base_url = false,
        .kind = .gemini,
    },
    .{
        .id = "together",
        .label = "Together",
        .description = "Together AI using an OpenAI-compatible chat API.",
        .default_model = "meta-llama/Llama-3.3-70B-Instruct-Turbo",
        .default_endpoint = "https://api.together.xyz/v1/chat/completions",
        .allow_custom_base_url = true,
        .kind = .openai_compatible,
    },
};

const ConfigRow = struct {
    provider: []const u8,
    api_key: []const u8,
    model: []const u8,
    base_url: ?[]const u8,
    is_default: bool,
    updated_at: []const u8,
};

const DefaultCountRow = struct {
    count: i64,
};

const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

const ChatRequest = struct {
    provider: ?[]const u8 = null,
    post_id: ?i64 = null,
    messages: []ChatMessage,
};

const PostContext = struct {
    id: i64,
    content: []const u8,
    created_at: []const u8,
    username: []const u8,
    display_name: ?[]const u8,
};

const ProviderCallResult = union(enum) {
    success: []u8,
    error_message: []u8,
};

const HttpResponseBody = struct {
    status: u16,
    body: []u8,
};

pub fn getProviders(_: std.mem.Allocator, _: *http.Request, res: *http.Response) !void {
    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"providers\":[");
    for (providers, 0..) |provider, idx| {
        if (idx > 0) try res.append(",");
        try res.bodyWriter().print(
            "{{\"id\":\"{s}\",\"label\":\"{s}\",\"description\":\"{s}\",\"default_model\":\"{s}\",\"supports_custom_base_url\":{s}}}",
            .{
                provider.id,
                provider.label,
                provider.description,
                provider.default_model,
                if (provider.allow_custom_base_url) "true" else "false",
            },
        );
    }
    try res.append("]}");
}

pub fn getConfigs(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try requireUserId(allocator, req, res) orelse return;
    const rows = try queryConfigs(allocator, user_id);
    defer db.freeRows(ConfigRow, allocator, rows);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"configs\":[");
    for (rows, 0..) |row, idx| {
        if (idx > 0) try res.append(",");
        const masked = try maskApiKey(allocator, row.api_key);
        defer allocator.free(masked);
        const escaped_provider = try json_utils.escapeJson(allocator, row.provider);
        defer allocator.free(escaped_provider);
        const escaped_model = try json_utils.escapeJson(allocator, row.model);
        defer allocator.free(escaped_model);
        const escaped_masked = try json_utils.escapeJson(allocator, masked);
        defer allocator.free(escaped_masked);
        const escaped_updated_at = try json_utils.escapeJson(allocator, row.updated_at);
        defer allocator.free(escaped_updated_at);

        try res.bodyWriter().print(
            "{{\"provider\":\"{s}\",\"configured\":true,\"masked_api_key\":\"{s}\",\"model\":\"{s}\",\"is_default\":{s},\"updated_at\":\"{s}\"",
            .{
                escaped_provider,
                escaped_masked,
                escaped_model,
                if (row.is_default) "true" else "false",
                escaped_updated_at,
            },
        );
        if (row.base_url) |base_url| {
            const escaped_base_url = try json_utils.escapeJson(allocator, base_url);
            defer allocator.free(escaped_base_url);
            try res.bodyWriter().print(",\"base_url\":\"{s}\"", .{escaped_base_url});
        }
        try res.append("}");
    }
    try res.append("]}");
}

pub fn updateConfig(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try requireUserId(allocator, req, res) orelse return;
    const provider_id = req.params.get("provider") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Provider required\"}");
        return;
    };
    const provider = providerFromId(provider_id) orelse {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unsupported provider\"}");
        return;
    };

    const UpdateRequest = struct {
        api_key: ?[]const u8 = null,
        model: ?[]const u8 = null,
        base_url: ?[]const u8 = null,
        is_default: ?bool = null,
    };

    const parsed = try std.json.parseFromSlice(UpdateRequest, allocator, req.body, .{});
    defer parsed.deinit();
    const body = parsed.value;

    const existing = try getConfigByProvider(allocator, user_id, provider.id);
    defer if (existing) |row| db.freeRows(ConfigRow, allocator, row);

    const trimmed_key = trimToNull(body.api_key);
    const trimmed_model = trimToNull(body.model);
    const trimmed_base_url = trimToNull(body.base_url);

    if (trimmed_base_url != null and !provider.allow_custom_base_url) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"This provider does not support a custom base URL\"}");
        return;
    }

    const final_api_key = if (trimmed_key) |value|
        value
    else if (existing) |rows|
        rows[0].api_key
    else
        null;

    if (final_api_key == null) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"API key is required\"}");
        return;
    }

    const final_model = if (trimmed_model) |value|
        value
    else if (existing) |rows|
        rows[0].model
    else
        provider.default_model;

    const final_base_url = if (trimmed_base_url != null)
        trimmed_base_url
    else if (existing) |rows|
        rows[0].base_url
    else
        null;

    const has_default = try userHasDefaultConfig(allocator, user_id);
    const make_default = body.is_default orelse (!has_default);
    const final_default = if (make_default) true else if (existing) |rows| rows[0].is_default else false;

    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    if (final_default) {
        db.execute("UPDATE llm_provider_configs SET is_default = 0 WHERE user_id = ?", &[_][]const u8{user_id_str}) catch {
            res.status = 500;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Failed to update default provider\"}");
            return;
        };
    }

    const is_default_str = if (final_default) "1" else "0";

    if (existing) |_| {
        const sql =
            "UPDATE llm_provider_configs SET api_key = ?, model = ?, base_url = ?, is_default = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ? AND provider = ?";
        db.execute(sql, &[_][]const u8{
            final_api_key.?,
            final_model,
            final_base_url orelse "",
            is_default_str,
            user_id_str,
            provider.id,
        }) catch {
            res.status = 500;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Failed to save provider config\"}");
            return;
        };
    } else {
        const sql =
            "INSERT INTO llm_provider_configs (user_id, provider, api_key, model, base_url, is_default) VALUES (?, ?, ?, ?, ?, ?)";
        db.execute(sql, &[_][]const u8{
            user_id_str,
            provider.id,
            final_api_key.?,
            final_model,
            final_base_url orelse "",
            is_default_str,
        }) catch {
            res.status = 500;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Failed to save provider config\"}");
            return;
        };
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"saved\":true}");
}

pub fn deleteConfig(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try requireUserId(allocator, req, res) orelse return;
    const provider_id = req.params.get("provider") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Provider required\"}");
        return;
    };

    const existing = try getConfigByProvider(allocator, user_id, provider_id);
    defer if (existing) |row| db.freeRows(ConfigRow, allocator, row);

    if (existing == null) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Provider config not found\"}");
        return;
    }

    const was_default = existing.?[0].is_default;
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);

    db.execute(
        "DELETE FROM llm_provider_configs WHERE user_id = ? AND provider = ?",
        &[_][]const u8{ user_id_str, provider_id },
    ) catch {
        res.status = 500;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Failed to delete provider config\"}");
        return;
    };

    if (was_default) {
        const remaining = try queryConfigs(allocator, user_id);
        defer db.freeRows(ConfigRow, allocator, remaining);
        if (remaining.len > 0) {
            db.execute(
                "UPDATE llm_provider_configs SET is_default = 1 WHERE user_id = ? AND provider = ?",
                &[_][]const u8{ user_id_str, remaining[0].provider },
            ) catch {};
        }
    }

    res.headers.put("Content-Type", "application/json") catch {};
    try res.append("{\"deleted\":true}");
}

pub fn revealConfig(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try requireUserId(allocator, req, res) orelse return;
    const provider_id = req.params.get("provider") orelse {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Provider required\"}");
        return;
    };

    const rows = try getConfigByProvider(allocator, user_id, provider_id);
    defer if (rows) |value| db.freeRows(ConfigRow, allocator, value);

    if (rows == null) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Provider config not found\"}");
        return;
    }

    const escaped_key = try json_utils.escapeJson(allocator, rows.?[0].api_key);
    defer allocator.free(escaped_key);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print("{{\"provider\":\"{s}\",\"api_key\":\"{s}\"}}", .{ provider_id, escaped_key });
}

pub fn chat(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const user_id = try requireUserId(allocator, req, res) orelse return;

    const parsed = std.json.parseFromSlice(ChatRequest, allocator, req.body, .{}) catch {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Invalid chat request\"}");
        return;
    };
    defer parsed.deinit();
    const body = parsed.value;

    if (body.messages.len == 0) {
        res.status = 400;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"At least one message is required\"}");
        return;
    }

    for (body.messages) |message| {
        if (!std.mem.eql(u8, message.role, "user") and
            !std.mem.eql(u8, message.role, "assistant") and
            !std.mem.eql(u8, message.role, "system"))
        {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Invalid message role\"}");
            return;
        }
        if (std.mem.trim(u8, message.content, " \n\r\t").len == 0) {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Message content cannot be empty\"}");
            return;
        }
    }

    var owned_provider_id: ?[]u8 = null;
    defer if (owned_provider_id) |value| allocator.free(value);

    const provider_id = if (body.provider) |value|
        value
    else blk: {
        owned_provider_id = try getDefaultProviderId(allocator, user_id) orelse {
            res.status = 400;
            res.headers.put("Content-Type", "application/json") catch {};
            try res.append("{\"error\":\"Configure an AI provider in Settings first\"}");
            return;
        };
        break :blk owned_provider_id.?;
    };

    const config_rows = try getConfigByProvider(allocator, user_id, provider_id);
    defer if (config_rows) |rows| db.freeRows(ConfigRow, allocator, rows);

    if (config_rows == null) {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Selected provider is not configured\"}");
        return;
    }

    const provider = providerFromId(provider_id) orelse {
        res.status = 404;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unsupported provider\"}");
        return;
    };

    const post_context = if (body.post_id) |post_id|
        try getPostContext(allocator, post_id)
    else
        null;
    defer if (post_context) |rows| db.freeRows(PostContext, allocator, rows);

    const system_prompt = try buildSystemPrompt(allocator, post_context);
    defer allocator.free(system_prompt);

    const config = config_rows.?[0];
    const provider_result = switch (provider.kind) {
        .openai_compatible => sendOpenAiCompatibleRequest(
            allocator,
            provider,
            config.api_key,
            config.model,
            config.base_url,
            system_prompt,
            body.messages,
        ),
        .anthropic => sendAnthropicRequest(
            allocator,
            provider,
            config.api_key,
            config.model,
            config.base_url,
            system_prompt,
            body.messages,
        ),
        .gemini => sendGeminiRequest(
            allocator,
            provider,
            config.api_key,
            config.model,
            system_prompt,
            body.messages,
        ),
    } catch |err| {
        res.status = 502;
        res.headers.put("Content-Type", "application/json") catch {};
        const error_message = switch (err) {
            error.ProviderRequestFailed => try allocator.dupe(u8, "The AI provider could not be reached. Please try again in a moment."),
            error.ProviderRequestTimeout => try allocator.dupe(u8, "The AI provider is taking too long to respond. Please try again."),
            error.ProviderBadResponse => try allocator.dupe(u8, "The AI provider returned an unexpected response"),
            else => try std.fmt.allocPrint(allocator, "Failed to complete AI request: {s}", .{@errorName(err)}),
        };
        defer allocator.free(error_message);
        const escaped_error = try json_utils.escapeJson(allocator, error_message);
        defer allocator.free(escaped_error);
        try res.bodyWriter().print("{{\"error\":\"{s}\"}}", .{escaped_error});
        return;
    };

    const reply = switch (provider_result) {
        .success => |value| value,
        .error_message => |value| {
            defer allocator.free(value);
            res.status = 502;
            res.headers.put("Content-Type", "application/json") catch {};
            const escaped_error = try json_utils.escapeJson(allocator, value);
            defer allocator.free(escaped_error);
            try res.bodyWriter().print("{{\"error\":\"{s}\"}}", .{escaped_error});
            return;
        },
    };
    defer allocator.free(reply);

    const escaped_provider = try json_utils.escapeJson(allocator, provider.id);
    defer allocator.free(escaped_provider);
    const escaped_model = try json_utils.escapeJson(allocator, config.model);
    defer allocator.free(escaped_model);
    const escaped_reply = try json_utils.escapeJson(allocator, reply);
    defer allocator.free(escaped_reply);

    res.headers.put("Content-Type", "application/json") catch {};
    try res.bodyWriter().print(
        "{{\"provider\":\"{s}\",\"model\":\"{s}\",\"reply\":\"{s}\"}}",
        .{ escaped_provider, escaped_model, escaped_reply },
    );
}

fn requireUserId(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !?i64 {
    const user_id = try auth.getUserIdFromRequest(allocator, req) orelse {
        res.status = 401;
        res.headers.put("Content-Type", "application/json") catch {};
        try res.append("{\"error\":\"Unauthorized\"}");
        return null;
    };
    return user_id;
}

fn providerFromId(id: []const u8) ?ProviderSpec {
    for (providers) |provider| {
        if (std.mem.eql(u8, provider.id, id)) return provider;
    }
    return null;
}

fn maskApiKey(allocator: std.mem.Allocator, key: []const u8) ![]u8 {
    if (key.len <= 8) return allocator.dupe(u8, "********");
    return std.fmt.allocPrint(allocator, "{s}...{s}", .{ key[0..4], key[key.len - 4 ..] });
}

fn trimToNull(value: ?[]const u8) ?[]const u8 {
    if (value) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \n\r\t");
        if (trimmed.len > 0) return trimmed;
    }
    return null;
}

fn queryConfigs(allocator: std.mem.Allocator, user_id: i64) ![]ConfigRow {
    const sql =
        \\SELECT provider, api_key, model, NULLIF(base_url, ''), is_default, updated_at
        \\FROM llm_provider_configs
        \\WHERE user_id = ?
        \\ORDER BY is_default DESC, updated_at DESC
    ;
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    return db.query(ConfigRow, allocator, sql, &[_][]const u8{user_id_str});
}

fn getConfigByProvider(allocator: std.mem.Allocator, user_id: i64, provider_id: []const u8) !?[]ConfigRow {
    const sql =
        \\SELECT provider, api_key, model, NULLIF(base_url, ''), is_default, updated_at
        \\FROM llm_provider_configs
        \\WHERE user_id = ? AND provider = ?
        \\LIMIT 1
    ;
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const rows = try db.query(ConfigRow, allocator, sql, &[_][]const u8{ user_id_str, provider_id });
    if (rows.len == 0) {
        db.freeRows(ConfigRow, allocator, rows);
        return null;
    }
    return rows;
}

fn userHasDefaultConfig(allocator: std.mem.Allocator, user_id: i64) !bool {
    const sql = "SELECT COUNT(*) as count FROM llm_provider_configs WHERE user_id = ? AND is_default = 1";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const rows = try db.query(DefaultCountRow, allocator, sql, &[_][]const u8{user_id_str});
    defer db.freeRows(DefaultCountRow, allocator, rows);
    return rows.len > 0 and rows[0].count > 0;
}

fn getDefaultProviderId(allocator: std.mem.Allocator, user_id: i64) !?[]u8 {
    const sql = "SELECT provider, api_key, model, NULLIF(base_url, ''), is_default, updated_at FROM llm_provider_configs WHERE user_id = ? ORDER BY is_default DESC, updated_at DESC LIMIT 1";
    const user_id_str = try std.fmt.allocPrint(allocator, "{d}", .{user_id});
    defer allocator.free(user_id_str);
    const rows = try db.query(ConfigRow, allocator, sql, &[_][]const u8{user_id_str});
    defer db.freeRows(ConfigRow, allocator, rows);
    if (rows.len == 0) return null;
    return try allocator.dupe(u8, rows[0].provider);
}

fn getPostContext(allocator: std.mem.Allocator, post_id: i64) !?[]PostContext {
    const sql =
        \\SELECT p.id, p.content, p.created_at, u.username, u.display_name
        \\FROM posts p
        \\JOIN users u ON p.user_id = u.id
        \\WHERE p.id = ?
        \\LIMIT 1
    ;
    const post_id_str = try std.fmt.allocPrint(allocator, "{d}", .{post_id});
    defer allocator.free(post_id_str);
    const rows = try db.query(PostContext, allocator, sql, &[_][]const u8{post_id_str});
    if (rows.len == 0) {
        db.freeRows(PostContext, allocator, rows);
        return null;
    }
    return rows;
}

fn buildSystemPrompt(allocator: std.mem.Allocator, post_context: ?[]PostContext) ![]u8 {
    if (post_context) |rows| {
        const post = rows[0];
        const author = post.display_name orelse post.username;
        return std.fmt.allocPrint(
            allocator,
            "You are the in-app AI assistant for Xeetapus. Help the user with general questions and with analyzing posts. If you go beyond the provided post, say that clearly. The current post context is from @{s} ({s}) at {s}: {s}",
            .{ post.username, author, post.created_at, post.content },
        );
    }
    return allocator.dupe(
        u8,
        "You are the in-app AI assistant for Xeetapus. Help the user with general questions. Keep answers grounded, concise, and explicit when you are inferring.",
    );
}

fn sendOpenAiCompatibleRequest(
    allocator: std.mem.Allocator,
    provider: ProviderSpec,
    api_key: []const u8,
    model: []const u8,
    base_url: ?[]const u8,
    system_prompt: []const u8,
    messages: []ChatMessage,
) !ProviderCallResult {
    var body: std.ArrayListUnmanaged(u8) = .{};
    defer body.deinit(allocator);
    try body.appendSlice(allocator, "{\"model\":");
    try body.writer(allocator).print("{f}", .{std.json.fmt(model, .{})});
    try body.appendSlice(allocator, ",\"messages\":[");
    try appendMessageObject(body.writer(allocator), "system", system_prompt);
    for (messages) |message| {
        try body.appendSlice(allocator, ",");
        try appendMessageObject(body.writer(allocator), message.role, message.content);
    }
    try body.appendSlice(allocator, "],\"temperature\":0.7}");

    const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
    defer allocator.free(auth_header);

    var headers: std.ArrayListUnmanaged(std.http.Header) = .{};
    defer headers.deinit(allocator);
    try headers.append(allocator, .{ .name = "Authorization", .value = auth_header });
    if (std.mem.eql(u8, provider.id, "openrouter")) {
        try headers.append(allocator, .{ .name = "HTTP-Referer", .value = "https://xeetapus.local" });
        try headers.append(allocator, .{ .name = "X-Title", .value = "Xeetapus" });
    }

    const response = try postJson(allocator, base_url orelse provider.default_endpoint, body.items, headers.items);
    defer allocator.free(response.body);

    if (response.status >= 300) {
        return .{ .error_message = try extractProviderError(allocator, response.body, response.status) };
    }

    return .{ .success = try extractOpenAiCompatibleReply(allocator, response.body) };
}

fn sendAnthropicRequest(
    allocator: std.mem.Allocator,
    provider: ProviderSpec,
    api_key: []const u8,
    model: []const u8,
    base_url: ?[]const u8,
    system_prompt: []const u8,
    messages: []ChatMessage,
) !ProviderCallResult {
    _ = provider;
    var body: std.ArrayListUnmanaged(u8) = .{};
    defer body.deinit(allocator);
    try body.appendSlice(allocator, "{\"model\":");
    try body.writer(allocator).print("{f}", .{std.json.fmt(model, .{})});
    try body.appendSlice(allocator, ",\"max_tokens\":1024,\"system\":");
    try body.writer(allocator).print("{f}", .{std.json.fmt(system_prompt, .{})});
    try body.appendSlice(allocator, ",\"messages\":[");

    var first = true;
    for (messages) |message| {
        if (std.mem.eql(u8, message.role, "system")) continue;
        if (!first) try body.appendSlice(allocator, ",");
        first = false;
        try appendMessageObject(body.writer(allocator), message.role, message.content);
    }
    try body.appendSlice(allocator, "]}");

    var headers: std.ArrayListUnmanaged(std.http.Header) = .{};
    defer headers.deinit(allocator);
    try headers.append(allocator, .{ .name = "x-api-key", .value = api_key });
    try headers.append(allocator, .{ .name = "anthropic-version", .value = "2023-06-01" });

    const response = try postJson(allocator, base_url orelse "https://api.anthropic.com/v1/messages", body.items, headers.items);
    defer allocator.free(response.body);

    if (response.status >= 300) {
        return .{ .error_message = try extractProviderError(allocator, response.body, response.status) };
    }

    return .{ .success = try extractAnthropicReply(allocator, response.body) };
}

fn sendGeminiRequest(
    allocator: std.mem.Allocator,
    provider: ProviderSpec,
    api_key: []const u8,
    model: []const u8,
    system_prompt: []const u8,
    messages: []ChatMessage,
) !ProviderCallResult {
    const url = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}:generateContent?key={s}",
        .{ provider.default_endpoint, model, api_key },
    );
    defer allocator.free(url);

    var body: std.ArrayListUnmanaged(u8) = .{};
    defer body.deinit(allocator);
    try body.appendSlice(allocator, "{\"systemInstruction\":{\"parts\":[{\"text\":");
    try body.writer(allocator).print("{f}", .{std.json.fmt(system_prompt, .{})});
    try body.appendSlice(allocator, "}]},\"contents\":[");

    var first = true;
    for (messages) |message| {
        if (std.mem.eql(u8, message.role, "system")) continue;
        if (!first) try body.appendSlice(allocator, ",");
        first = false;
        const role = if (std.mem.eql(u8, message.role, "assistant")) "model" else "user";
        try body.writer(allocator).print("{{\"role\":\"{s}\",\"parts\":[{{\"text\":", .{role});
        try body.writer(allocator).print("{f}", .{std.json.fmt(message.content, .{})});
        try body.appendSlice(allocator, "}]}");
        try body.appendSlice(allocator, "}");
    }
    try body.appendSlice(allocator, "],\"generationConfig\":{\"temperature\":0.7}}");

    const response = try postJson(allocator, url, body.items, &.{});
    defer allocator.free(response.body);

    if (response.status >= 300) {
        return .{ .error_message = try extractProviderError(allocator, response.body, response.status) };
    }

    return .{ .success = try extractGeminiReply(allocator, response.body) };
}

fn appendMessageObject(writer: anytype, role: []const u8, content: []const u8) !void {
    try writer.writeAll("{\"role\":");
    try writer.print("{f}", .{std.json.fmt(role, .{})});
    try writer.writeAll(",\"content\":");
    try writer.print("{f}", .{std.json.fmt(content, .{})});
    try writer.writeAll("}");
}

const REQUEST_TIMEOUT_MS: u64 = 60000; // 60 seconds total timeout

fn postJson(
    allocator: std.mem.Allocator,
    url: []const u8,
    payload: []const u8,
    extra_headers: []const std.http.Header,
) !HttpResponseBody {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response: std.ArrayListUnmanaged(u8) = .{};
    defer response.deinit(allocator);

    const start_time = std.time.milliTimestamp();

    var body_writer = std.io.Writer.Allocating.init(allocator);
    defer body_writer.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = payload,
        .headers = .{
            .content_type = .{ .override = "application/json" },
        },
        .extra_headers = extra_headers,
        .response_writer = @ptrCast(@constCast(&response.writer(allocator))),
    }) catch |err| {
        const elapsed = std.time.milliTimestamp() - start_time;
        std.log.warn("LLM request failed after {d}ms: {s}", .{ elapsed, @errorName(err) });
        // Provide more specific error messages
        return switch (err) {
            error.ConnectionTimedOut => error.ProviderRequestTimeout,
            else => error.ProviderRequestFailed,
        };
    };

    const elapsed = std.time.milliTimestamp() - start_time;
    std.log.info("LLM request completed in {d}ms", .{elapsed});

    // Check if request took longer than timeout threshold
    if (elapsed > REQUEST_TIMEOUT_MS) {
        return error.ProviderRequestTimeout;
    }

    return .{
        .status = @intFromEnum(result.status),
        .body = try response.toOwnedSlice(allocator),
    };
}

fn extractOpenAiCompatibleReply(allocator: std.mem.Allocator, response_body: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response_body, .{}) catch {
        return error.ProviderBadResponse;
    };
    defer parsed.deinit();

    const root = parsed.value;
    const choices = getObjectValue(root, "choices") orelse return error.ProviderBadResponse;
    if (choices != .array or choices.array.items.len == 0) return error.ProviderBadResponse;
    const message = getObjectValue(choices.array.items[0], "message") orelse return error.ProviderBadResponse;
    const content = getObjectValue(message, "content") orelse return error.ProviderBadResponse;
    return valueToText(allocator, content);
}

fn extractAnthropicReply(allocator: std.mem.Allocator, response_body: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response_body, .{}) catch {
        return error.ProviderBadResponse;
    };
    defer parsed.deinit();

    const root = parsed.value;
    const content = getObjectValue(root, "content") orelse return error.ProviderBadResponse;
    return valueToText(allocator, content);
}

fn extractGeminiReply(allocator: std.mem.Allocator, response_body: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response_body, .{}) catch {
        return error.ProviderBadResponse;
    };
    defer parsed.deinit();

    const root = parsed.value;
    const candidates = getObjectValue(root, "candidates") orelse return error.ProviderBadResponse;
    if (candidates != .array or candidates.array.items.len == 0) return error.ProviderBadResponse;
    const content = getObjectValue(candidates.array.items[0], "content") orelse return error.ProviderBadResponse;
    return valueToText(allocator, content);
}

fn getObjectValue(value: std.json.Value, key: []const u8) ?std.json.Value {
    if (value != .object) return null;
    return value.object.get(key);
}

fn extractProviderError(allocator: std.mem.Allocator, response_body: []const u8, status: u16) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response_body, .{}) catch {
        const trimmed = std.mem.trim(u8, response_body, " \n\r\t");
        if (trimmed.len > 0) {
            return allocator.dupe(u8, trimmed);
        }
        return std.fmt.allocPrint(allocator, "Provider returned HTTP {d}", .{status});
    };
    defer parsed.deinit();

    if (findErrorMessage(parsed.value)) |message| {
        const trimmed = std.mem.trim(u8, message, " \n\r\t");
        if (trimmed.len > 0) {
            return allocator.dupe(u8, trimmed);
        }
    }

    const trimmed = std.mem.trim(u8, response_body, " \n\r\t");
    if (trimmed.len > 0) {
        return allocator.dupe(u8, trimmed);
    }

    return std.fmt.allocPrint(allocator, "Provider returned HTTP {d}", .{status});
}

fn findErrorMessage(value: std.json.Value) ?[]const u8 {
    switch (value) {
        .string => |text| return text,
        .object => |object| {
            if (object.get("error")) |error_value| {
                if (findErrorMessage(error_value)) |message| return message;
            }
            if (object.get("message")) |message_value| {
                if (findErrorMessage(message_value)) |message| return message;
            }
            if (object.get("detail")) |detail_value| {
                if (findErrorMessage(detail_value)) |message| return message;
            }
            if (object.get("details")) |details_value| {
                if (findErrorMessage(details_value)) |message| return message;
            }
            return null;
        },
        .array => |array| {
            for (array.items) |item| {
                if (findErrorMessage(item)) |message| return message;
            }
            return null;
        },
        else => return null,
    }
}

fn valueToText(allocator: std.mem.Allocator, value: std.json.Value) ![]u8 {
    switch (value) {
        .string => |text| return allocator.dupe(u8, text),
        .array => |array| {
            var result: std.ArrayListUnmanaged(u8) = .{};
            defer result.deinit(allocator);
            for (array.items) |item| {
                const next = valueToText(allocator, item) catch continue;
                defer allocator.free(next);
                if (next.len == 0) continue;
                if (result.items.len > 0) try result.appendSlice(allocator, "\n\n");
                try result.appendSlice(allocator, next);
            }
            if (result.items.len == 0) return error.ProviderBadResponse;
            return result.toOwnedSlice(allocator);
        },
        .object => |object| {
            if (object.get("text")) |text_value| {
                return valueToText(allocator, text_value);
            }
            if (object.get("content")) |content_value| {
                return valueToText(allocator, content_value);
            }
            if (object.get("parts")) |parts_value| {
                return valueToText(allocator, parts_value);
            }
            return error.ProviderBadResponse;
        },
        else => return error.ProviderBadResponse,
    }
}
