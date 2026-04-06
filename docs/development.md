# Development Guide

This guide covers local development setup, coding standards, and contribution guidelines.

## Development Setup

### Prerequisites

- Zig 0.14.0 or later
- SQLite3 development libraries
- Node.js 18+ and npm
- Git
- Just (task runner) - optional but recommended

### Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd xeetapus

# Install frontend dependencies
cd frontend && npm install && cd ..

# Configure environment
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Edit backend/.env with your settings
# At minimum, set:
# XEETAPUS_JWT_SECRET=<generate with: openssl rand -base64 64>
# XEETAPUS_CSRF_SECRET=<generate with: openssl rand -base64 32>
```

### Running in Development Mode

**Using Just (recommended):**
```bash
# Start both backend and frontend with hot reload
just dev
```

**Manual:**
```bash
# Terminal 1: Backend
cd backend
source .env && zig build run

# Terminal 2: Frontend
cd frontend
npm run dev
```

### Development URLs

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080/api
- **Health Check**: http://localhost:8080/api/health

---

## Project Structure

```
xeetapus/
├── backend/
│   ├── src/
│   │   ├── main.zig          # Entry point
│   │   ├── http.zig          # HTTP server
│   │   ├── config.zig        # Configuration
│   │   ├── db.zig            # Database
│   │   ├── auth.zig          # Authentication
│   │   ├── security.zig      # Security exports
│   │   ├── password.zig      # Password hashing
│   │   ├── tokens.zig        # JWT tokens
│   │   ├── ratelimit.zig     # Rate limiting
│   │   ├── validation.zig    # Input validation
│   │   ├── audit.zig         # Audit logging
│   │   ├── posts.zig         # Posts module
│   │   ├── users.zig         # Users module
│   │   └── ...               # Other modules
│   ├── build.zig             # Build configuration
│   ├── .env.example          # Environment template
│   └── xeetapus.db           # SQLite database
├── frontend/
│   ├── src/
│   │   ├── components/       # Reusable components
│   │   │   └── ui/           # Radix UI components
│   │   ├── pages/            # Route components
│   │   ├── context/          # React context
│   │   ├── api.ts            # API client
│   │   ├── types.ts          # TypeScript types
│   │   ├── App.tsx           # Main app
│   │   └── main.tsx          # Entry point
│   ├── public/               # Static assets
│   ├── package.json          # Dependencies
│   ├── vite.config.ts        # Vite configuration
│   └── tsconfig.json         # TypeScript config
├── deploy/
│   ├── deploy.sh             # Deployment script
│   ├── nginx-xeeta.conf      # Nginx config
│   └── openrc/               # Init scripts
├── docs/                     # Documentation
├── justfile                  # Task commands
└── README.md                 # Project overview
```

---

## Backend Development

### Zig Code Style

Follow the official Zig style guide:

1. **Naming**:
   - `snake_case` for functions and variables
   - `PascalCase` for types
   - `UPPER_CASE` for constants

2. **Formatting**:
   ```bash
   zig fmt src/main.zig
   ```

3. **Error Handling**:
   ```zig
   // Use error unions
   pub fn doSomething() !void {
       const result = try someOperation();
       // Handle result
   }
   
   // Use catch for default values
   const value = mightFail() catch defaultValue;
   ```

### Adding a New Module

1. Create the module file:
   ```bash
   touch backend/src/mymodule.zig
   ```

2. Implement the module:
   ```zig
   // backend/src/mymodule.zig
   const std = @import("std");
   const http = @import("http.zig");
   const db = @import("db.zig");
   
   pub fn handler(allocator: std.mem.Allocator, req: *http.Request, res: *http.Response) !void {
       // Implementation
   }
   ```

3. Register routes in `main.zig`:
   ```zig
   const mymodule = @import("mymodule.zig");
   
   // In main():
   try server.addRoute("GET", "/api/mymodule", mymodule.handler);
   ```

4. Add database migrations in `db.zig` if needed.

### Running Tests

```bash
cd backend
zig build test
```

### Debugging

Add debug logging:
```zig
std.log.debug("Variable value: {s}", .{variable});
std.log.info("Processing request", .{});
std.log.warn("Rate limit approaching for IP: {s}", .{ip});
std.log.err("Failed to connect: {}", .{err});
```

Set log level via environment:
```bash
# More verbose logging
ZEETAPUS_LOG_LEVEL=debug
```

---

## Frontend Development

### TypeScript Code Style

1. **Naming**:
   - `PascalCase` for components and types
   - `camelCase` for functions and variables
   - `UPPER_CASE` for constants

2. **Components**:
   ```tsx
   // Use functional components with hooks
   const MyComponent: React.FC<MyComponentProps> = ({ prop }) => {
       const [state, setState] = useState(initialState);
       
       return (
           <div className="my-component">
               {prop}
           </div>
       );
   };
   ```

3. **TypeScript Types**:
   ```tsx
   interface User {
       id: number;
       username: string;
       email: string;
   }
   ```

### Adding a New Page

1. Create the page component:
   ```tsx
   // frontend/src/pages/NewPage.tsx
   import React from 'react';
   
   const NewPage: React.FC = () => {
       return (
           <div>
               <h1>New Page</h1>
           </div>
       );
   };
   
   export default NewPage;
   ```

2. Add the route in `App.tsx`:
   ```tsx
   import NewPage from './pages/NewPage';
   
   <Route path="/newpage" element={<PrivateRoute><NewPage /></PrivateRoute>} />
   ```

### Adding a New Component

1. Create in `components/`:
   ```tsx
   // frontend/src/components/MyComponent.tsx
   interface MyComponentProps {
       title: string;
       onClick?: () => void;
   }
   
   const MyComponent: React.FC<MyComponentProps> = ({ title, onClick }) => {
       return (
           <button onClick={onClick} className="my-component">
               {title}
           </button>
       );
   };
   
   export default MyComponent;
   ```

### API Client Usage

```tsx
import api from './api';

