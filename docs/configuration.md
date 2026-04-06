# Configuration Reference

Complete reference for all Xeetapus configuration options.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Backend Configuration](#backend-configuration)
- [Frontend Configuration](#frontend-configuration)
- [Nginx Configuration](#nginx-configuration)
- [OpenRC Configuration](#openrc-configuration)
- [Security Configuration](#security-configuration)
- [Performance Tuning](#performance-tuning)

---

## Environment Variables

### Required Variables

These must be set for the application to function properly.

| Variable | Description | Example |
|----------|-------------|---------|
| `XEETAPUS_JWT_SECRET` | JWT signing secret (64+ chars) | `openssl rand -base64 64` |
| `XEETAPUS_CSRF_SECRET` | CSRF token secret (32+ chars) | `openssl rand -base64 32` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `XEETAPUS_ENV` | `development` | Environment (`development`, `staging`, `production`) |
| `XEETAPUS_PORT` | `8080` | Server port |
| `XEETAPUS_DB_PATH` | `xeetapus.db` | Database file path |
| `XEETAPUS_MEDIA_PATH` | `/var/www/xeetapus/media` | Media upload directory |
| `XEETAPUS_ALLOWED_ORIGINS` | `http://localhost:3000` | CORS origins (comma-separated) |
| `XEETAPUS_BCRYPT_COST` | `12` | _Deprecated/unused - Password hashing uses PBKDF2 |
| `XEETAPUS_MAX_REQUEST_SIZE` | `10485760` | Max request size in bytes (default: 10MB) |
| `XEETAPUS_RATE_LIMIT_REQUESTS` | `100` | Max requests per window |
| `XEETAPUS_RATE_LIMIT_WINDOW` | `60` | Rate limit window in seconds |
| `XEETAPUS_MONERO_ADDRESS` | - | Monero wallet address |
| `XEETAPUS_MONEROD_URL` | `http://localhost:18081` | Monero daemon RPC URL |

---

## Backend Configuration

### Environment File

**File**: `backend/.env`

```bash
# ==============================================================================
# Xeetapus Backend Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# REQUIRED SETTINGS
# ------------------------------------------------------------------------------

# JWT Secret for token signing
# Generate with: openssl rand -base64 64
# Minimum length: 64 characters in production
XEETAPUS_JWT_SECRET=your-super-secure-jwt-secret-change-this-in-production

# CSRF Secret for token generation
# Generate with: openssl rand -base64 32
# Minimum length: 32 characters in production
XEETAPUS_CSRF_SECRET=your-csrf-secret-change-this-in-production

# ------------------------------------------------------------------------------
# SERVER SETTINGS
# ------------------------------------------------------------------------------

# Environment mode
# Options: development, staging, production
# Default: development
XEETAPUS_ENV=development

# Server port
# Default: 8080
XEETAPUS_PORT=8080

# ------------------------------------------------------------------------------
# DATABASE SETTINGS
# ------------------------------------------------------------------------------

# SQLite database path
# Default: xeetapus.db (relative to working directory)
XEETAPUS_DB_PATH=xeetapus.db

# ------------------------------------------------------------------------------
# MEDIA SETTINGS
# ------------------------------------------------------------------------------

# Media upload directory
# Default: /var/www/xeetapus/media
XEETAPUS_MEDIA_PATH=/var/www/xeetapus/media

# ------------------------------------------------------------------------------
# SECURITY SETTINGS
# ------------------------------------------------------------------------------

# CORS allowed origins (comma-separated for multiple)
# No wildcards allowed except for subdomains (*.example.com)
# Default: http://localhost:3000
# Production example: https://example.com,https://www.example.com
XEETAPUS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

# Password hashing cost (deprecated - not used)
# The implementation now uses PBKDF2-HMAC-SHA256 with fixed 32,768 iterations
# This setting is kept for backward compatibility
# XEETAPUS_BCRYPT_COST=12

# Maximum request size in bytes
# Default: 10485760 (10 MB)
XEETAPUS_MAX_REQUEST_SIZE=10485760

# ------------------------------------------------------------------------------
# RATE LIMITING
# ------------------------------------------------------------------------------

# Maximum requests per window (per IP)
# Default: 100
XEETAPUS_RATE_LIMIT_REQUESTS=100

# Rate limit window in seconds
# Default: 60
XEETAPUS_RATE_LIMIT_WINDOW=60

# ------------------------------------------------------------------------------
# MONERO PAYMENTS (Optional)
# ------------------------------------------------------------------------------

# Monero wallet address for receiving payments
# Example: 4B6V4rjoiYSY85ZwbtLDGNAhxLdZTrmjFPRaLEXLAD2YjR6ewxJ4enQC481RrcRLQx8AhKkMgVaSCSpUEYyJPZV5FWmZ3g5
# XEETAPUS_MONERO_ADDRESS=

# Monero daemon RPC URL
# Default: http://localhost:18081
# XEETAPUS_MONEROD_URL=http://localhost:18081
```

### Configuration Loading

Configuration is loaded from environment variables in `config.zig`:

```zig
pub const Config = struct {
    jwt_secret: []const u8,
    csrf_secret: []const u8,
    database_path: []const u8,
    media_path: []const u8,
    server_port: u16,
    allowed_origins: []const []const u8,
    bcrypt_cost: u6,
    max_request_size: usize,
    rate_limit_requests: u32,
    rate_limit_window_seconds: i64,
    environment: []const u8,
    cookie_secure: bool,
    cookie_http_only: bool,
    cookie_same_site: []const u8,
    //...
};
```

---

## Frontend Configuration

### Environment File

**File**: `frontend/.env`

```bash
# ==============================================================================
# Xeetapus Frontend Configuration
# ==============================================================================

# API URL
# Development: http://localhost:8080/api
# Production: https://your-domain.com/api
VITE_API_URL=http://localhost:8080/api
```

### Production Environment

**File**: `frontend/.env.production`

```bash
# Production API URL
VITE_API_URL=https://api.yourdomain.com/api
```

### Vite Configuration

**File**: `frontend/vite.config.ts`

Key configuration options:

```typescript
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        credentials: 'include',
      },
      '/media': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        credentials: 'include',
      }
    }
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        },
      },
    },
  },
})
```

---

## Nginx Configuration

### Reverse Proxy

**File**: `/etc/nginx/sites-available/xeetapus`

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    # SSL
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Upload size
    client_max_body_size 10M;

    # API
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Media
    location /media {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## OpenRC Configuration

### Service Script

**File**: `/etc/init.d/xeetapus`

The main service script (see `deploy/openrc/xeetapus`).

### Configuration File

**File**: `/etc/conf.d/xeetapus` (optional)

```bash
# User to run as
XEETAPUS_USER=nginx

# Group to run as
XEETAPUS_GROUP=nginx

# Installation directory
XEETAPUS_DIR=/var/www/xeetapus

# Log file path
XEETAPUS_LOG=/var/log/xeetapus.log
```

### Managing the Service

```bash
# Add to default runlevel
rc-update add xeetapus default

# Start
rc-service xeetapus start

# Stop
rc-service xeetapus stop

# Restart
rc-service xeetapus restart

# Status
rc-service xeetapus status
```

---

## Security Configuration

### Secret Generation

```bash
# JWT Secret (64+ characters)
openssl rand -base64 64

# CSRF Secret (32+ characters)
openssl rand -base64 32
```

### File Permissions

```bash
# Configuration file
chmod 600 /var/www/xeetapus/.env

# Database file
chmod 600 /var/www/xeetapus/xeetapus.db

# Media directory
chmod 750 /var/www/xeetapus/media
```

### CORS Configuration

For production, specify exact domains:

```bash
# Single domain
XEETAPUS_ALLOWED_ORIGINS=https://example.com

# Multiple domains
XEETAPUS_ALLOWED_ORIGINS=https://example.com,https://app.example.com,https://api.example.com

# Subdomain wildcard
XEETAPUS_ALLOWED_ORIGINS=*.example.com
```

### Cookie Security

Production cookies are automatically configured with:

| Attribute | Value |
|-----------|-------|
| HttpOnly | Yes |
| Secure | Yes (HTTPS only) |
| SameSite | Lax |

Development cookies have `Secure` disabled for HTTP testing.

---

## Performance Tuning

### Rate Limiting

Adjust based on your needs:

```bash
# Conservative (stricter limits)
XEETAPUS_RATE_LIMIT_REQUESTS=50
XEETAPUS_RATE_LIMIT_WINDOW=60

# Aggressive (higher limits)
XEETAPUS_RATE_LIMIT_REQUESTS=200
XEETAPUS_RATE_LIMIT_WINDOW=60

# API-only limits (implement in reverse proxy)
# See Nginx rate limiting configuration
```

### Database Optimization

```bash
# Optimize database periodically
sqlite3 /var/www/xeetapus/xeetapus.db "VACUUM;"

# Analyze for query optimization
sqlite3 /var/www/xeetapus/xeetapus.db "ANALYZE;"
```

### Memory Usage

- Backend binary size: ~2-5 MB
- Memory per request: Depends on request size
- Database: File-based, grows with data

### Connection Handling

The backend handles connections in a single process:

- No connection pooling (SQLite)
- Each request creates temporary allocations
- Arena allocators for request lifetime

---

## Environment-Specific Configurations

### Development

```bash
XEETAPUS_ENV=development
XEETAPUS_PORT=8080
XEETAPUS_DB_PATH=xeetapus.db
XEETAPUS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
# Note: XEETAPUS_BCRYPT_COST is deprecated/not used - hashing uses PBKDF2 with fixed iterations
```

### Staging

```bash
XEETAPUS_ENV=staging
XEETAPUS_PORT=8080
XEETAPUS_DB_PATH=/var/www/xeetapus/xeetapus.db
XEETAPUS_ALLOWED_ORIGINS=https://staging.example.com
```

### Production

```bash
XEETAPUS_ENV=production
XEETAPUS_PORT=8080
XEETAPUS_DB_PATH=/var/www/xeetapus/xeetapus.db
XEETAPUS_MEDIA_PATH=/var/www/xeetapus/media
XEETAPUS_ALLOWED_ORIGINS=https://example.com,https://www.example.com
XEETAPUS_RATE_LIMIT_REQUESTS=100
XEETAPUS_RATE_LIMIT_WINDOW=60
XEETAPUS_MAX_REQUEST_SIZE=10485760
```

---

## Configuration Validation

### Check Required Variables

```bash
# Verify secrets are set
grep -E "XEETAPUS_(JWT|CSRF)_SECRET=" /var/www/xeetapus/.env

# Verify no default secrets
if grep -q "change-this" /var/www/xeetapus/.env; then
    echo "ERROR: Default secrets found!"
    exit1
fi
```

### Test Configuration

```bash
# Start with verbose logging
XEETAPUS_ENV=development /var/www/xeetapus/xeetapus-backend

# Check headers
curl -I https://example.com/api/health

# Verify CORS
curl -H "Origin: https://example.com" -I https://example.com/api/health
```

---

## See Also

- [Getting Started](./getting-started.md) - Initial setup
- [Deployment](./deployment.md) - Production deployment
- [Security](./security.md) - Security configuration