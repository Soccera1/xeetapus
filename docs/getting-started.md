# Getting Started

This guide will help you get Xeetapus up and running in development mode quickly.

## Prerequisites

Before you begin, ensure you have the following installed:

| Requirement | Version | Installation |
|-------------|---------|--------------|
| Zig | 0.14.0+ | [ziglang.org](https://ziglang.org/) |
| SQLite3 | Any recent version | Package manager |
| Node.js | 18+ | [nodejs.org](https://nodejs.org/) |
| npm | 9+ | Comes with Node.js |
| Just | Optional | [github.com/casey/just](https://github.com/casey/just) |

### Installing Prerequisites

**Linux (Debian/Ubuntu):**
```bash
# Install SQLite3
sudo apt install sqlite3 libsqlite3-dev

# Install Just (optional but recommended)
cargo install just
# or
sudo apt install just
```

**Linux (Arch):**
```bash
sudo pacman -S sqlite just
```

**macOS:**
```bash
brew install sqlite just
```

## Quick Start

### 11. Clone the Repository

```bash
git clone <repository-url>
cd xeetapus
```

### 2. Configure Environment

**Backend Configuration:**
```bash
cd backend
cp .env.example .env
```

Edit `backend/.env` and set required values:
```bash
# Required: Generate strong secrets
XEETAPUS_JWT_SECRET=$(openssl rand -base64 64)
XEETAPUS_CSRF_SECRET=$(openssl rand -base64 32)
```

**Frontend Configuration:**
```bash
cd ../frontend
cp .env.example .env
```

### 3. Install Dependencies

**Backend:**
```bash
cd backend
zig build
```

**Frontend:**
```bash
cd frontend
npm install
```

### 4. Run the Application

**Using Just (Recommended):**
```bash
# From project root
just dev
```

**Manual:**
```bash
# Terminal 1: Start backend
cd backend
source .env && ./zig-out/bin/xeetapus-backend

# Terminal 2: Start frontend
cd frontend
npm run dev
```

### 5. Access the Application

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080/api
- **Health Check**: http://localhost:8080/api/health

## Development Mode

Development mode provides:

- Hot reload for frontend changes
- Debug logging
- Relaxed CORS for local development
- Source maps for debugging

### Development Commands (Just)

| Command | Description |
|---------|-------------|
| `just dev` | Start both backend and frontend in dev mode |
| `just run` | Start in production mode |
| `just build` | Build both backend and frontend |
| `just build-backend` | Build Zig backend only |
| `just build-frontend` | Build React frontend only |
| `just stop` | Stop all running processes |
| `just clean` | Remove build artifacts |

### Development Commands (Manual)

**Backend:**
```bash
cd backend
zig build run    # Build and run
zig build test    # Run tests
```

**Frontend:**
```bash
cd frontend
npm run dev       # Development server with hot reload
npm run build     # Production build
npm run test      # Run tests
npm run preview   # Preview production build
```

## Environment Variables

### Required Variables

These must be set before running:
```bash
XEETAPUS_JWT_SECRET=      # JWT signing secret (64+ characters)
XEETAPUS_CSRF_SECRET=     # CSRF token secret (32+ characters)
```

Generate secrets:
```bash
# JWT Secret
openssl rand -base64 64

# CSRF Secret
openssl rand -base64 32
```

### Optional Variables

See [Configuration Reference](./configuration.md) for all options.

## Database

Xeetapus uses SQLite and automatically creates the database file on first run. Migrations are applied automatically.

**Database Location**: `backend/xeetapus.db` (configurable via `XEETAPUS_DB_PATH`)

### Database Management

```bash
# View database
sqlite3 backend/xeetapus.db

# Backup database
cp backend/xeetapus.db backend/xeetapus.db.backup

# Reset database
rm backend/xeetapus.db
# Restart server to recreate
```

## Troubleshooting

### Port Already in Use

```bash
# Find process using port8080
lsof -i:8080

# Kill process
kill -9 <PID>

# Or use Just to stop
just stop
```

### Build Errors

**Backend:**
```bash
# Clean and rebuild
rm -rf backend/zig-out backend/.zig-cache
cd backend && zig build
```

**Frontend:**
```bash
# Clean and reinstall
rm -rf frontend/node_modules frontend/package-lock.json
cd frontend && npm install
```

### SQLite Linking Errors

Ensure SQLite development libraries are installed:
```bash
# Debian/Ubuntu
sudo apt install libsqlite3-dev

# Arch
sudo pacman -S sqlite

# macOS
brew install sqlite
```

### Zig Version Issues

Xeetapus requires Zig 0.14.0 or later:
```bash
zig version
```

If your version is older, upgrade Zig.

## Next Steps

- Read [Architecture Overview](./architecture.md)
- Explore [API Reference](./api-reference.md)
- Learn about [Security Features](./security.md)
- Set up [Production Deployment](./deployment.md)