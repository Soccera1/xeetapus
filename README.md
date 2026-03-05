# Xeetapus

A fully functional clone of X (Twitter) built with Zig backend and React frontend.

## Features

- **User Authentication**: Register, login, and logout
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
- **Pinned Posts**: Pin important posts to your profile

## Tech Stack

### Backend (Zig)
- Custom HTTP server
- SQLite database with 20+ tables
- RESTful API
- CORS support
- Port: 8080

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
│   │   ├── http.zig           # HTTP server implementation
│   │   ├── db.zig             # Database module & migrations
│   │   ├── auth.zig           # Authentication handlers
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
│   └── xeetapus.db            # SQLite database
├── frontend/
│   ├── src/                   # React source code
│   ├── dist/                  # Built files (production)
│   ├── package.json           # Node dependencies
│   └── vite.config.ts         # Vite configuration
├── justfile                   # Task runner commands
├── LICENSE                    # AGPL3+ License
└── README.md
```

## Prerequisites

- Zig 0.11.0 or later
- SQLite3 (development library)
- Node.js 18+ and npm
- A C compiler (for Zig SQLite bindings)
- [Just](https://github.com/casey/just) task runner (recommended)

## Installation

### Using Just (Recommended)

```bash
# Install Just first: https://github.com/casey/just

# Build everything
just build

# Or build individually
just build-backend
just build-frontend
```

### Manual Installation

**Backend:**
```bash
cd backend
zig build
```

**Frontend:**
```bash
cd frontend
npm install
npm run build
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
npm run dev
# Frontend on port 3000
```

**Build Frontend for Production:**
```bash
cd frontend
npm run build
# Serves static files from backend on port 8080
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login
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

### Health
- `GET /api/health` - Health check endpoint

## Database Schema

The application uses SQLite with the following tables:

- **users** - User accounts with profile info
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

The frontend uses Vite for fast development:

```bash
cd frontend
npm install            # Install dependencies
npm run dev            # Start dev server with hot reload
npm run build          # Build for production
npm run preview        # Preview production build
npm run test           # Run tests
```

## Security Notes

This is a demo application. For production use:

1. Use proper JWT authentication with secure secrets
2. Implement rate limiting on all endpoints
3. Use HTTPS/TLS for all connections
4. Sanitize user inputs to prevent XSS
5. Use bcrypt or Argon2 for password hashing
6. Add CSRF protection
7. Implement proper CORS policies
8. Add input validation and SQL injection prevention
9. Use prepared statements for all database queries
10. Implement request logging and monitoring

## License

AGPL3+ - See LICENSE file for details