// GET request
const response = await api.get('/api/posts');
const posts = await response.json();

// POST request
const response = await api.post('/api/posts', {
    content: 'Hello, world!'
});

// With error handling
try {
    const response = await api.get('/api/posts');
    if (!response.ok) {
        throw new Error('Failed to fetch posts');
    }
    const posts = await response.json();
} catch (error) {
    console.error('Error:', error);
}
```

### Running Tests

```bash
cd frontend
npm run test

# Watch mode
npm run test -- --watch

# Coverage
npm run test:coverage
```

### Building for Production

```bash
cd frontend
npm run build
```

Output is in `frontend/dist/`.

---

## Database Development

### Adding a Table

1. Add migration in `db.zig`:
   ```zig
   const migrations = [_][]const u8{
       // ...existing migrations
       \\CREATE TABLE IF NOT EXISTS new_table (
       \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
       \\    name TEXT NOT NULL,
       \\    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
       \\);
   };
   ```

2. Create corresponding struct in your module:
   ```zig
   const NewTable = struct {
       id: i64,
       name: []const u8,
       created_at: []const u8,
   };
   ```

### Database Queries

Always use parameterized queries:

```zig
// Correct
const users = try db.query(User, allocator,
    "SELECT * FROM users WHERE username = ?",
    &[_][]const u8{username}
);
defer db.freeRows(User, allocator, users);

// Incorrect (SQL injection risk)
const sql = try std.fmt.allocPrint(allocator,
    "SELECT * FROM users WHERE username = '{s}'",
    .{username}
);
```

### Database Management

```bash
# Open database
sqlite3 backend/xeetapus.db

# View tables
.tables

# Describe table
.schema users

# Query data
SELECT * FROM users LIMIT 5;

# Exit
.quit
```

---

## Testing

### Backend Unit Tests

Create tests in Zig files:

```zig
const std = @import("std");
const testing = std.testing;
const mymodule = @import("mymodule.zig");

test "my function works correctly" {
    const result = try mymodule.myFunction(testing.allocator);
    try testing.expectEqual(expected, result);
}
```

Run tests:
```bash
cd backend
zig build test
```

### Frontend Unit Tests

Create test files alongside components:

```tsx
// MyComponent.test.tsx
import { render, screen } from '@testing-library/react';
import MyComponent from './MyComponent';

describe('MyComponent', () => {
    it('renders correctly', () => {
        render(<MyComponent title="Test" />);
        expect(screen.getByText('Test')).toBeInTheDocument();
    });
});
```

Run tests:
```bash
cd frontend
npm run test
```

### End-to-End Testing

1. Start the development server:
   ```bash
   just dev
   ```

2. Test API endpoints with curl:
   ```bash
   # Health check
   curl http://localhost:8080/api/health
   
   # Register user
   curl -X POST http://localhost:8080/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{"username":"testuser","email":"test@example.com","password":"Test123!"}'
   ```

---

## Code Quality

### Linting

Frontend uses ESLint:
```bash
cd frontend
npm run lint
```

### Type Checking

Frontend TypeScript:
```bash
cd frontend
npm run build  # Includes type checking
```

### Formatting

Backend Zig:
```bash
cd backend
zig fmt src/
```

---

## Git Workflow

### Branch Naming

- `feature/feature-name` - New features
- `fix/bug-name` - Bug fixes
- `docs/documentation-update` - Documentation
- `refactor/component-name` - Code refactoring

### Commit Messages

Use conventional commits:

```
feat: add user blocking feature
fix: resolve authentication token expiry bug
docs: update API documentation
refactor: simplify password hashing logic
test: add unit tests for validation module
```

### Pull Request Process

1. Create feature branch
2. Make changes
3. Run tests
4. Submit PR with description

---

## Debugging Tips

### Backend Debugging

```zig
// Add debug logs
std.log.debug("Processing: {s}", .{input});
std.log.debug("Result: {}", .{result});

// Check error details
if (result) |value| {
    std.log.debug("Success: {}", .{value});
} else |err| {
    std.log.err("Error: {}", .{err});
}
```

### Frontend Debugging

```tsx
// Console logging
console.log('Data:', data);

// Debugger
debugger;

// React DevTools
// Use browser extension for component inspection
```

### Database Debugging

```sql
-- Enable query logging
PRAGMA cache_size = 0;

-- Check table structure
.schema users

-- View recent entries
SELECT * FROM users ORDER BY created_at DESC LIMIT 10;
```

---

## Performance Tips

### Backend

1. Use arena allocators for request handling
2. Free resources properly
3. Use prepared statements
4. Add indexes for frequently queried columns

### Frontend

1. Use React.memo for expensive components
2. Implement virtualization for long lists
3. Lazy load images
4. Use production builds for benchmarks

---

## Common Issues

### Port Already in Use

```bash
# Find and kill process
lsof -ti:8080 | xargs kill -9

# Or use Just
just stop
```

### Build Errors

```bash
# Clean and rebuild
just clean
just build
```

### Database Locked

```bash
# Ensure only one process uses database
just stop
# Restart database
rm backend/xeetapus.db-wal backend/xeetapus.db-shm 2>/dev/null || true
just run-backend
```

---

## Resources

- [Zig Documentation](https://ziglang.org/documentation/)
- [React Documentation](https://react.dev/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Radix UI](https://www.radix-ui.com/docs)