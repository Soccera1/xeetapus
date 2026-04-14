# Xeetapus

A fully functional clone of X (Twitter) built with Zig backend and React frontend. Now production-ready with comprehensive security features.

## Features

- **User Authentication**: Secure register, login, and logout with JWT tokens
- **Posts (Xeets)**: Create, delete, and view posts (280 character limit)
- **Timeline**: View posts from users you follow
- **Explore**: Discover popular posts
- **Likes**: Like and unlike posts
- **Comments**: Comment on posts
- **Follow System**: Follow and unfollow users
- **User Profiles**: View user profiles with stats
- **Reposts**: Repost and quote posts
- **Bookmarks**: Save posts for later
- **Notifications**: Get notified about likes, follows, and mentions
- **Search**: Search users and posts
- **Communities**: Join and participate in topic-based communities
- **Direct Messages**: Private messaging between users
- **Lists**: Create custom lists of users
- **Hashtags**: Trending topics and hashtag search
- **Polls**: Create and vote on polls
- **Blocks & Mutes**: Control who can interact with you
- **Drafts**: Save unfinished posts
- **Scheduled Posts**: Schedule posts for later
- **Analytics**: View post engagement statistics
- **AI Chat**: Configure per-provider LLM settings and chat with models
- **Pinned Posts**: Pin important posts to your profile
- **Monero Payments**: Accept Monero (XMR) payments

## Security Features

Xeetapus implements comprehensive security measures following OWASP guidelines:

- **Secure Authentication**: Argon2id password hashing, JWT with HMAC-SHA256, `auth_token` httpOnly cookies
- **Session Management**: `auth_token` cookie with SameSite=Lax protection
- **Rate Limiting**: Configurable rate limits (default: 100 req/min) with proper headers
- **CSRF Protection**: CSRF tokens for all state-changing operations
- **CORS Security**: Whitelist-based CORS (no wildcards)
- **Security Headers**: CSP, HSTS, X-Frame-Options, X-Content-Type-Options, and more
- **Input Validation**: Username, email, and password validation; XSS sanitization
- **Path Traversal Protection**: Canonical path validation
- **Request Limits**: Configurable request size limits (default: 10MB)
- **Audit Logging**: Security event tracking
- **SQL Injection Prevention**: Parameterized queries throughout

See [SECURITY.md](SECURITY.md) for detailed security documentation.

## Tech Stack

### Backend (Zig)
- Custom HTTP server with security hardening
- SQLite database with 20+ tables
- RESTful API with comprehensive security
- Environment-based configuration
- Port: 8080 (configurable)

### Frontend (React + TypeScript)
- React 18 with hooks
- React Router for navigation
- Vite for build tooling
- Tailwind CSS for styling
- Radix UI for accessible components
- Lucide React for icons
- Port: 3000 (development)

## Project Structure

```
xeetapus/
├── backend/
│   ├── src/
│   │   ├── main.zig           # Entry point & route registration
│   │   ├── http.zig           # HTTP server with security headers
│   │   ├── config.zig         # Environment configuration
│   │   ├── db.zig             # Database module & migrations
│   │   ├── auth.zig           # Authentication with secure tokens
│   │   ├── security.zig       # Security module exports
│   │   ├── password.zig       # Secure password hashing
│   │   ├── tokens.zig         # JWT token generation/verification
│   │   ├── ratelimit.zig      # Rate limiting implementation
│   │   ├── validation.zig     # Input validation
│   │   ├── audit.zig          # Security audit logging
│   │   ├── posts.zig          # Post handlers
│   │   ├── users.zig          # User handlers
│   │   ├── timeline.zig       # Timeline handlers
│   │   ├── notifications.zig  # Notification system
│   │   ├── search.zig         # Search functionality
│   │   ├── communities.zig    # Community features
│   │   ├── messages.zig       # Direct messages
│   │   ├── lists.zig          # User lists
│   │   ├── hashtags.zig       # Hashtag tracking
│   │   ├── polls.zig          # Poll creation & voting
│   │   ├── blocks.zig         # Block/mute functionality
│   │   ├── drafts.zig         # Draft posts
│   │   ├── scheduled.zig      # Scheduled posts
│   │   ├── analytics.zig      # View analytics
│   │   ├── json.zig           # JSON utilities
│   │   └── routes.zig         # Route utilities
│   ├── build.zig              # Zig build configuration
│   ├── .env.example           # Environment variables template
│   └── xeetapus.db            # SQLite database
├── frontend/
│   ├── src/                   # React source code
│   ├── dist/                  # Built files (production)
│   ├── package.json           # Bun package manifest
│   ├── vite.config.ts         # Vite configuration
│   └── .env.example           # Environment variables template
├── justfile                   # Task runner commands
├── SECURITY.md                # Security documentation
├── LICENSE                    # AGPL3+ License
└── README.md
```

