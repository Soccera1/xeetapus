# API Reference

Complete REST API documentation for Xeetapus.

## Base URL

- Development: `http://localhost:8080/api`
- Production: `https://your-domain.com/api`

## Authentication

Xeetapus uses cookie-based authentication with JWT tokens.

### Authentication Flow

1. Register or login to receive a session cookie
2. Session cookie is automatically included in subsequent requests
3. CSRF token required for state-changing operations

### CSRF Protection

For POST, PUT, DELETE requests, include the CSRF token:
```http
X-CSRF-Token: <token>
```

The CSRF token is returned in the `Set-Cookie` header on login and available via `/api/auth/me`.

## Response Format

### Success Response
```json
{
  "data": {...},
  "status": "success"
}
```

### Error Response
```json
{
  "error": "Error message",
  "status": "error"
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

## Rate Limiting

Default: 100 requests per 60 secondsper IP.

Rate limit headers are included in responses:
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1712345678
```

---

## Authentication Endpoints

### Register User

Create a new user account.

**Endpoint**: `POST /api/auth/register`

**Public**: Yes

**Request Body**:
```json
{
  "username": "string (3-20 chars, alphanumeric and underscores)",
  "email": "string (valid email)",
  "password": "string (8+ chars, complexity requirements)"
}
```

