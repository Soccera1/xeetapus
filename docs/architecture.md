# System Architecture

This document describes the architecture, design decisions, and implementation details of Xeetapus.

## Overview

Xeetapus is a social media platform built with a clear separation between backend and frontend:

```
┌─────────────────────────────────────────────────────────────┐
│                     USER BROWSER                              │├─────────────────────────────────────────────────────────────┤
│  React Frontend (Port 3000dev, served by backend in prod)   │
│┌───────────────────────────────────────────────────────────┐ │
││  Components│ │
││  Pages      │ │
││  Context│ │
││  API Client│ │
││  Utilities  │ │
│└───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ││ HTTP/REST API
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Zig Backend (Port 8080)                     │
├─────────────────────────────────────────────────────────────┤
│┌───────────────────────────────────────────────────────────┐ │
││                     HTTP Server│ │
││  ┌─────────────┐  ┌─────────────┐  ┌────────────────────┐ │ │
││  │ Router      │  │ Middleware │  │ Static File Server │ │ │
││  │ (Routing)   │  │ (Security)  │  │ (SPA Support)      │ │ │
││  └─────────────┘  └─────────────┘  └────────────────────┘ │ │
│└───────────────────────────────────────────────────────────┘ │
││┌───────────────────────────────────────────────────────────┐ │
││  │                    Route Handlers                       │ │
││  ├─────────────────────────────────────────────────────────┤ │
││  │  auth.zig   │ posts.zig    │ users.zig │ timeline.zig │ │
││  │  search.zig │ messages.zig │ lists.zig │ hashtags.zig │ │
││  │  polls.zig  │ blocks.zig   │ drafts.zig│ llm.zig       │ │
││  │  payments.zig│ communities.zig│ notifications.zig│...   │ │
││  └───────────────────────────────────────────────────────────┘ │
│└───────────────────────────────────────────────────────────┘ │
│                              │
│                              ▼
│┌─────────────────┐  ┌────────────────┐  ┌─────────────────┐ │
││ config.zig      │  │ db.zig         │  │security.zig    │ │
││ (Configuration) │  │ (SQLite)       │  │ (Auth/Security) │ │
│└─────────────────┘  └────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   SQLite Database                            │
│                   (xeetapus.db)                               │
└─────────────────────────────────────────────────────────────┘
```

## Backend Architecture

### Entry Point

**File**: `backend/src/main.zig`

The entry point:
1. Initializes configuration from environment variables
2. Sets up SQLite database connection
3. Runs database migrations
4. Initializes audit logging
5. Initializes payment system (Monero)
6. Creates HTTP server
7. Registers all API routes
8. Starts listening for connections

### Module Structure

| Module | File | Purpose |
|--------|------|---------|
| HTTP Server | `http.zig` | Custom HTTP server implementation |
| Config | `config.zig` | Environment configuration management |
| Database | `db.zig` | SQLite connection and migrations |
| Auth | `auth.zig` | Authentication and user management |
| Security | `security.zig` | Security module exports |
| Password | `password.zig` | Password hashing (PBKDF2-inspired) |
| Tokens | `tokens.zig` | JWT token generation and verification |
| Rate Limit | `ratelimit.zig` | Request rate limiting |
| Validation | `validation.zig` | Input validation and sanitization |
| Audit | `audit.zig` | Security audit logging |
| Posts | `posts.zig` | Post CRUD and interactions |
| Users | `users.zig` | User profiles and follow system |
| Timeline | `timeline.zig` | Feed generation |
| Notifications | `notifications.zig` | Notification system |
| Search | `search.zig` | Search functionality |
| Communities | `communities.zig` | Community features |
| Messages | `messages.zig` | Direct messaging |
| Lists | `lists.zig` | User lists |
| Hashtags | `hashtags.zig` | Hashtag tracking |
| Polls | `polls.zig` | Poll system |
| Blocks | `blocks.zig` | Block/mute functionality |
| Drafts | `drafts.zig` | Draft posts |
| Scheduled | `scheduled.zig` | Scheduled posts |
| Analytics | `analytics.zig` | View analytics |
| Media | `media.zig` | Media upload and serving |
| LLM | `llm.zig` | AI chat integration |
| Payments | `payments.zig` | Monero payment processing |
| JSON | `json.zig` | JSON utility functions |

### HTTP Server

**File**: `backend/src/http.zig`

Custom HTTP server implementation with:

- **Request parsing**: Full HTTP/1.1 request parsing
- **Response building**: Structured response generation
- **Routing**: Pattern-based route matching with parameters (`:id`, `*`)
- **Middleware**: Security headers, CORS, rate limiting
- **Static files**: Production SPA serving with security checks

#### Route Types

```zig
// Public routes (no authentication required)
try server.addPublicRoute("GET", "/api/health", healthCheck);

// Protected routes (authentication required)
try server.addRoute("POST", "/api/posts", posts.create);

// Wildcard routes (static file serving)
try server.addPublicRoute("GET", "/*", serveStaticFiles);

// Parameterized routes
try server.addRoute("GET", "/api/users/:username", users.getProfile);
```

### Configuration

**File**: `backend/src/config.zig`

Environment-based configuration with:

- Singleton pattern for global access
- Secure defaults
- Production/development mode detection
- Validation of required values

```zig
pub const Config = struct {
    jwt_secret: []const u8,
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
    csrf_secret: []const u8,
    //...
};
```

### Database

**File**: `backend/src/db.zig`

SQLite database management:

