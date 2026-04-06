# Deployment Guide

This guide covers production deployment of Xeetapus.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Production Build](#production-build)
- [Server Setup](#server-setup)
- [Nginx Configuration](#nginx-configuration)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Process Management](#process-management)
- [Environment Configuration](#environment-configuration)
- [Database Management](#database-management)
- [Monitoring](#monitoring)
- [Backup Strategy](#backup-strategy)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Server Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 512 MB | 1+ GB |
| Storage | 1 GB | 10+ GB |
| OS | Linux | Ubuntu22.04/Debian 12 |

### Software Requirements

- Linux server (Ubuntu/Debian recommended)
- SQLite3
- Nginx or Caddy (reverse proxy)
- SSL certificate (Let's Encrypt recommended)
- systemd or OpenRC (process management)

---

## Production Build

### Build Backend

```bash
cd backend

# Set production environment
export XEETAPUS_ENV=production

# Build release binary
zig build -Doptimize=ReleaseFast

# Binary location
ls zig-out/bin/xeetapus-backend
```

### Build Frontend

```bash
cd frontend

# Install dependencies
npm install

# Production build
npm run build

# Output location
ls dist/
```

### Build Summary

```bash
# Using Just
just build

# Output:
# - backend/zig-out/bin/xeetapus-backend
# - frontend/dist/
```

---

## Server Setup

### 1. Create Directories

```bash
# Create directories
sudo mkdir -p /var/www/xeetapus
sudo mkdir -p /var/www/xeetapus/media
sudo mkdir -p /var/log

# Set ownership (nginx user as per OpenRC script)
sudo chown -R nginx:nginx /var/www/xeetapus
sudo touch /var/log/xeetapus.log
sudo chown nginx:nginx /var/log/xeetapus.log
```

### 2. Copy Files

```bash
# Copy backend binary
sudo cp backend/zig-out/bin/xeetapus-backend /var/www/xeetapus/

# Copy frontend build
sudo cp -r frontend/dist /var/www/xeetapus/

# Copy media directory (for uploads)
sudo mkdir -p /var/www/xeetapus/media
sudo chown -R nginx:nginx /var/www/xeetapus/media
```

### 3. Set Permissions

```bash
# Set ownership
sudo chown -R nginx:nginx /var/www/xeetapus

# Set permissions
sudo chmod 750 /var/www/xeetapus
sudo chmod 600 /var/www/xeetapus/.env
```

### 2. Copy Files

```bash
# Copy backend binary
sudo cp backend/zig-out/bin/xeetapus-backend /var/www/xeetapus/

# Copy frontend build
sudo cp -r frontend/dist /var/www/xeetapus/

# Copy media directory (for uploads)
sudo mkdir -p /var/www/xeetapus/media
sudo chown -R xeetapus:xeetapus /var/www/xeetapus/media
```

### 3. Set Permissions

```bash
# Set ownership
sudo chown -R xeetapus:xeetapus /var/www/xeetapus
sudo chown -R xeetapus:xeetapus /var/log/xeetapus

# Set permissions
sudo chmod 750 /var/www/xeetapus
sudo chmod 750 /var/log/xeetapus
sudo chmod 600 /var/www/xeetapus/.env
```

---

## Nginx Configuration

### Basic Configuration

**File**: `/etc/nginx/sites-available/xeetapus`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Security headers (additional to application headers)
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Upload size
    client_max_body_size 10M;

    # API proxy
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 90s;
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;
    }

    # Media files proxy
    location /media {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files (frontend)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Enable Site

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/xeetapus /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## SSL/TLS Configuration

### Let's Encrypt (Certbot)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d example.com -d www.example.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

### Manual Certificate

```bash
# Place certificates
sudo mkdir -p /etc/nginx/ssl
sudo cp your-cert.pem /etc/nginx/ssl/
sudo cp your-key.pem /etc/nginx/ssl/

# Set permissions
sudo chmod 600 /etc/nginx/ssl/your-key.pem
```

### Generate Self-Signed (Development Only)

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt

# WARNING: Only use for development!
```

---

## Process Management

### Using OpenRC

**File**: `/etc/init.d/xeetapus`

Copy the provided init script:

```bash
sudo cp deploy/openrc/xeetapus /etc/init.d/xeetapus
sudo chmod +x /etc/init.d/xeetapus
```

### Manage Service

```bash
# Add to default runlevel
sudo rc-update add xeetapus default

# Start service
sudo rc-service xeetapus start

# Stop service
sudo rc-service xeetapus stop

# Restart service
sudo rc-service xeetapus restart

# Check status
sudo rc-service xeetapus status

# View logs
sudo tail -f /var/log/xeetapus.log
```

### Configuration

The OpenRC script can be configured via `/etc/conf.d/xeetapus`:

```bash
# /etc/conf.d/xeetapus
XEETAPUS_USER=nginx
XEETAPUS_GROUP=nginx
XEETAPUS_DIR=/var/www/xeetapus
XEETAPUS_LOG=/var/log/xeetapus.log
```

### Environment File

The service loads environment variables from `/var/www/xeetapus/.env` automatically.

---

## Environment Configuration

### Production Environment File

**File**: `/var/www/xeetapus/.env`

```bash
# Environment
XEETAPUS_ENV=production

# Secrets (generate with: openssl rand -base64 64)
XEETAPUS_JWT_SECRET=your-secure-jwt-secret-here-minimum-64-characters
XEETAPUS_CSRF_SECRET=your-secure-csrf-secret-here

# Server
XEETAPUS_PORT=8080

# Database
XEETAPUS_DB_PATH=/var/www/xeetapus/xeetapus.db

# Media
XEETAPUS_MEDIA_PATH=/var/www/xeetapus/media

# CORS (comma-separated)
XEETAPUS_ALLOWED_ORIGINS=https://example.com,https://www.example.com

# Rate Limiting
XEETAPUS_RATE_LIMIT_REQUESTS=100
XEETAPUS_RATE_LIMIT_WINDOW=60

# Password Hashing
XEETAPUS_BCRYPT_COST=12

# Request Limits
XEETAPUS_MAX_REQUEST_SIZE=10485760

# Monero (optional)
XEETAPUS_MONERO_ADDRESS=your-monero-wallet-address
XEETAPUS_MONEROD_URL=http://localhost:18081
```

### Generate Secrets

```bash
# JWT Secret (64+ characters)
openssl rand -base64 64

# CSRF Secret (32+ characters)
openssl rand -base64 32
```

---

## Database Management

### Database Location

Default: `/var/www/xeetapus/xeetapus.db`

### Backup

```bash
# Manual backup
sqlite3 /var/www/xeetapus/xeetapus.db ".backup '/var/backups/xeetapus-$(date +%Y%m%d).db'"

# Automated backup (cron)
crontab -e

# Add daily backup at 2 AM
0 2 * * * sqlite3 /var/www/xeetapus/xeetapus.db ".backup '/var/backups/xeetapus-$(date +\%Y\%m\%d).db'"
```

### Restore

```bash
# Stop service
sudo systemctl stop xeetapus

# Restore database
cp /var/backups/xeetapus-20240115.db /var/www/xeetapus/xeetapus.db

# Start service
sudo systemctl start xeetapus
```

### Maintenance

```bash
# Optimize database
sqlite3 /var/www/xeetapus/xeetapus.db "VACUUM;"

# Check integrity
sqlite3 /var/www/xeetapus/xeetapus.db "PRAGMA integrity_check;"

# Analyze for query optimization
sqlite3 /var/www/xeetapus/xeetapus.db "ANALYZE;"
```

---

## Monitoring

### Log Files

- **Application**: `/var/log/xeetapus/app.log`
- **Errors**: `/var/log/xeetapus/error.log`
- **Audit**: `/var/log/xeetapus.log`

### Log Rotation

**File**: `/etc/logrotate.d/xeetapus`

```
/var/log/xeetapus.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 xeetapus xeetapus
    missingok
}

/var/log/xeetapus/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 xeetapus xeetapus
    missingok
}
```

### Health Monitoring

```bash
# Simple health check script
#!/bin/bash
# /usr/local/bin/xeetapus-health

ENDPOINT="http://localhost:8080/api/health"

if curl -sf "$ENDPOINT" > /dev/null; then
    echo "Xeetapus is healthy"
    exit 0
else
    echo "Xeetapus is unhealthy"
    exit 1
fi
```

### System Monitoring

```bash
# CPU usage
top -p $(pgrep xeetapus-backend)

# Memory usage
ps -o rss,command -p $(pgrep xeetapus-backend)

# Disk usage
df -h /var/www/xeetapus

# Database size
ls -lh /var/www/xeetapus/xeetapus.db
```

---

## Backup Strategy

### Automated Backups

```bash
#!/bin/bash
# /usr/local/bin/xeetapus-backup

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/xeetapus"
SOURCE_DIR="/var/www/xeetapus"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
sqlite3 "$SOURCE_DIR/xeetapus.db" ".backup '$BACKUP_DIR/db_$DATE.db'"

# Backup .env
cp "$SOURCE_DIR/.env" "$BACKUP_DIR/env_$DATE"

# Backup media (if any)
tar -czf "$BACKUP_DIR/media_$DATE.tar.gz" -C "$SOURCE_DIR" media/

# Remove old backups (keep 30 days)
find "$BACKUP_DIR" -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

### Cron Schedule

```bash
# Daily backups at 2 AM
0 2 * * * /usr/local/bin/xeetapus-backup
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo tail -f /var/log/xeetapus.log

# Check configuration
sudo -u nginx cat /var/www/xeetapus/.env

# Check permissions
ls -la /var/www/xeetapus/

# Test binary manually
sudo -u nginx /var/www/xeetapus/xeetapus-backend
```

### Database Errors

```bash
# Check database integrity
sqlite3 /var/www/xeetapus/xeetapus.db "PRAGMA integrity_check;"

# Fix corruption
sqlite3 /var/www/xeetapus/xeetapus.db ".recover" > /tmp/recovered.sql
sqlite3 /var/www/xeetapus/xeetapus_new.db < /tmp/recovered.sql
```

### Connection Issues

```bash
# Check if service is running
sudo rc-service xeetapus status

# Check port
sudo netstat -tlnp | grep 8080

# Test API directly
curl http://localhost:8080/api/health
```

### Performance Issues

```bash
# Check resource usage
top -p $(pgrep xeetapus-backend)

# Optimize database
sqlite3 /var/www/xeetapus/xeetapus.db "VACUUM;"

# Check logs for errors
sudo tail -f /var/log/xeetapus.log
```

---

## Security Checklist

- [ ] Generate strong JWT and CSRF secrets
- [ ] Configure HTTPS with valid certificate
- [ ] Set proper file permissions
- [ ] Configure firewall
- [ ] Enable rate limiting
- [ ] Set up audit logging
- [ ] Configure CORS whitelist
- [ ] Enable HSTS headers
- [ ] Set up automated backups
- [ ] Configure log rotation
- [ ] Remove development files
- [ ] Disable directory listing
- [ ] Set up monitoring

---

## Upgrade Procedure

```bash
# 1. Backup
sudo /usr/local/bin/xeetapus-backup

# 2. Stop service
sudo rc-service xeetapus stop

# 3. Update code
git pull origin main

# 4. Rebuild
just build
# or manually:
cd backend && zig build -Doptimize=ReleaseFast
cd ../frontend && npm install && npm run build

# 5. Deploy
sudo cp backend/zig-out/bin/xeetapus-backend /var/www/xeetapus/
sudo cp -r frontend/dist/* /var/www/xeetapus/

# 6. Start service
sudo rc-service xeetapus start

# 7. Verify
sudo rc-service xeetapus status
curl https://example.com/api/health
```

---

## Additional Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [systemd Documentation](https://systemd.io/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)