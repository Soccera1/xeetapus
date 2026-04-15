import { vi } from 'vitest';
import type { User, Post, Profile, Comment, Notification, Community, Conversation, Message, UserList, Hashtag, PollOption, Draft, ScheduledPost, UserAnalytics, BlockedUser, MutedUser, LlmProvider, LlmConfigSummary, LlmChatResponse } from '../../types';

export const mockUser: User = {
  id: 1,
  username: 'testuser',
  email: 'test@example.com',
  display_name: 'Test User',
  bio: 'Test bio',
  avatar_url: 'https://example.com/avatar.png',
  created_at: '2024-01-01T00:00:00Z',
  token: 'test-token',
};

export const mockPost: Post = {
  id: 1,
  user_id: 1,
  username: 'testuser',
  display_name: 'Test User',
  avatar_url: 'https://example.com/avatar.png',
  content: 'Test post content',
  is_liked: false,
  is_reposted: false,
  is_bookmarked: false,
  created_at: '2024-01-01T00:00:00Z',
  likes_count: 0,
  comments_count: 0,
  reposts_count: 0,
};

export const mockProfile: Profile = {
  id: 1,
  username: 'testuser',
  display_name: 'Test User',
  bio: 'Test bio',
  avatar_url: 'https://example.com/avatar.png',
  created_at: '2024-01-01T00:00:00Z',
  followers_count: 10,
  following_count: 20,
  posts_count: 5,
  is_following: false,
};

export const mockComment: Comment = {
  id: 1,
  user_id: 1,
  username: 'testuser',
  display_name: 'Test User',
  avatar_url: 'https://example.com/avatar.png',
  content: 'Test comment',
  created_at: '2024-01-01T00:00:00Z',
};

export const mockNotification: Notification = {
  id: 1,
  actor_id: 2,
  actor_username: 'otheruser',
  actor_display_name: 'Other User',
  type: 'like',
  post_id: 1,
  read: false,
  created_at: '2024-01-01T00:00:00Z',
};

export const mockCommunity: Community = {
  id: 1,
  name: 'Test Community',
  description: 'Test community description',
  created_by: 1,
  created_at: '2024-01-01T00:00:00Z',
  member_count: 100,
  post_count: 50,
  is_member: false,
};

export const mockConversation: Conversation = {
  id: 1,
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
  participants: 'user1,user2',
  last_message: 'Last message',
  unread_count: 0,
};

export const mockMessage: Message = {
  id: 1,
  conversation_id: 1,
  sender_id: 1,
  sender_username: 'testuser',
  sender_display_name: 'Test User',
  content: 'Test message',
  read: false,
  created_at: '2024-01-01T00:00:00Z',
};

export const mockUserList: UserList = {
  id: 1,
  owner_id: 1,
  name: 'Test List',
  description: 'Test list description',
  is_private: false,
  member_count: 5,
  created_at: '2024-01-01T00:00:00Z',
};

export const mockHashtag: Hashtag = {
  id: 1,
  tag: 'test',
  use_count: 100,
};

export const mockPollOption: PollOption = {
  id: 1,
  poll_id: 1,
  option_text: 'Option 1',
  position: 1,
  vote_count: 10,
};

export const mockDraft: Draft = {
  id: 1,
  user_id: 1,
  content: 'Draft content',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};

export const mockScheduledPost: ScheduledPost = {
  id: 1,
  user_id: 1,
  content: 'Scheduled content',
  scheduled_at: '2024-12-31T00:00:00Z',
  created_at: '2024-01-01T00:00:00Z',
  is_posted: false,
};

export const mockUserAnalytics: UserAnalytics = {
  total_views: 100,
  total_posts: 10,
  total_likes_received: 50,
  total_reposts_received: 20,
};

export const mockBlockedUser: BlockedUser = {
  id: 1,
  username: 'blockeduser',
  display_name: 'Blocked User',
  avatar_url: 'https://example.com/avatar.png',
  blocked_at: '2024-01-01T00:00:00Z',
};

export const mockMutedUser: MutedUser = {
  id: 1,
  username: 'muteduser',
  display_name: 'Muted User',
  avatar_url: 'https://example.com/avatar.png',
  muted_at: '2024-01-01T00:00:00Z',
};

export const mockLlmProvider: LlmProvider = {
  id: 'openai',
  label: 'OpenAI',
  description: 'OpenAI GPT models',
  default_model: 'gpt-4',
  supports_custom_base_url: true,
};

export const mockLlmConfigSummary: LlmConfigSummary = {
  provider: 'openai',
  configured: true,
  masked_api_key: 'sk-***...***',
  model: 'gpt-4',
  is_default: true,
  updated_at: '2024-01-01T00:00:00Z',
};

export const mockLlmChatResponse: LlmChatResponse = {
  provider: 'openai',
  model: 'gpt-4',
  reply: 'This is a test response',
};

export function createMockFetch(overrides: Record<string, any> = {}) {
  return vi.fn((url: string, options?: RequestInit) => {
    const method = options?.method || 'GET';
    const path = url.replace('/api', '');
    
    // Check for specific endpoints
    for (const [pattern, response] of Object.entries(overrides)) {
      if (path.match(new RegExp(pattern))) {
        return Promise.resolve({
          ok: true,
          status: 200,
          json: () => Promise.resolve(typeof response === 'function' ? response() : response),
          text: () => Promise.resolve(JSON.stringify(typeof response === 'function' ? response() : response)),
        });
      }
    }

    // Default responses
    const defaultResponses: Record<string, any> = {
      'POST:/auth/login': mockUser,
      'POST:/auth/register': mockUser,
      'POST:/auth/logout': { deleted: true },
      'GET:/auth/me': mockUser,
      'GET:/health': {
        status: 'ok',
        service: 'xeetapus',
        checked_at: '2024-01-01 00:00:00',
        response_ms: 5,
        uptime_percentage: 100,
        checks: 1,
        history: [
          {
            status: 'ok',
            service: 'xeetapus',
            checked_at: '2024-01-01 00:00:00',
            response_ms: 5,
          },
        ],
      },
      'GET:/posts': [mockPost],
      'GET:/posts/\\d+': mockPost,
      'DELETE:/posts/\\d+': { deleted: true },
      'POST:/posts': { id: 1, content: 'Test', created: true },
      'POST:/posts/\\d+/like': { liked: true },
      'DELETE:/posts/\\d+/like': { unliked: true },
      'GET:/users/\\w+': mockProfile,
      'GET:/timeline': [mockPost],
      'GET:/notifications': [mockNotification],
    };

    const key = `${method}:${path}`;
    const response = defaultResponses[key] || null;

    return Promise.resolve({
      ok: true,
      status: 200,
      json: () => Promise.resolve(response),
      text: () => Promise.resolve(JSON.stringify(response)),
    });
  });
}