**Response**: `201 Created`
```json
{
  "id": 1,
  "username": "johndoe",
  "email": "john@example.com",
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Errors**:
- `400`: Invalid input
- `409`: Username or email already exists

---

### Login

Authenticate and receive session cookie.

**Endpoint**: `POST /api/auth/login`

**Public**: Yes

**Request Body**:
```json
{
  "username": "string",
  "password": "string"
}
```

**Response**: `200 OK`
```json
{
  "id": 1,
  "username": "johndoe",
  "email": "john@example.com",
  "display_name": "John Doe",
  "bio": "Developer",
  "avatar_url": null,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Cookies Set**:
- `session`: HTTP-only, secure (production), SameSite=Lax

---

### Logout

End the current session.

**Endpoint**: `POST /api/auth/logout`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "message": "Logged out successfully"
}
```

---

### Get Current User

Get the authenticated user's profile.

**Endpoint**: `GET /api/auth/me`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "id": 1,
  "username": "johndoe",
  "email": "john@example.com",
  "display_name": "John Doe",
  "bio": "Developer",
  "avatar_url": null,
  "csrf_token": "abc123...",
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

## Post Endpoints

### List Posts

Get a paginated list of posts.

**Endpoint**: `GET /api/posts`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | int | 1 | Page number |
| limit | int | 20 | Posts per page (max100) |

**Response**: `200 OK`
```json
{
  "posts": [
    {
      "id": 1,
      "user_id": 1,
      "username": "johndoe",
      "display_name": "John Doe",
      "content": "Hello, world!",
      "media_urls": null,
      "likes_count": 5,
      "comments_count": 2,
      "reposts_count": 1,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "page": 1,
  "total_pages": 5
}
```

---

### Create Post

Create a new post (xeet).

**Endpoint**: `POST /api/posts`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string (max 280 chars)",
  "media_urls": ["string"], // Optional
  "reply_to_id": null, // Optional, for replies
  "community_id": null // Optional, for community posts
}
```

**Response**: `201 Created`
```json
{
  "id": 123,
  "user_id": 1,
  "content": "Hello, world!",
  "media_urls": null,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

### Get Post

Get a specific post by ID.

**Endpoint**: `GET /api/posts/:id`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "id": 1,
  "user_id": 1,
  "username": "johndoe",
  "display_name": "John Doe",
  "content": "Hello, world!",
  "media_urls": null,
  "likes_count": 5,
  "comments_count": 2,
  "reposts_count": 1,
  "is_liked": false,
  "is_reposted": false,
  "is_bookmarked": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

### Delete Post

Delete own post.

**Endpoint**: `DELETE /api/posts/:id`

**Auth Required**: Yes

**Response**: `204 No Content`

---

### Like Post

Like a post.

**Endpoint**: `POST /api/posts/:id/like`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "message": "Post liked"
}
```

---

### Unlike Post

Remove like from a post.

**Endpoint**: `DELETE /api/posts/:id/like`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Repost Post

Repost a post to timeline.

**Endpoint**: `POST /api/posts/:id/repost`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "message": "Post reposted"
}
```

---

### Undo Repost

Remove repost.

**Endpoint**: `DELETE /api/posts/:id/repost`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Bookmark Post

Save a post for later.

**Endpoint**: `POST /api/posts/:id/bookmark`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Remove Bookmark

Remove saved post.

**Endpoint**: `DELETE /api/posts/:id/bookmark`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Comment on Post

Add a comment to a post.

**Endpoint**: `POST /api/posts/:id/comment`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string"
}
```

**Response**: `201 Created`

---

### Get Post Comments

Get comments for a post.

**Endpoint**: `GET /api/posts/:id/comments`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`
```json
{
  "comments": [
    {
      "id": 1,
      "user_id": 2,
      "username": "janedoe",
      "content": "Great post!",
      "created_at": "2024-01-15T11:00:00Z"
    }
  ]
}
```

---

### Pin Post

Pin a post to profile.

**Endpoint**: `POST /api/posts/:id/pin`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Unpin Post

Remove pinned post.

**Endpoint**: `DELETE /api/posts/:id/pin`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Record Post View

Record a view for analytics.

**Endpoint**: `POST /api/posts/:id/view`

**Auth Required**: Yes

**Response**: `200 OK`

---

## User Endpoints

### Get User Profile

Get a user's public profile.

**Endpoint**: `GET /api/users/:username`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "id": 1,
  "username": "johndoe",
  "display_name": "John Doe",
  "bio": "Software developer",
  "avatar_url": null,
  "followers_count": 150,
  "following_count": 200,
  "posts_count": 50,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

### Get User Posts

Get posts by a user.

**Endpoint**: `GET /api/users/:username/posts`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`

---

### Get User Replies

Get replies by a user.

**Endpoint**: `GET /api/users/:username/replies`

**Public**: Yes

**Response**: `200 OK`

---

### Get User Media Posts

Get posts with media by a user.

**Endpoint**: `GET /api/users/:username/media`

**Public**: Yes

**Response**: `200 OK`

---

### Follow User

Follow a user.

**Endpoint**: `POST /api/users/:username/follow`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Unfollow User

Unfollow a user.

**Endpoint**: `DELETE /api/users/:username/follow`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Followers

Get a user's followers.

**Endpoint**: `GET /api/users/:username/followers`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`

---

### Get Following

Get users that a user follows.

**Endpoint**: `GET /api/users/:username/following`

**Public**: Yes

**Response**: `200 OK`

---

### Update Profile

Update current user's profile.

**Endpoint**: `PUT /api/users/me`

**Auth Required**: Yes

**Request Body**:
```json
{
  "display_name": "string (optional)",
  "bio": "string (optional)",
  "avatar_url": "string (optional)"
}
```

**Response**: `200 OK`

---

## Block/Mute Endpoints

### Block User

Block a user.

**Endpoint**: `POST /api/users/:username/block`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Unblock User

Unblock a user.

**Endpoint**: `DELETE /api/users/:username/block`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Mute User

Mute a user.

**Endpoint**: `POST /api/users/:username/mute`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Unmute User

Unmute a user.

**Endpoint**: `DELETE /api/users/:username/mute`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Blocked Users

List blocked users.

**Endpoint**: `GET /api/blocks`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Muted Users

List muted users.

**Endpoint**: `GET /api/mutes`

**Auth Required**: Yes

**Response**: `200 OK`

---

## Timeline Endpoints

### Get Timeline

Get personalized feed for authenticated user.

**Endpoint**: `GET /api/timeline`

**Auth Required**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`

---

### Get Explore Feed

Get trending/popular posts.

**Endpoint**: `GET /api/timeline/explore`

**Public**: Yes

**Response**: `200 OK`

---

## Notification Endpoints

### List Notifications

Get user notifications.

**Endpoint**: `GET /api/notifications`

**Auth Required**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`
```json
{
  "notifications": [
    {
      "id": 1,
      "type": "like",
      "actor_username": "janedoe",
      "post_id": 123,
      "read": false,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

---

### Mark Notification as Read

Mark a notification as read.

**Endpoint**: `POST /api/notifications/:id/read`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Mark All Notifications as Read

Mark all notifications as read.

**Endpoint**: `POST /api/notifications/read-all`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Unread notification Count

Get count of unread notifications.

**Endpoint**: `GET /api/notifications/unread-count`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "count": 5
}
```

---

## Search Endpoints

### Search Users

Search for users.

**Endpoint**: `GET /api/search/users`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Required |
|-----------|------|----------|
| q | string | Yes |
| page | int | No |
| limit | int | No |

**Response**: `200 OK`

---

### Search Posts

Search for posts.

**Endpoint**: `GET /api/search/posts`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Required |
|-----------|------|----------|
| q | string | Yes |
| page | int | No |
| limit | int | No |

**Response**: `200 OK`

---

## Community Endpoints

### List Communities

Get all communities.

**Endpoint**: `GET /api/communities`

**Public**: Yes

**Response**: `200 OK`

---

### Create Community

Create a new community.

**Endpoint**: `POST /api/communities`

**Auth Required**: Yes

**Request Body**:
```json
{
  "name": "string",
  "description": "string"
}
```

**Response**: `201 Created`

---

### Get Community

Get community details.

**Endpoint**: `GET /api/communities/:id`

**Public**: Yes

**Response**: `200 OK`

---

### Join Community

Join a community.

**Endpoint**: `POST /api/communities/:id/join`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Leave Community

Leave a community.

**Endpoint**: `DELETE /api/communities/:id/join`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Community Posts

Get posts in a community.

**Endpoint**: `GET /api/communities/:id/posts`

**Public**: Yes

**Response**: `200 OK`

---

### Post to Community

Create post in community.

**Endpoint**: `POST /api/communities/:id/posts`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string"
}
```

**Response**: `201 Created`

---

### Get Community Members

Get community member list.

**Endpoint**: `GET /api/communities/:id/members`

**Public**: Yes

**Response**: `200 OK`

---

## Direct Message Endpoints

### Get Conversations

List user's conversations.

**Endpoint**: `GET /api/messages/conversations`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Create Conversation

Start a new conversation.

**Endpoint**: `POST /api/messages/conversations`

**Auth Required**: Yes

**Request Body**:
```json
{
  "user_ids": [2, 3]
}
```

**Response**: `201 Created`

---

### Get Messages

Get messages in a conversation.

**Endpoint**: `GET /api/messages/conversations/:id`

**Auth Required**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 50 |

**Response**: `200 OK`

---

### Send Message

Send a message in a conversation.

**Endpoint**: `POST /api/messages/conversations/:id`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string",
  "media_urls": [] // optional
}
```

**Response**: `201 Created`

---

### Get Unread Message Count

Count of unread messages.

**Endpoint**: `GET /api/messages/unread-count`

**Auth Required**: Yes

**Response**: `200 OK`

---

## List Endpoints

### Get My Lists

Get user's custom lists.

**Endpoint**: `GET /api/lists`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Create List

Create a new list.

**Endpoint**: `POST /api/lists`

**Auth Required**: Yes

**Request Body**:
```json
{
  "name": "string",
  "description": "string" // optional
}
```

**Response**: `201 Created`

---

### Get List Details

Get listinformation.

**Endpoint**: `GET /api/lists/:id`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Delete List

Delete a list.

**Endpoint**: `DELETE /api/lists/:id`

**Auth Required**: Yes

**Response**: `204 No Content`

---

### Add Member to List

Add user to list.

**Endpoint**: `POST /api/lists/:id/members`

**Auth Required**: Yes

**Request Body**:
```json
{
  "user_id": 123
}
```

**Response**: `200 OK`

---

### Remove Member from List

Remove user from list.

**Endpoint**: `DELETE /api/lists/:id/members/:user_id`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get List Timeline

Get posts from list members.

**Endpoint**: `GET /api/lists/:id/timeline`

**Auth Required**: Yes

**Response**: `200 OK`

---

## Hashtag Endpoints

### Get Trending Hashtags

Get trending hashtags.

**Endpoint**: `GET /api/hashtags/trending`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "hashtags": [
    {
      "name": "zig",
      "count": 1500
    }
  ]
}
```

---

### Get Posts by Hashtag

Get posts with a specific hashtag.

**Endpoint**: `GET /api/hashtags/:tag/posts`

**Public**: Yes

**Query Parameters**:
| Parameter | Type | Default |
|-----------|------|---------|
| page | int | 1 |
| limit | int | 20 |

**Response**: `200 OK`

---

## Poll Endpoints

### Vote on Poll

Vote for a poll option.

**Endpoint**: `POST /api/polls/:id/vote`

**Auth Required**: Yes

**Request Body**:
```json
{
  "option_id": 1
}
```

**Response**: `200 OK`

---

### Get Poll Results

Get poll results.

**Endpoint**: `GET /api/polls/:id/results`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "poll_id": 1,
  "total_votes": 100,
  "options": [
    {
      "id": 1,
      "text": "Option A",
      "votes": 60,
      "percentage": 60.0
    },
    {
      "id": 2,
      "text": "Option B",
      "votes": 40,
      "percentage": 40.0
    }
  ]
}
```

---

## Draft Endpoints

### Get Drafts

Get user's draft posts.

**Endpoint**: `GET /api/drafts`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Create Draft

Save a draft post.

**Endpoint**: `POST /api/drafts`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string"
}
```

**Response**: `201 Created`

---

### Update Draft

Update a draft.

**Endpoint**: `PUT /api/drafts/:id`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string"
}
```

**Response**: `200 OK`

---

### Delete Draft

Delete a draft.

**Endpoint**: `DELETE /api/drafts/:id`

**Auth Required**: Yes

**Response**: `204 No Content`

---

## Scheduled Post Endpoints

### Get Scheduled Posts

Get user's scheduled posts.

**Endpoint**: `GET /api/scheduled`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Create Scheduled Post

Schedule a post for later.

**Endpoint**: `POST /api/scheduled`

**Auth Required**: Yes

**Request Body**:
```json
{
  "content": "string",
  "scheduled_for": "2024-02-01T10:00:00Z"
}
```

**Response**: `201 Created`

---

### Delete Scheduled Post

Cancel a scheduled post.

**Endpoint**: `DELETE /api/scheduled/:id`

**Auth Required**: Yes

**Response**: `204 No Content`

---

## Analytics Endpoints

### Get Post Views

Get view count for a post.

**Endpoint**: `GET /api/analytics/posts/:id/views`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "post_id": 123,
  "views": 1500
}
```

