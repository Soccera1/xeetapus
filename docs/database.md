# Database Schema

Xeetapus uses SQLite as its database. This document describes the complete database schema.

## Overview

- **Database Engine**: SQLite3
- **File Location**: `backend/xeetapus.db` (configurable via `XEETAPUS_DB_PATH`)
- **Migrations**: Automatic on startup (see `backend/src/db.zig`)

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                              users                                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │id, username, email, password_hash, display_name, bio,       │    │
│  │ avatar_url, created_at, updated_at                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
          │      │      │      │      │      │      │
          │      │      │      │      │      │      │
          ▼      ▼      ▼      ▼      ▼      ▼      ▼
      ┌───────┐ ┌──────┐ ┌──────┐ ┌───────┐ ┌──────┐ ┌──────┐
      │ posts │ │follows│ │likes │ │blocks │ │mutes │ │drafts│ ...
      └───────┘ └──────┘ └──────┘ └───────┘ └──────┘ └──────┘
          │
          ├──► comments
          ├──► reposts
          ├──► bookmarks
          ├──► post_views
          ├──► quote_posts
          ├──► post_hashtags
          └──► polls ──► poll_options ──► poll_votes
```

---

## Tables

### users

User accounts and profiles.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique user ID |
| username | TEXT | UNIQUE NOT NULL | Username (3-20 chars) |
| email | TEXT | UNIQUE NOT NULL | Email address |
| password_hash | TEXT | NOT NULL | Hashed password |
| display_name | TEXT | | Display name |
| bio | TEXT | | User biography |
| avatar_url | TEXT | | Avatar image URL |
| legacy_password_hash | TEXT | | Legacy password hash (migration) |
| password_migrated_at | DATETIME | | Password migration timestamp |
| migration_notified_at | DATETIME | | Migration notification timestamp |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Account creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Last update time |

**Indexes**: `username`, `email`

**Example**:
```sql
INSERT INTO users (username, email, password_hash)
VALUES ('johndoe', 'john@example.com', '$2a$12$...');
```

---

### posts

User posts (xeets).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique post ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Author ID |
| content | TEXT | NOT NULL | Post content (max 280 chars) |
| media_urls | TEXT | | JSON array of media URLs |
| reply_to_id | INTEGER | FK → posts.id | Parent post (for replies) |
| quote_to_id | INTEGER | FK → posts.id | Quoted post |
| poll_id | INTEGER | FK → polls.id | Attached poll |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

**Indexes**: `user_id`, `created_at`, `reply_to_id`

**Example**:
```sql
INSERT INTO posts (user_id, content)
VALUES (1, 'Hello, world!');
```

---

### likes

Post likes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique like ID |
| user_id | INTEGER | NOT NULL, FK → users.id | User who liked |
| post_id | INTEGER | NOT NULL, FK → posts.id | Liked post |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Like time |

**Unique Constraint**: `(user_id, post_id)`

---

### follows

User follow relationships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique follow ID |
| follower_id | INTEGER | NOT NULL, FK → users.id | Follower user |
| following_id | INTEGER | NOT NULL, FK → users.id | Followed user |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Follow time |

**Unique Constraint**: `(follower_id, following_id)`

---

### comments

Post comments.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique comment ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Comment author |
| post_id | INTEGER | NOT NULL, FK → posts.id | Commented post |
| content | TEXT | NOT NULL | Comment content |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

---

### reposts

Reposted posts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique repost ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Reposting user |
| post_id | INTEGER | NOT NULL, FK → posts.id | Reposted post |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Repost time |

**Unique Constraint**: `(user_id, post_id)`

---

### bookmarks

Saved posts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique bookmark ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Saving user |
| post_id | INTEGER | NOT NULL, FK → posts.id | Saved post |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Save time |

**Unique Constraint**: `(user_id, post_id)`

---

### notifications

User notifications.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique notification ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Notification recipient |
| actor_id | INTEGER | NOT NULL, FK → users.id | User who triggered |
| type | TEXT | NOT NULL | Notification type |
| post_id | INTEGER | FK → posts.id | Related post |
| read | INTEGER | DEFAULT 0 | Read status (0/1) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |

**Notification Types**:
- `like` - Post liked
- `follow` - User followed
- `mention` - Mentioned in post
- `comment` - Post commented
- `repost` - Post reposted

---

### communities

Topic-based communities.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique community ID |
| name | TEXT | UNIQUE NOT NULL | Community name |
| description | TEXT | | Community description |
| icon_url | TEXT | | Icon image URL |
| banner_url | TEXT | | Banner image URL |
| created_by | INTEGER | NOT NULL, FK → users.id | Creator |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |

---

### community_members

Community memberships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique membership ID |
| community_id | INTEGER | NOT NULL, FK → communities.id | Community |
| user_id | INTEGER | NOT NULL, FK → users.id | Member |
| joined_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Join time |

**Unique Constraint**: `(community_id, user_id)`

---

### community_posts

Posts in communities.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique link ID |
| community_id | INTEGER | NOT NULL, FK → communities.id | Community |
| post_id | INTEGER | NOT NULL, FK → posts.id | Post |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Post time |

**Unique Constraint**: `(community_id, post_id)`

---

### conversations

Direct message conversation threads.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique conversation ID |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

---

### conversation_participants

Conversation participants.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique participant ID |
| conversation_id | INTEGER | NOT NULL, FK → conversations.id | Conversation |
| user_id | INTEGER | NOT NULL, FK → users.id | Participant |
| joined_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Join time |

**Unique Constraint**: `(conversation_id, user_id)`

---

### messages

Direct messages.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique message ID |
| conversation_id | INTEGER | NOT NULL, FK → conversations.id | Conversation |
| sender_id | INTEGER | NOT NULL, FK → users.id | Sender |
| content | TEXT | NOT NULL | Message content |
| media_urls | TEXT | | JSON array of media URLs |
| read | INTEGER | DEFAULT 0 | Read status (0/1) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Send time |

---

### user_lists

Custom user lists.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique list ID |
| owner_id | INTEGER | NOT NULL, FK → users.id | List owner |
| name | TEXT | NOT NULL | List name |
| description | TEXT | | List description |
| is_private | INTEGER | DEFAULT 0 | Private flag (0/1) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

---

### list_members

List memberships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique membership ID |
| list_id | INTEGER | NOT NULL, FK → user_lists.id | List |
| user_id | INTEGER | NOT NULL, FK → users.id | Member |
| added_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Add time |

**Unique Constraint**: `(list_id, user_id)`

---

### hashtags

Hashtag tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique hashtag ID |
| tag | TEXT | UNIQUE NOT NULL | Hashtag text (without #) |
| use_count | INTEGER | DEFAULT 1 | Usage count |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | First use |

---

### post_hashtags

Post-hashtag relationships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique link ID |
| post_id | INTEGER | NOT NULL, FK → posts.id | Post |
| hashtag_id | INTEGER | NOT NULL, FK → hashtags.id | Hashtag |

**Unique Constraint**: `(post_id, hashtag_id)`

---

### polls

Polls attached to posts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique poll ID |
| post_id | INTEGER | NOT NULL, FK → posts.id | Associated post |
| question | TEXT | NOT NULL | Poll question |
| duration_minutes | INTEGER | DEFAULT 1440 | Duration in minutes |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| ends_at | DATETIME | | End time |

---

### poll_options

Poll answer options.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique option ID |
| poll_id | INTEGER | NOT NULL, FK → polls.id | Parent poll |
| option_text | TEXT | NOT NULL | Option text |
| position | INTEGER | NOT NULL | Display order |
| vote_count | INTEGER | DEFAULT 0 | Vote count |

---

### poll_votes

User poll votes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique vote ID |
| poll_id | INTEGER | NOT NULL, FK → polls.id | Poll |
| option_id | INTEGER | NOT NULL, FK → poll_options.id | Chosen option |
| user_id | INTEGER | NOT NULL, FK → users.id | Voter |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Vote time |

**Unique Constraint**: `(poll_id, user_id)`

---

### quote_posts

Quote posts (reposts with comment).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique quote ID |
| post_id | INTEGER | NOT NULL, FK → posts.id | Quoting post |
| quoted_post_id | INTEGER | NOT NULL, FK → posts.id | Quoted post |
| comment | TEXT | | Quote comment |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |

**Unique Constraint**: `(post_id, quoted_post_id)`

---

### post_views

Post view analytics.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique view ID |
| post_id | INTEGER | NOT NULL, FK → posts.id | Viewed post |
| user_id | INTEGER | FK → users.id | Viewer (nullable) |
| ip_address | TEXT | | Viewer IP |
| viewed_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | View time |

---

### blocks

User blocks.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique block ID |
| blocker_id | INTEGER | NOT NULL, FK → users.id | Blocking user |
| blocked_id | INTEGER | NOT NULL, FK → users.id | Blocked user |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Block time |

**Unique Constraint**: `(blocker_id, blocked_id)`

---

### mutes

User mutes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique mute ID |
| muter_id | INTEGER | NOT NULL, FK → users.id | Muting user |
| muted_id | INTEGER | NOT NULL, FK → users.id | Muted user |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Mute time |

**Unique Constraint**: `(muter_id, muted_id)`

---

### drafts

Unpublished post drafts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique draft ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Author |
| content | TEXT | NOT NULL | Draft content |
| media_urls | TEXT | | JSON array of media URLs |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

---

### scheduled_posts

Scheduled posts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique schedule ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Author |
| content | TEXT | NOT NULL | Post content |
| media_urls | TEXT | | JSON array of media URLs |
| scheduled_at | DATETIME | NOT NULL | Scheduled time |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| is_posted | INTEGER | DEFAULT 0 | Posted status (0/1) |

---

### pinned_posts

Pinned posts on profiles.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique pin ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Profile owner |
| post_id | INTEGER | NOT NULL, FK → posts.id | Pinned post |
| pinned_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Pin time |

**Unique Constraint**: `(user_id)` - Only one pinned post per user

---

### llm_provider_configs

Per-user LLM provider settings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique config ID |
| user_id | INTEGER | NOT NULL, FK → users.id | User |
| provider | TEXT | NOT NULL | Provider name |
| api_key | TEXT | NOT NULL | Encrypted API key |
| model | TEXT | NOT NULL | Model name |
| base_url | TEXT | | Custom API URL |
| is_default | INTEGER | DEFAULT 0 | Default provider flag |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

**Unique Constraint**: `(user_id, provider)`

---

### invoices

Monero payment invoices.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique invoice ID |
| user_id | INTEGER | NOT NULL, FK → users.id | Payer |
| amount | INTEGER | NOT NULL | Amount in atomic units |
| invoice | TEXT | NOT NULL | Payment address |
| status | TEXT | DEFAULT 'pending' | Invoice status |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| paid_at | DATETIME | | Payment time |

---

### payments

Monero payment records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Unique payment ID |
| user_id | INTEGER | NOT NULL, FK → users.id | User |
| amount | INTEGER | NOT NULL | Amount in atomic units |
| invoice | TEXT | NOT NULL | Invoice reference |
| status | TEXT | DEFAULT 'pending' | Payment status |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| completed_at | DATETIME | | Completion time |

---

## Relationships

### User Relationships

```
users ──┬──< posts (author)
        ├──< likes
        ├──< comments
        ├──< reposts
        ├──< bookmarks
        ├──< follows (follower)
        ├──< follows (following)
        ├──< blocks (blocker)
        ├──< blocks (blocked)
        ├──< mutes (muter)
        ├──< mutes (muted)
        ├──< notifications (recipient)
        ├──< notifications (actor)
        ├──< drafts
        ├──< scheduled_posts
        ├──< pinned_posts
        ├──< llm_provider_configs
        ├──< user_lists
        ├──< community_members
        ├──< conversation_participants
        ├──< messages
        ├──< poll_votes
        ├──< post_views
        ├──< invoices
        └──< payments