- Connection pooling (single connection per process)
- Automatic migrations on startup
- Parameterized queries for SQL injection prevention
- Transaction support

### Security Modules

**Files**: `backend/src/security.zig`, `password.zig`, `tokens.zig`, `ratelimit.zig`, `validation.zig`, `audit.zig`

Comprehensive security implementation:

| Module | Function |
|--------|----------|
| `password.zig` | PBKDF2-inspired password hashing |
| `tokens.zig` | JWT generation/validation with HMAC-SHA256 |
| `ratelimit.zig` | IP-based request rate limiting |
| `validation.zig` | Input validation and XSS sanitization |
| `audit.zig` | Security event logging |

See [Security Documentation](./security.md) for details.

## Frontend Architecture

### Entry Point

**File**: `frontend/src/main.tsx`

```typescript
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AuthProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AuthProvider>
  </React.StrictMode>
);
```

### Component Structure

```
frontend/src/
├── components/          # Reusable UI components
│   ├── ui/              # Radix UI primitives
│   ├── Navbar.tsx       # Main navigation
│   ├── PostCard.tsx     # Post display component
│   ├── PostComposer.tsx # Post creation form
│   └── LlmChatDialog.tsx # AI chat interface
├── pages/               # Route components
│   ├── AuthPage.tsx     # Login/register
│   ├── TimelinePage.tsx # Main feed
│   ├── ProfilePage.tsx  # User profiles
│   └── ...              # Other pages
├── context/
│   └── AuthContext.tsx  # Authentication state
├── api.ts               # API client
├── types.ts             # TypeScript interfaces
├── App.tsx               # Main app component
├── main.tsx             # Entry point
└── index.css            # Global styles (Tailwind)
```

### State Management

- **React Context**: Authentication state via `AuthContext`
- **Local State**: Component-level state with `useState`
- **URL State**: Navigation state via React Router

### Routing

**File**: `frontend/src/App.tsx`

```typescript
<Routes>
  {/* Public routes */}
  <Route path="/" element={<AuthPage />} />
  
  {/* Protected routes (require authentication) */}
  <Route path="/timeline" element={<PrivateRoute><TimelinePage /></PrivateRoute>} />
  <Route path="/profile/:username" element={<PrivateRoute><ProfilePage /></PrivateRoute>} />
  {/* ... more routes */}
</Routes>
```

### API Client

**File**: `frontend/src/api.ts`

Centralized API client with:

- Automatic credential handling (cookies)
- Error handling and parsing
- TypeScript response typing
- CSRF token management

## Data Flow

### Authentication Flow

```
User Browser            Frontend              Backend
      │                    │                    │
      │  Login Form        │                    │
      │ ──────────────────>│                    │
      │                    │ POST /api/auth/login
      │                    │ ──────────────────>│
      │                    │                    │ Validate credentials
      │                    │                    │ Generate JWT
      │                    │                    │ Create session cookie
      │                    │ Set-Cookie: session │
      │                    │ <─────────────────│
      │                    │ Store auth state   │
      │ Redirect to /timeline                   │
      │ <─────────────────│                    │
      │                    │                    │
      │ Subsequent requests │                    │
      │ ──────────────────>│ Cookie: session     │
      │                    │ ──────────────────>│
      │                    │                    │ Verify JWT
      │                    │   Response         │ Extract user
      │                    │ <─────────────────│
      │                    │                    │
```

### Request Processing Flow

```
HTTP Request
      │
      ▼
┌─────────────────┐
│ Rate Limiting   │──▶ 429 Too Many Requests (if exceeded)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CORS Check     │──▶ 403 Forbidden (iforigin not allowed)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Route Matching │──▶ 404 Not Found (if no match)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Auth Check     │──▶ 401 Unauthorized (if required & missing)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ CSRF Check     │──▶ 403 Forbidden (if state-changing & invalid)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Input Validation│──▶ 400 Bad Request (if invalid)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Route Handler   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Response +      │
│ Security Headers│
└─────────────────┘
```

## Performance Considerations

### Backend

- **SQLite**: Efficient for read-heavy workloads with proper indexing
- **Connection**: Single database connection with efficient query patterns
- **Memory**: Arena allocators for request handling
- **Static Files**: In-memory caching for small files

### Frontend

- **Vite**: Fast HMR in development, optimized bundles in production
- **Code Splitting**: Vendor chunks for React/ReactDOM
- **Lazy Loading**: Route-based code splitting potential
- **Tailwind**: Purged CSS for minimal bundle size

## Scalability

### Current Architecture

- Single-process backend
- SQLite database (single file)
- Vertical scaling preferred

### Scaling Options

1. **Multiple Processes**: Run multiple backend instances behind a load balancer
2. **Database**: Migrate to PostgreSQL for concurrent connections
3. **Caching**: Add Redis for session/rate limiting
4. **CDN**: Serve static assets via CDN

## Development Decisions

### Why Zig for Backend?

- Performance comparable to C
- Memory safety without garbage collection
- Simple deployment (single binary)
- Direct SQLite bindings
- Modern tooling

### Why SQLite?

- Simplicity for development
- Zero configuration
- Single-file database
- Sufficient for moderate traffic
- Easy backup and migration

### Why React + Vite?

- Modern development experience
- Fast HMR
- TypeScript support
- Rich ecosystem
- Tailwind integration

## See Also

- [API Reference](./api-reference.md) - Complete API documentation
- [Database Schema](./database.md) - Database structure
- [Security](./security.md) - Security implementation details