## Prerequisites

- Zig 0.14.0 or later
- SQLite3 (development library)
- Bun 1.2+ for the frontend toolchain
- A C compiler (for Zig SQLite bindings)
- [Just](https://github.com/casey/just) task runner (recommended)

## Installation

### 1. Clone and Setup

```bash
git clone <repository-url>
cd xeetapus
```

### 2. Configure Environment

**Backend:**
```bash
cd backend
cp .env.example .env
# Edit .env with your configuration (see Configuration section)
```

**Frontend:**
```bash
cd frontend
cp .env.example .env
# Edit .env with your API URL
```

### 3. Build

**Using Just (Recommended):**
```bash
# Install Just first: https://github.com/casey/just

# Build everything
just build

# Or build individually
just build-backend
just build-frontend
```

**Manual Installation:**

**Backend:**
```bash
cd backend
zig build
```

**Frontend:**
```bash
cd frontend
bun install
bun run build
```

## Configuration

### Required Environment Variables

Create a `.env` file in the `backend/` directory:

```bash
# Required: Generate with: openssl rand -base64 64
XEETAPUS_JWT_SECRET=your-64-character-secret-here

# Required: Generate with: openssl rand -base64 32
XEETAPUS_CSRF_SECRET=your-32-character-secret-here
```

### Optional Environment Variables

```bash
# Environment (development/staging/production)
XEETAPUS_ENV=development

# Server port
XEETAPUS_PORT=8080

# Database path
XEETAPUS_DB_PATH=xeetapus.db

# Media storage directory
XEETAPUS_MEDIA_PATH=/var/www/xeetapus/media

# CORS allowed origins (comma-separated)
XEETAPUS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

# Request binding address
XEETAPUS_BIND_ADDR=0.0.0.0

# Password hashing parameters (Argon2id)
XEETAPUS_ARGON2_TIME_COST=3
XEETAPUS_ARGON2_MEMORY_COST=65536
XEETAPUS_ARGON2_PARALLELISM=4

# Maximum request size in bytes (default: 10MB)
XEETAPUS_MAX_REQUEST_SIZE=10485760

# Rate limiting
XEETAPUS_RATE_LIMIT_REQUESTS=100
XEETAPUS_RATE_LIMIT_WINDOW=60

# Authentication rate limiting
XEETAPUS_AUTH_RATE_LIMIT_REQUESTS=5
XEETAPUS_AUTH_RATE_LIMIT_WINDOW=300

# Monero Configuration
# Required for payment functionality
XEETAPUS_MONERO_ADDRESS=your-monero-wallet-address

# Monero daemon RPC URL (for fee estimates, defaults to http://localhost:18081)
XEETAPUS_MONEROD_URL=http://localhost:18081
```

### Frontend Configuration

```bash
# API URL
VITE_API_URL=http://localhost:8080/api
```

## Running the Application

### Using Just (Recommended)

```bash
# Development mode (hot reload)
just dev

# Production mode
just run

# Backend only
just run-backend

# Frontend only
just run-frontend

# Stop all services
just stop

# Clean build artifacts
just clean
```

### Manual

**Start the Backend:**
```bash
cd backend
zig build run
# Server starts on port 8080
```

**Start the Frontend (Development):**
```bash
cd frontend
bun run dev
# Frontend on port 3000
```

**Build Frontend for Production:**
```bash
cd frontend
bun run build
# Serves static files from backend on port 8080
```

## Production Deployment

### Pre-Deployment Checklist

1. **Set Strong Secrets:**
   ```bash
   # Generate secrets
   openssl rand -base64 64  # JWT_SECRET
   openssl rand -base64 32  # CSRF_SECRET
   ```

2. **Environment Configuration:**
   ```bash
   XEETAPUS_ENV=production
   XEETAPUS_ALLOWED_ORIGINS=https://yourdomain.com
   XEETAPUS_JWT_SECRET=<strong-secret>
   XEETAPUS_CSRF_SECRET=<strong-secret>
   ```

3. **Enable HTTPS:**
   - Use a valid SSL certificate
   - Set up reverse proxy (nginx, Caddy, or Traefik)
   - Configure HSTS headers

4. **Database Security:**
   ```bash
   chmod 600 /path/to/xeetapus.db
   ```

5. **File Permissions:**
   ```bash
   # Ensure proper ownership
   chown -R www-data:www-data /path/to/xeetapus
   ```

### Docker Deployment (Example)

```dockerfile
# Dockerfile
FROM alpine:latest
RUN apk add --no-cache sqlite-dev
COPY backend/zig-out/bin/xeetapus-backend /app/
COPY frontend/dist /app/public
WORKDIR /app
ENV XEETAPUS_ENV=production
ENV XEETAPUS_PORT=8080
EXPOSE 8080
CMD ["./xeetapus-backend"]
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout (clears cookies)
- `GET /api/auth/me` - Get current user

### Posts
- `GET /api/posts` - List posts (with pagination)
- `POST /api/posts` - Create a new post
- `GET /api/posts/:id` - Get a specific post
- `DELETE /api/posts/:id` - Delete a post
- `POST /api/posts/:id/like` - Like a post
- `DELETE /api/posts/:id/like` - Unlike a post
- `POST /api/posts/:id/repost` - Repost a post
- `DELETE /api/posts/:id/repost` - Undo repost
- `POST /api/posts/:id/bookmark` - Bookmark a post
- `DELETE /api/posts/:id/bookmark` - Remove bookmark
- `POST /api/posts/:id/comment` - Comment on a post
- `GET /api/posts/:id/comments` - Get post comments
- `POST /api/posts/:id/pin` - Pin a post to profile
- `DELETE /api/posts/:id/pin` - Unpin a post
- `POST /api/posts/:id/view` - Record a post view (analytics)

### Users
- `GET /api/users/:username` - Get user profile
- `GET /api/users/:username/posts` - Get user's posts
- `GET /api/users/:username/replies` - Get user's replies
- `GET /api/users/:username/media` - Get user's media posts
- `POST /api/users/:username/follow` - Follow a user
- `DELETE /api/users/:username/follow` - Unfollow a user
- `GET /api/users/:username/followers` - Get followers list
- `GET /api/users/:username/following` - Get following list
- `POST /api/users/:username/block` - Block a user
- `DELETE /api/users/:username/block` - Unblock a user
- `POST /api/users/:username/mute` - Mute a user
- `DELETE /api/users/:username/mute` - Unmute a user

### Timeline
- `GET /api/timeline` - Get personal timeline
- `GET /api/timeline/explore` - Get explore feed

### Notifications
- `GET /api/notifications` - List notifications
- `POST /api/notifications/:id/read` - Mark notification as read
- `POST /api/notifications/read-all` - Mark all as read
- `GET /api/notifications/unread-count` - Get unread count

### Search
- `GET /api/search/users?q=query` - Search users
- `GET /api/search/posts?q=query` - Search posts

### AI / LLM
- `GET /api/llm/providers` - List supported LLM providers
- `GET /api/llm/configs` - Get saved provider settings
- `PUT /api/llm/configs/:provider` - Save provider settings
- `DELETE /api/llm/configs/:provider` - Remove provider settings
- `POST /api/llm/configs/:provider/reveal` - Reveal a saved API key
- `POST /api/llm/chat` - Chat with a configured provider

### Communities
- `GET /api/communities` - List communities
- `POST /api/communities` - Create a community
- `GET /api/communities/:id` - Get community details
- `POST /api/communities/:id/join` - Join a community
- `DELETE /api/communities/:id/join` - Leave a community
- `GET /api/communities/:id/posts` - Get community posts
- `POST /api/communities/:id/posts` - Post in community
- `GET /api/communities/:id/members` - Get members list

### Direct Messages
- `GET /api/messages/conversations` - List conversations
- `POST /api/messages/conversations` - Start a conversation
- `GET /api/messages/conversations/:id` - Get messages
- `POST /api/messages/conversations/:id` - Send a message
- `GET /api/messages/unread-count` - Get unread count

### Lists
- `GET /api/lists` - Get my lists
- `POST /api/lists` - Create a list
- `GET /api/lists/:id` - Get list details
- `DELETE /api/lists/:id` - Delete a list
- `POST /api/lists/:id/members` - Add member to list
- `DELETE /api/lists/:id/members/:user_id` - Remove member
- `GET /api/lists/:id/timeline` - Get list timeline

### Hashtags
- `GET /api/hashtags/trending` - Get trending hashtags
- `GET /api/hashtags/:tag/posts` - Get posts by hashtag

### Polls
- `POST /api/polls/:id/vote` - Vote on a poll
- `GET /api/polls/:id/results` - Get poll results

### Blocks & Mutes
- `GET /api/blocks` - Get blocked users
- `GET /api/mutes` - Get muted users

### Drafts
- `GET /api/drafts` - Get drafts
- `POST /api/drafts` - Create a draft
- `PUT /api/drafts/:id` - Update a draft
- `DELETE /api/drafts/:id` - Delete a draft

### Scheduled Posts
- `GET /api/scheduled` - Get scheduled posts
- `POST /api/scheduled` - Schedule a post
- `DELETE /api/scheduled/:id` - Cancel scheduled post

### Analytics
- `GET /api/analytics/posts/:id/views` - Get post view count
- `GET /api/analytics/me` - Get user analytics

### Payments (Monero)
- `POST /api/payments/invoices` - Create a Monero payment request
  - Option 1 - Fixed XMR amount (no exchange rate needed):
    ```json
    {"xmr_amount": 0.5, "priority": "normal"}
    ```
  - Option 2 - Fiat amount (requires exchange rate):
    ```json
    {"amount": 10.00, "currency": "USD", "priority": "normal"}
    ```
  - Priority options: `slow` (~90min), `normal` (~30min), `fast` (~10min), `fastest` (~5min)
  - Network fee is automatically added based on current Monero network conditions
- `GET /api/payments/invoices/:id` - Check payment status
- `GET /api/payments/invoices` - List user's invoices
- `GET /api/payments/balance` - Get user's balance
- `POST /api/payments/pay` - Pay a Monero invoice
- `GET /api/payments/rate` - Get current XMR/USD exchange rate and network fee estimates (cached for 2hours)

### Health
- `GET /api/health` - Health check endpoint

## Database Schema

The application uses SQLite with the following tables:

- **users** - User accounts with profile info and secure password hashes
- **posts** - User posts (xeets) with optional media
- **likes** - Post likes
- **follows** - User follow relationships
- **comments** - Post comments
- **reposts** - Repost records
- **bookmarks** - Saved posts
- **notifications** - User notifications
- **communities** - Topic-based communities
- **community_members** - Community memberships
- **community_posts** - Posts linked to communities
- **conversations** - DM conversation threads
- **conversation_participants** - DM participants
- **messages** - Direct messages
- **user_lists** - Custom user lists
- **list_members** - List memberships
- **hashtags** - Trending hashtags
- **post_hashtags** - Post hashtag relationships
- **polls** - Polls attached to posts
- **poll_options** - Poll answer options
- **poll_votes** - User votes on polls
- **quote_posts** - Quote post records
- **post_views** - View analytics
- **blocks** - User blocks
- **mutes** - User mutes
- **drafts** - Unpublished drafts
- **scheduled_posts** - Posts scheduled for future
- **pinned_posts** - User's pinned posts
- **invoices** - Monero payment invoices
- **payments** - Monero payment records

## Development

### Backend Development

The backend uses Zig's built-in build system:

```bash
cd backend
zig build              # Build the project
zig build run          # Build and run
zig build test         # Run tests
```

### Frontend Development

The frontend uses Vite and Bun for fast development:

```bash
cd frontend
bun install            # Install dependencies
bun run dev            # Start dev server with hot reload
bun run build          # Build for production
bun run preview        # Preview production build
bun run test           # Run tests
```

### Code Style

- **Zig**: Follow official Zig style guide
- **TypeScript/React**: Use ESLint and Prettier configurations
- **Security**: Run security scans before commits

## Security

Xeetapus has been hardened for production use with comprehensive security measures. Key highlights:

- ✅ No hardcoded secrets
- ✅ Secure password hashing (Argon2id)
- ✅ JWT with HMAC-SHA256 signatures
- ✅ httpOnly cookies with SameSite protection
- ✅ CSRF protection
- ✅ Rate limiting
- ✅ CORS whitelist
- ✅ Security headers (CSP, HSTS, etc.)
- ✅ Input validation and sanitization
- ✅ Path traversal protection
- ✅ SQL injection prevention
- ✅ Audit logging

For complete security documentation, see [SECURITY.md](SECURITY.md) and the Security Implementation chapter in the manual.

## Testing Security

Verify security features:

```bash
# 1. Test rate limiting (101st request should return 429)
for i in {1..101}; do
  curl -s http://localhost:8080/api/health > /dev/null
done

# 2. Test path traversal (should return 403)
curl http://localhost:8080/../../../etc/passwd

# 3. Check security headers
curl -I http://localhost:8080/api/health

# 4. Test with weak password (should fail)
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"123"}'
```

## Troubleshooting

### Build Issues

**Backend:**
```bash
# Clean build
rm -rf backend/.zig-cache backend/zig-out
zig build

# Check Zig version
zig version  # Should be 0.14.0+
```

**Frontend:**
```bash
# Clean install
rm -rf frontend/node_modules frontend/bun.lock
cd frontend && bun install
```

### Runtime Issues

**Database:**
- Ensure SQLite3 is installed
- Check database file permissions
- Verify database path in configuration

**Environment:**
- Verify all required environment variables are set
- Check `.env` file exists in backend directory
- Ensure JWT_SECRET is at least 32 characters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

AGPL3+ - See LICENSE file for details

## Acknowledgments

- Built with [Zig](https://ziglang.org/)
- Frontend powered by [React](https://reactjs.org/)
- UI components from [Radix UI](https://www.radix-ui.com/)
- Icons from [Lucide](https://lucide.dev/)

## Support

For issues and feature requests, please use the GitHub issue tracker.

For security issues, please see [SECURITY.md](SECURITY.md) for responsible disclosure guidelines.