```

### Post Relationships

```
posts ──┬──< comments
        ├──< likes
        ├──< reposts
        ├──< bookmarks
        ├──< post_hashtags
        ├──< post_views
        ├──< quote_posts
        ├──< poll (one)
        ├── community_post (one)
        └──> reply_to (parent post)
```

---

## Indexes

Recommended indexes for performance:

```sql
-- Users
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Posts
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_reply_to ON posts(reply_to_id);

-- Likes
CREATE INDEX idx_likes_post_id ON likes(post_id);
CREATE INDEX idx_likes_user_id ON likes(user_id);

-- Follows
CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);

-- Messages
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);

-- Hashtags
CREATE INDEX idx_hashtags_tag ON hashtags(tag);
CREATE INDEX idx_hashtags_count ON hashtags(use_count DESC);
```

---

## Migration System

Migrations are run automatically on startup in `db.zig`:

1. **Table Creation**: `CREATE TABLE IF NOT EXISTS` statements
2. **Schema Migrations**: `ALTER TABLE` statements for column additions

When adding new migrations:

1. Add to the `migrations` array for new tables
2. Add to `schema_migrations` for ALTER statements
3. Migrations are idempotent (ignored if already applied)

---

## Backup & Restore

### Backup

```bash
# Stop the server first
just stop