---

### Get User Analytics

Get analytics for current user.

**Endpoint**: `GET /api/analytics/me`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "total_posts": 50,
  "total_likes": 500,
  "total_followers": 150,
  "total_views": 5000
}
```

---

## LLM (AI Chat) Endpoints

### Get Available Providers

List available LLM providers.

**Endpoint**: `GET /api/llm/providers`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "providers": [
    "openai",
    "anthropic",
    "openrouter",
    "groq",
    "google",
    "together"
  ]
}
```

---

### Get User Configs

Get user's LLM configurations.

**Endpoint**: `GET /api/llm/configs`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Update Provider Config

Configure an LLM provider.

**Endpoint**: `PUT /api/llm/configs/:provider`

**Auth Required**: Yes

**Request Body**:
```json
{
  "api_key": "string",
  "model": "string",
  "enabled": true
}
```

**Response**: `200 OK`

---

### Delete Provider Config

Remove a provider configuration.

**Endpoint**: `DELETE /api/llm/configs/:provider`

**Auth Required**: Yes

**Response**: `204 No Content`

---

### Reveal API Key

Reveal configured API key.

**Endpoint**: `POST /api/llm/configs/:provider/reveal`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "api_key": "sk-..."
}
```

---

### Chat with LLM

Send a message to AI.

**Endpoint**: `POST /api/llm/chat`

**Auth Required**: Yes

**Request Body**:
```json
{
  "provider": "openai",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ]
}
```

**Response**: `200 OK`
```json
{
  "response": "Hello! How can I help you today?"
}
```

---

## Payment (Monero) Endpoints

### Create Invoice

Create a Monero payment invoice.

**Endpoint**: `POST /api/payments/invoices`

**Auth Required**: Yes

**Request Body (Option1 - Fixed XMR)**:
```json
{
  "xmr_amount": 0.5,
  "priority": "normal"
}
```

**Request Body (Option 2 - Fiat)**:
```json
{
  "amount": 10.00,
  "currency": "USD",
  "priority": "normal"
}
```

**Priority options**: `slow` (~90min), `normal` (~30min), `fast` (~10min), `fastest` (~5min)

**Response**: `201 Created`
```json
{
  "invoice_id": "abc123",
  "address": "4B..."
  "amount": 0.5,
  "network_fee": 0.001
}
```

---

### Check Payment Status

Check invoice payment status.

**Endpoint**: `GET /api/payments/invoices/:id`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "invoice_id": "abc123",
  "status": "pending",
  "amount": 0.5,"confirmed": false
}
```

