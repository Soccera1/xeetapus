# Security Implementation

Xeetapus implements comprehensive security measures following OWASP guidelines. This document describes the security architecture and implementation details.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Password Security](#password-security)
- [Session Management](#session-management)
- [CSRF Protection](#csrf-protection)
- [Rate Limiting](#rate-limiting)
- [CORS Security](#cors-security)
- [SecurityHeaders](#security-headers)
- [Input Validation](#input-validation)
- [Path Traversal Protection](#path-traversal-protection)
- [SQL Injection Prevention](#sql-injection-prevention)
- [Audit Logging](#audit-logging)
- [Best Practices](#best-practices)

---

## Overview

Xeetapus is built with security as a core principle, not an afterthought. All security features are enabled by default with sensible configurations.

### Security Features Summary

| Feature | Implementation | Status |
|---------|----------------|--------|
| Password Hashing | PBKDF2-HMAC-SHA256 | ✅ |
| JWT Tokens | HMAC-SHA256 signatures | ✅ |
| Cookie Security | HttpOnly, SameSite, Secure | ✅ |
| CSRF Protection | Signed tokens | ✅ |
| Rate Limiting | IP-based sliding window | ✅ |
| CORS | Whitelist-based | ✅ |
| Security Headers | Full OWASP set | ✅ |
| Input Validation | Strict validation | ✅ |
| Path Traversal | Canonical path checking | ✅ |
| SQL Injection | Parameterized queries | ✅ |
| XSS Prevention | Content sanitization | ✅ |
| Audit Logging | Security events | ✅ |

---

## Authentication

### Architecture

Xeetapus uses a JWT-based authentication system with secure cookie storage.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Browser    │────▶│   Backend    │────▶│   Database   │
└──────────────┘     └──────────────┘     └──────────────┘
        │                   │                    │
        │ Login Credentials │                    │
        │ ──────────────────▶│                    │
        │                    │ Verify Password    │
        │                    │ ──────────────────▶│
        │                    │                    │
        │                    │ Generate JWT       │
        │                    │◀──────────────────││
        │ Set-Cookie: session│                    │
        │◀──────────────────│                    │
        │                    │                    │
```

### Implementation

**File**: `backend/src/auth.zig`

The authentication flow:

1. **Registration**:
   - Validates username and email
   - Hashes password with PBKDF2
   - Creates user record
   - Returns success (no auto-login)

2. **Login**:
   - Validates credentials
   - Generates JWT token
   - Sets secure httpOnly cookie
   - Returns user profile

3. **Session Verification**:
   - Extracts JWT from cookie
   - Verifies signature and expiration
   - Loads user from database
   - Attaches user to request

### Token Format

Xeetapus uses JWT-format tokens with HMAC-SHA256 signatures:

```
base64(header).base64(payload).base64(signature)
```

**Header**:
```json
{"alg":"HS256","typ":"JWT"}
```

**Payload**:
```json
{"sub":1,"iat":1712345678,"exp":1712432078}
```

- `sub`: User ID
- `iat`: Issued at (Unix timestamp)
- `exp`: Expiration time (Unix timestamp)

---

## Password Security

### Implementation

**File**: `backend/src/password.zig`

Xeetapus uses **PBKDF2-HMAC-SHA256** for password hashing with:

- **32,768 iterations**: Configurable, provides strong resistance to brute force
- **32-byte salt**: Cryptographically random salt for each password
- **32-byte hash**: Full SHA-256 output length

### Hash Format

```
$pbkdf2-sha256$v2$32768$<base64(salt)>$<base64(hash)>
```

### Password Requirements

- Minimum length: 8 characters
- Maximum length: 128 characters
- Must contain:
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one digit
- Recommended: at least one special character

### Hash Verification

```zig
pub fn verifyPassword(allocator: std.mem.Allocator, password: []const u8, stored_hash: []const u8) !bool {
    const hash_type = detectHashType(stored_hash);
    
    return switch (hash_type) {
        .modern_pbkdf2 => verifyPbkdf2V2(allocator, password, stored_hash),
        .legacy_pbkdf2 => verifyLegacyPbkdf2(allocator, password, stored_hash),
        .legacy_sha256 => verifyLegacySha256(password, stored_hash),
    };
}
```

### Password Migration

Xeetapus supports password format migration:

1. **Legacy formats** are still accepted for verification
2. **New passwords** use the modern format
3. **Old passwords** are upgraded on successful login

---

## Session Management

### Cookie Configuration

| Attribute | Development | Production |
|-----------|-------------|------------|
| HttpOnly | ✅ | ✅ |
| Secure | ❌ | ✅ |
| SameSite | Lax | Lax |
| MaxAge | 7 days | 7 days |

### Implementation

```zig
// Cookie settings based on environment
const cookie_secure = std.mem.eql(u8, env, "production");
const cookie_http_only = true;
const cookie_same_site = "Lax";
```

### Session Expiry

- **Access Token Expiry**: 7 days (configurable)
- **Sliding Window**: Sessions can be refreshed
- **Automatic Logout**: On expiration

---

## CSRF Protection

### Implementation

**File**: `backend/src/tokens.zig`

Xeetapus implements CSRF protection using signed tokens:

1. **Token Generation**:
   ```zig
   pub fn generateCsrfToken(allocator: std.mem.Allocator, secret: []const u8, session_id: []const u8) ![]u8 {
       const timestamp = std.time.timestamp();
       const nonce = try generateSecureTokenAlloc(allocator);
       // Create HMAC of session_id + timestamp + nonce
       var sig: [32]u8 = undefined;
       var hasher = crypto.hash.sha2.Sha256.init(.{});
       hasher.update(secret);
       hasher.update(session_id);
       hasher.update(timestamp_bytes);
       hasher.update(nonce);
       hasher.final(&sig);
       return format("{d}:{s}:{s}", .{ timestamp, nonce, sig_hex });
   }
   ```

2. **Token Verification**:
   - Extracts timestamp and nonce
   - Verifies token hasn't expired (24-hour max age)
   - Recomputes HMAC signature
   - Constant-time comparison

### Usage

For state-changing operations (POST, PUT, DELETE):

```http
POST /api/posts
X-CSRF-Token: 1712345678:abc123...:def456...
Content-Type: application/json

{"content":"Hello, world!"}
```

### When CSRF is Checked

- POST requests
- PUT requests
- DELETE requests
- Not required for GET requests (read-only)

---

## Rate Limiting

### Implementation

**File**: `backend/src/ratelimit.zig`

Xeetapus implements IP-based rate limiting with a sliding window algorithm:

```zig
pub const RateLimiter = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(RateLimitEntry),
    max_requests: u32,
    window_seconds: i64,
    mutex: std.Thread.Mutex,
    //...
};
```

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `XEETAPUS_RATE_LIMIT_REQUESTS` | 100 | Max requests per window |
| `XEETAPUS_RATE_LIMIT_WINDOW` | 60 | Window size in seconds |

### Rate Limit Headers

Responses include rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1712345678
```

### When Rate Limited

Returns HTTP 429 with JSON:

```json
{
  "error": "Rate limit exceeded. Please try again later.",
  "status": "error"
}
```

### IP Detection

The rate limiter checks multiple headers for the real IP:

1. `X-Forwarded-For` (first IP in chain)
2. `X-Real-IP`
3. Remote socket address

---

## CORS Security

### Implementation

**File**: `backend/src/config.zig`

Xeetapus uses **whitelist-based CORS** - no wildcards allowed.

```zig
pub fn isOriginAllowed(origin: []const u8) bool {
    const cfg = instance orelse return true;
    
    for (cfg.allowed_origins) |allowed| {
        if (std.mem.eql(u8, allowed, origin)) {
            return true;
        }
        // Support wildcard subdomains
        if (std.mem.startsWith(u8, allowed, "*.")) {
            const domain = allowed[2..];
            if (std.mem.endsWith(u8, origin, domain)) {
                return true;
            }
        }
    }
    return false;
}
```

### Configuration

Set allowed origins via environment:

```bash
XEETAPUS_ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

### Wildcard Subdomains

Support for wildcard subdomains:

```bash
# Allows app.example.com, api.example.com, etc.
XEETAPUS_ALLOWED_ORIGINS=*.example.com
```

### CORS Headers

```http
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token
```

---

## Security Headers

### Implementation

**File**: `backend/src/http.zig`

Xeetapus sets comprehensive security headers on all responses:

```zig
pub fn addSecurityHeaders(self: *Response, is_production: bool) void {
    // Prevent clickjacking
    self.headers.put("X-Frame-Options", "DENY") catch {};
    
    // Prevent MIME type sniffing
    self.headers.put("X-Content-Type-Options", "nosniff") catch {};
    
    // XSS Protection
    self.headers.put("X-XSS-Protection", "1; mode=block") catch {};
    
    // Referrer Policy
    self.headers.put("Referrer-Policy", "strict-origin-when-cross-origin") catch {};
    
    // Permissions Policy
    self.headers.put("Permissions-Policy", "geolocation=(), microphone=(), camera=()") catch {};
    
    // Content Security Policy
    self.headers.put("Content-Security-Policy", 
        "default-src 'self'; " ++
        "script-src 'self'; " ++
        "style-src 'self' 'unsafe-inline'; " ++
        "img-src 'self' data: https:; " ++
        "font-src 'self'; " ++
        "connect-src 'self'; " ++
        "frame-ancestors 'none'; " ++
        "base-uri 'self'; " ++
        "form-action 'self';"
    ) catch {};
    
    // HSTS in production
    if (is_production) {
        self.headers.put("Strict-Transport-Security", 
            "max-age=31536000; includeSubDomains; preload") catch {};
    }
}
```

### Header Reference

| Header | Value | Purpose |
|--------|-------|---------|
| X-Frame-Options | DENY | Prevent clickjacking |
| X-Content-Type-Options | nosniff | Prevent MIME sniffing |
| X-XSS-Protection | 1; mode=block | XSS protection |
| Referrer-Policy | strict-origin-when-cross-origin | Control referrer |
| Permissions-Policy | geolocation=(), microphone=(), camera=() | Disable unnecessary APIs |
| Content-Security-Policy | (see above) | XSS mitigation |
| Strict-Transport-Security | max-age=31536000; includeSubDomains; preload | Force HTTPS (production only) |

---

## Input Validation

### Implementation

**File**: `backend/src/validation.zig`

### Username Validation

```zig
pub fn validateUsername(username: []const u8) ?[]const u8 {
    // Length: 3-30 characters
    if (username.len < 3 or username.len > 30) {
        return "Username must be between 3 and 30 characters";
    }
    
    // Characters: alphanumeric, underscore, hyphen
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
```

### Email Validation

```zig
pub fn validateEmail(email: []const u8) ?[]const u8 {
    // Length: 5-254 characters
    if (email.len < 5 or email.len > 254) {
        return "Invalid email length";
    }
    
    // Basic format check
    // - Must contain @
    // - Must contain . after @
    // - No consecutive dots
    // - Valid characters only
    
    return null;
}
```

### Password Validation

```zig
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
    
    for (password) |c| {
        if (std.ascii.isUpper(c)) has_upper = true;
        if (std.ascii.isLower(c)) has_lower = true;
        if (std.ascii.isDigit(c)) has_digit = true;
    }
    
    if (!has_upper or !has_lower or !has_digit) {
        return "Password must contain uppercase, lowercase, and digit";
    }
    
    return null;
}
```

### XSS Prevention

Content sanitization for user-generated content:

```zig
pub fn sanitizeContent(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    // Escapes: < > & " ' /
    // < → &lt;
    // > → &gt;
    // & → &amp;
    // " → &quot;
    // ' → &#x27;
    // / → &#x2F;
    
    return sanitized_content;
}
```

---

## Path Traversal Protection

### Implementation

**File**: `backend/src/main.zig`

All static file serving includes path traversal protection:

```zig
fn serveStaticFiles(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
    const path = req.params.get("path") orelse "index.html";
    
    // SECURITY: Check for path traversal sequences
    if (std.mem.indexOf(u8, path, "..") != null or
        std.mem.indexOf(u8, path, "~") != null or
        std.mem.startsWith(u8, path, "/") or
        std.mem.indexOf(u8, path, "\\") != null)
    {
        res.status = 403;
        try res.append("Forbidden");
        return;
    }
    
    // Resolve to absolute path
    const abs_path = try std.fs.cwd().realpathAlloc(allocator, full_path);
    const public_dir_abs = try std.fs.cwd().realpathAlloc(allocator, PUBLIC_DIR);
    
    // Ensure resolved path is within PUBLIC_DIR
    if (!std.mem.startsWith(u8, abs_path, public_dir_abs)) {
        res.status = 403;
        try res.append("Forbidden");
        return;
    }
    
    // Serve file...
}
```

### Protection Checks

1. **Pattern Detection**: Blocks `..`, `~`, `/`, `\`
2. **Canonical Path**: Resolves to absolute path
3. **BoundaryCheck**: Verifies path is within allowed directory

---

## SQL Injection Prevention

### Implementation

All database queries use parameterized statements:

```zig
pub fn query(comptime T: type, allocator: std.mem.Allocator, sql: []const u8, params: []const []const u8) ![]T {
    const database = try getDb();
    var stmt: ?*c.sqlite3_stmt = null;
    
    // Prepare statement
    const result = c.sqlite3_prepare_v2(database, sql.ptr, @intCast(sql.len), &stmt, null);
    
    // Bind parameters (prevents SQL injection)
    for (params, 0..) |param, i| {
        _ = c.sqlite3_bind_text(stmt, @intCast(i + 1), param.ptr, @intCast(param.len), c.SQLITE_STATIC);
    }
    
    // Execute and fetch results...
}
```

### Example Usage

```zig
// SAFE: Parameterized query
const users = try db.query(User, allocator, 
    "SELECT * FROM users WHERE username = ?",
    &[_][]const u8{username}
);

// NEVER do this (vulnerable to SQL injection):
// const sql = try std.fmt.allocPrint(allocator, 
//     "SELECT * FROM users WHERE username = '{s}'", 
//     .{username}
// );
```

---

## Audit Logging

### Implementation

**File**: `backend/src/audit.zig`

Xeetapus logs security-relevant events for monitoring and forensics:

```zig
pub const AuditEvent = struct {
    timestamp: i64,
    action: []const u8,
    user_id: ?i64,
    ip_address: []const u8,
    user_agent: ?[]const u8,
    details: ?[]const u8,
    success: bool,
};
```

### Logged Events

| Category | Events |
|----------|--------|
| Authentication | login, logout, register |
| Account | password_change, email_change, account_delete |
| Social | block, unblock |
| Content | post_create, post_delete |

### Log Format

Events are logged as JSON:

```json
{"timestamp":1712345678,"action":"login","user_id":1,"ip":"192.168.1.1","user_agent":"Mozilla/5.0...","details":null,"success":true}
```

### Log Location

- **Development**: stdout
- **Production**: `/var/log/xeetapus.log`

---

## Best Practices

### Production Deployment Checklist

- [ ] Generate strong JWT secret (64+ characters)
- [ ] Generate strong CSRF secret (32+ characters)
- [ ] Set `XEETAPUS_ENV=production`
- [ ] Configure allowed CORS origins
- [ ] Enable HTTPS with valid certificate
- [ ] Set secure cookie flag
- [ ] Configure rate limits
- [ ] Set up audit log storage
- [ ] Configure database file permissions (600)
- [ ] Run behind reverse proxy (nginx/Caddy)
- [ ] Configure HSTS headers

### Security Hardening

1. **Secrets Management**:
   ```bash
   # Generate secrets
   openssl rand -base64 64  # JWT secret
   openssl rand -base64 32  # CSRF secret
   ```

2. **Database Security**:
   ```bash
   chmod 600 xeetapus.db
   chown www-data:www-data xeetapus.db
   ```

3. **File Permissions**:
   ```bash
   # Limit access to configuration
   chmod 600 .env
   ```

4. **Network Security**:
   - Run behind firewall
   - Only expose necessary ports
   - Use reverse proxy for SSL termination

### Testing Security

```bash
# Test rate limiting (should return 429 after 100 requests)
for i in {1..101}; do curl -s http://localhost:8080/api/health > /dev/null; done

# Test path traversal (should return 403)
curl http://localhost:8080/../../../etc/passwd

# Check security headers
curl -I http://localhost:8080/api/health

# Test weak password (should fail)
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"123"}'
```

---

## Vulnerability Disclosure

See [SECURITY.md](../SECURITY.md) for responsible disclosure guidelines.

---

## Security Updates

Stay informed about security updates by:
1. Watching the repository
2. Checking releases regularly
3. Reviewing this documentation for changes