# Copy database
cp backend/xeetapus.db backend/xeetapus.db.backup

# Or use SQLite backup
sqlite3 backend/xeetapus.db ".backup 'xeetapus.db.backup'"
```

### Restore

```bash
# Stop server
just stop

# Restore from backup
cp backend/xeetapus.db.backup backend/xeetapus.db
```

### Export Data

```bash
# Export to SQL
sqlite3 backend/xeetapus.db .dump > backup.sql

# Export specific table
sqlite3 backend/xeetapus.db "SELECT * FROM users;" > users.csv
```

---

## Query Examples

### Get User Timeline

```sql
SELECT p.*, u.username, u.display_name
FROM posts p
JOIN follows f ON p.user_id = f.following_id
JOIN users u ON p.user_id = u.id
WHERE f.follower_id = ?
ORDER BY p.created_at DESC
LIMIT 20;
```

### Get Post with Engagement

```sql
SELECT 
    p.*,
    (SELECT COUNT(*) FROM likes WHERE post_id = p.id) as likes_count,
    (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comments_count,
    (SELECT COUNT(*) FROM reposts WHERE post_id = p.id) as reposts_count
FROM posts p
WHERE p.id = ?;
```

### Get Unread Notification Count

```sql
SELECT COUNT(*) 
FROM notifications 
WHERE user_id = ? AND read = 0;
```

---

## See Also

- [API Reference](./api-reference.md) - How API endpoints use these tables
- [Architecture](./architecture.md) - How the database layer works