---

### Get Invoices

List user's invoices.

**Endpoint**: `GET /api/payments/invoices`

**Auth Required**: Yes

**Response**: `200 OK`

---

### Get Balance

Get user's Monero balance.

**Endpoint**: `GET /api/payments/balance`

**Auth Required**: Yes

**Response**: `200 OK`
```json
{
  "balance": 1.5
}
```

---

### Pay Invoice

Pay an invoice.

**Endpoint**: `POST /api/payments/pay`

**Auth Required**: Yes

**Request Body**:
```json
{
  "invoice_id": "abc123"
}
```

**Response**: `200 OK`

---

### Get Exchange Rate

Get XMR/USD exchange rate.

**Endpoint**: `GET /api/payments/rate`

**Public**: Yes

**Response**: `200 OK`
```json
{
  "rate": 150.50,
  "currency": "USD",
  "network_fees": {
    "slow": 0.0005,"normal": 0.001,
    "fast": 0.002,
    "fastest": 0.005
  }
}
```

---

## Health Check

### Health Check

Basic health check endpoint.

**Endpoint**: `GET /api/health`
**Public**: Yes

**Response**: `200 OK`
```json
{
  "status": "ok",
  "service": "xeetapus"
}
```

---

## Media Endpoints

### Upload Media

Upload an image or video.

**Endpoint**: `POST /api/media/upload`

**Auth Required**: Yes

**Request**: `multipart/form-data`
- Field: `file`

**Response**: `201 Created`
```json
{
  "url": "/media/abc123.jpg"
}
```

---

### Serve Media

Serve uploaded media files.

**Endpoint**: `GET /media/*`

**Public**: Yes

**Response**: Binary file data

---

## Error Handling

All endpoints return consistent error responses:

```json
{
  "error": "Error description",
  "status": "error"
}
```

Common error codes:

| HTTP Code | Error |
|-----------|-------|
| 400 | Invalid input, missing fields |
| 401 | Authentication required |
| 403 | Forbidden, CSRF failure |
| 404 | Resource not found |
| 409 | Conflict (duplicate) |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

---

## Pagination

List endpoints support pagination with query parameters:

**Request**:
```
GET /api/posts?page=2&limit=50
```

**Response**:
```json
{
  "posts": [...],
  "page": 2,
  "total_pages": 10
}
```

Default limit is 20, maximum is100.