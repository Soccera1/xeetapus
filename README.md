# Xeetapus

A fully functional clone of X (Twitter) built with Zig backend and TypeScript frontend.

## Features

- **User Authentication**: Register, login, and logout
- **Posts (Xeets)**: Create, delete, and view posts (280 character limit)
- **Timeline**: View posts from users you follow
- **Explore**: Discover popular posts
- **Likes**: Like and unlike posts
- **Comments**: Comment on posts
- **Follow System**: Follow and unfollow users
- **User Profiles**: View user profiles with stats

## Tech Stack

### Backend (Zig)
- Custom HTTP server
- SQLite database
- RESTful API
- CORS support

### Frontend (TypeScript)
- Vanilla TypeScript
- Custom router
- Component-based architecture
- Responsive design

## Project Structure

```
xeetapus/
├── backend/
│   ├── src/
│   │   ├── main.zig         # Entry point
│   │   ├── http.zig         # HTTP server implementation
│   │   ├── db.zig           # Database module
│   │   ├── auth.zig         # Authentication handlers
│   │   ├── posts.zig        # Post handlers
│   │   ├── users.zig        # User handlers
│   │   └── timeline.zig     # Timeline handlers
│   └── build.zig            # Zig build configuration
├── frontend/
│   ├── src/
│   │   ├── main.ts          # Entry point
│   │   ├── api.ts           # API client
│   │   ├── router.ts        # Router
│   │   ├── types.ts         # TypeScript types
│   │   ├── views/           # Page views
│   │   └── components/      # UI components
│   ├── public/              # Built files
│   └── package.json
└── README.md
```

## Prerequisites

- Zig 0.11.0 or later
- SQLite3
- Node.js 18+ and npm
- A C compiler (for Zig SQLite bindings)

## Installation

### Backend

```bash
cd backend
zig build
```

### Frontend

```bash
cd frontend
npm install
npm run build
```

## Running the Application

### Start the Backend

```bash
cd backend
zig build run
```

The backend server will start on port 8080.

### Start the Frontend

```bash
cd frontend
npm run dev
```

The frontend will be served on port 8080 (or another available port).

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Posts
- `GET /api/posts` - List all posts
- `POST /api/posts` - Create a new post
- `GET /api/posts/:id` - Get a specific post
- `DELETE /api/posts/:id` - Delete a post
- `POST /api/posts/:id/like` - Like a post
- `DELETE /api/posts/:id/like` - Unlike a post
- `POST /api/posts/:id/comment` - Comment on a post
- `GET /api/posts/:id/comments` - Get post comments

### Users
- `GET /api/users/:username` - Get user profile
- `GET /api/users/:username/posts` - Get user's posts
- `POST /api/users/:username/follow` - Follow a user
- `DELETE /api/users/:username/follow` - Unfollow a user
- `GET /api/users/:username/followers` - Get followers
- `GET /api/users/:username/following` - Get following

### Timeline
- `GET /api/timeline` - Get personal timeline
- `GET /api/timeline/explore` - Get explore feed

## Database Schema

The application uses SQLite with the following tables:

- **users**: User accounts
- **posts**: User posts (xeets)
- **likes**: Post likes
- **follows**: User follows
- **comments**: Post comments

## Development

### Backend Development

```bash
cd backend
zig build run
```

### Frontend Development

```bash
cd frontend
npm run watch
```

## Security Notes

This is a demo application. For production use:

1. Use proper JWT authentication
2. Implement rate limiting
3. Use HTTPS
4. Sanitize user inputs properly
5. Use a proper password hashing library (bcrypt/Argon2)
6. Add CSRF protection
7. Implement proper CORS policies

## License

AGPL3+
