import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ApiClient } from './api';
import { mockUser, mockPost, mockProfile, mockNotification, mockCommunity, mockConversation, mockMessage, mockUserList, mockHashtag, mockDraft, mockScheduledPost, mockUserAnalytics } from './test/mocks/api';

describe('ApiClient', () => {
  let api: ApiClient;
  let fetchMock: any;

  beforeEach(() => {
    api = new ApiClient();
    fetchMock = vi.fn();
    globalThis.fetch = fetchMock;
    localStorage.clear();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('Authentication', () => {
    describe('register', () => {
      it('should register a new user', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ ...mockUser, token: 'new-token', csrf_token: 'csrf-token' }),
        });

        const result = await api.register({
          username: 'newuser',
          email: 'new@example.com',
          password: 'password123',
        });

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/auth/register',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include',
          })
        );
        expect(result).toEqual({ ...mockUser, token: 'new-token', csrf_token: 'csrf-token' });
      });

      it('should handle registration errors', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: false,
          status: 400,
          text: async () => JSON.stringify({ error: 'Username already exists' }),
        });

        await expect(api.register({
          username: 'existinguser',
          email: 'test@example.com',
          password: 'password123',
        })).rejects.toThrow('Username already exists');
      });
    });

    describe('login', () => {
      it('should login successfully', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ ...mockUser, token: 'login-token', csrf_token: 'csrf-token' }),
        });

        const result = await api.login({
          username: 'testuser',
          password: 'password123',
        });

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/auth/login',
          expect.objectContaining({
            method: 'POST',
          })
        );
        expect(result).toEqual({ ...mockUser, token: 'login-token', csrf_token: 'csrf-token' });
      });

      it('should handle login errors', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: false,
          status: 401,
          text: async () => JSON.stringify({ error: 'Invalid credentials' }),
        });

        await expect(api.login({
          username: 'testuser',
          password: 'wrongpassword',
        })).rejects.toThrow('Invalid credentials');
      });
    });

    describe('logout', () => {
      it('should logout and clear token', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({}),
        });

        await api.logout();

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/auth/logout',
          expect.objectContaining({
            method: 'POST',
          })
        );
      });
    });

    describe('me', () => {
      it('should get current user', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => mockUser,
        });

        const result = await api.me();

        expect(fetchMock).toHaveBeenCalledWith('/api/auth/me', expect.any(Object));
        expect(result).toEqual(mockUser);
      });
    });
  });

  describe('Posts', () => {
    describe('createPost', () => {
      it('should create a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ id: 1, content: 'Test post', created: true }),
        });

        const result = await api.createPost({ content: 'Test post' });

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/posts',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ content: 'Test post' }),
          })
        );
        expect(result).toEqual({ id: 1, content: 'Test post', created: true });
      });
    });

    describe('getPosts', () => {
      it('should get all posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockPost],
        });

        const result = await api.getPosts();

        expect(result).toEqual([mockPost]);
      });
    });

    describe('getPost', () => {
      it('should get a single post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => mockPost,
        });

        const result = await api.getPost(1);

        expect(result).toEqual(mockPost);
      });
    });

    describe('deletePost', () => {
      it('should delete a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ deleted: true }),
        });

        const result = await api.deletePost(1);

        expect(result).toEqual({ deleted: true });
      });
    });

    describe('likePost', () => {
      it('should like a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ liked: true }),
        });

        const result = await api.likePost(1);

        expect(result).toEqual({ liked: true });
      });
    });

    describe('unlikePost', () => {
      it('should unlike a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ unliked: true }),
        });

        const result = await api.unlikePost(1);

        expect(result).toEqual({ unliked: true });
      });
    });

    describe('repostPost', () => {
      it('should repost a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ reposted: true, is_reposted: true, reposts_count: 1 }),
        });

        const result = await api.repostPost(1);

        expect(result).toEqual({ reposted: true, is_reposted: true, reposts_count: 1 });
      });
    });

    describe('bookmarkPost', () => {
      it('should bookmark a post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ bookmarked: true }),
        });

        const result = await api.bookmarkPost(1);

        expect(result).toEqual({ bookmarked: true });
      });
    });
  });

  describe('Users', () => {
    describe('getProfile', () => {
      it('should get user profile', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => mockProfile,
        });

        const result = await api.getProfile('testuser');

        expect(result).toEqual(mockProfile);
      });
    });

    describe('getUserPosts', () => {
      it('should get user posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockPost],
        });

        const result = await api.getUserPosts('testuser');

        expect(result).toEqual([mockPost]);
      });
    });

    describe('followUser', () => {
      it('should follow a user', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ following: true }),
        });

        const result = await api.followUser('otheruser');

        expect(result).toEqual({ following: true });
      });
    });

    describe('unfollowUser', () => {
      it('should unfollow a user', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ unfollowed: true }),
        });

        const result = await api.unfollowUser('otheruser');

        expect(result).toEqual({ unfollowed: true });
      });
    });
  });

  describe('Timeline', () => {
    describe('getTimeline', () => {
      it('should get timeline posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockPost],
        });

        const result = await api.getTimeline();

        expect(result).toEqual([mockPost]);
      });
    });

    describe('getExplore', () => {
      it('should get explore posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockPost],
        });

        const result = await api.getExplore();

        expect(result).toEqual([mockPost]);
      });
    });
  });

  describe('Notifications', () => {
    describe('getNotifications', () => {
      it('should get notifications', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockNotification],
        });

        const result = await api.getNotifications();

        expect(result).toEqual([mockNotification]);
      });
    });

    describe('markNotificationAsRead', () => {
      it('should mark notification as read', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ read: true }),
        });

        const result = await api.markNotificationAsRead(1);

        expect(result).toEqual({ read: true });
      });
    });
  });

  describe('Search', () => {
    describe('searchUsers', () => {
      it('should search users', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockUser],
        });

        const result = await api.searchUsers('test');

        expect(result).toEqual([mockUser]);
      });

      it('should encode query parameters', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [],
        });

        await api.searchUsers(' test user ');

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/search/users?q=%20test%20user%20',
          expect.any(Object)
        );
      });
    });

    describe('searchPosts', () => {
      it('should search posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockPost],
        });

        const result = await api.searchPosts('test');

        expect(result).toEqual([mockPost]);
      });
    });
  });

  describe('Communities', () => {
    describe('getCommunities', () => {
      it('should get communities', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => [mockCommunity],
        });

        const result = await api.getCommunities();

        expect(result).toEqual([mockCommunity]);
      });
    });

    describe('joinCommunity', () => {
      it('should join a community', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ joined: true }),
        });

        const result = await api.joinCommunity(1);

        expect(result).toEqual({ joined: true });
      });
    });
  });

  describe('Messages', () => {
    describe('getConversations', () => {
      it('should get conversations', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ conversations: [mockConversation] }),
        });

        const result = await api.getConversations();

        expect(result).toEqual({ conversations: [mockConversation] });
      });
    });

    describe('getMessages', () => {
      it('should get messages for a conversation', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ messages: [mockMessage] }),
        });

        const result = await api.getMessages(1);

        expect(result).toEqual({ messages: [mockMessage] });
      });
    });

    describe('sendMessage', () => {
      it('should send a message', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ id: 1, message: 'Message sent' }),
        });

        const result = await api.sendMessage(1, 'Hello');

        expect(result).toEqual({ id: 1, message: 'Message sent' });
      });
    });
  });

  describe('Lists', () => {
    describe('getLists', () => {
      it('should get user lists', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ lists: [mockUserList] }),
        });

        const result = await api.getLists();

        expect(result).toEqual({ lists: [mockUserList] });
      });
    });

    describe('createList', () => {
      it('should create a list', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ id: 1, message: 'List created' }),
        });

        const result = await api.createList('My List', 'Description', false);

        expect(fetchMock).toHaveBeenCalledWith(
          '/api/lists',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({
              name: 'My List',
              description: 'Description',
              is_private: false,
            }),
          })
        );
        expect(result).toEqual({ id: 1, message: 'List created' });
      });
    });
  });

  describe('Hashtags', () => {
    describe('getTrendingHashtags', () => {
      it('should get trending hashtags', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ trending: [mockHashtag] }),
        });

        const result = await api.getTrendingHashtags();

        expect(result).toEqual({ trending: [mockHashtag] });
      });
    });

    describe('getPostsByHashtag', () => {
      it('should get posts by hashtag', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ posts: [mockPost], hashtag: 'test' }),
        });

        const result = await api.getPostsByHashtag('test');

        expect(result).toEqual({ posts: [mockPost], hashtag: 'test' });
      });
    });
  });

  describe('Drafts', () => {
    describe('getDrafts', () => {
      it('should get drafts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ drafts: [mockDraft] }),
        });

        const result = await api.getDrafts();

        expect(result).toEqual({ drafts: [mockDraft] });
      });
    });

    describe('createDraft', () => {
      it('should create a draft', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ id: 1, message: 'Draft created' }),
        });

        const result = await api.createDraft('Draft content');

        expect(result).toEqual({ id: 1, message: 'Draft created' });
      });
    });

    describe('deleteDraft', () => {
      it('should delete a draft', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ message: 'Draft deleted' }),
        });

        const result = await api.deleteDraft(1);

        expect(result).toEqual({ message: 'Draft deleted' });
      });
    });
  });

  describe('Scheduled Posts', () => {
    describe('getScheduledPosts', () => {
      it('should get scheduled posts', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ scheduled_posts: [mockScheduledPost] }),
        });

        const result = await api.getScheduledPosts();

        expect(result).toEqual({ scheduled_posts: [mockScheduledPost] });
      });
    });

    describe('createScheduledPost', () => {
      it('should create a scheduled post', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ id: 1, message: 'Post scheduled' }),
        });

        const result = await api.createScheduledPost('Content', '2024-12-31T00:00:00Z');

        expect(result).toEqual({ id: 1, message: 'Post scheduled' });
      });
    });
  });

  describe('Analytics', () => {
    describe('getUserAnalytics', () => {
      it('should get user analytics', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => mockUserAnalytics,
        });

        const result = await api.getUserAnalytics();

        expect(result).toEqual(mockUserAnalytics);
      });
    });

    describe('getPostViews', () => {
      it('should get post view count', async () => {
        fetchMock.mockResolvedValueOnce({
          ok: true,
          status: 200,
          json: async () => ({ view_count: 100 }),
        });

        const result = await api.getPostViews(1);

        expect(result).toEqual({ view_count: 100 });
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle rate limiting (429)', async () => {
      fetchMock.mockResolvedValueOnce({
        ok: false,
        status: 429,
        headers: new Headers({ 'Retry-After': '60' }),
        text: async () => 'Rate limit exceeded',
      });

      await expect(api.getPosts()).rejects.toMatchObject({
        message: 'Rate limit exceeded. Please try again later.',
        retryAfter: '60',
        status: 429,
      });
    });

    it('should handle unauthorized (401)', async () => {
      fetchMock.mockResolvedValueOnce({
        ok: false,
        status: 401,
        text: async () => JSON.stringify({ error: 'Unauthorized' }),
      });

      const dispatchEventSpy = vi.spyOn(window, 'dispatchEvent');

      await expect(api.getPosts()).rejects.toThrow('Unauthorized');
      expect(dispatchEventSpy).toHaveBeenCalledWith(expect.any(CustomEvent));
    });

    it('should handle server errors (500)', async () => {
      fetchMock.mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => JSON.stringify({ error: 'Internal server error' }),
      });

      await expect(api.getPosts()).rejects.toThrow('Internal server error');
    });
  });

  describe('CSRF Token', () => {
    it('should add CSRF token to state-changing requests', async () => {
      api.setCsrfToken('test-csrf-token');

      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ id: 1, created: true }),
      });

      await api.createPost({ content: 'Test' });

      const callArgs = fetchMock.mock.calls[0];
      expect(callArgs[1].headers).toMatchObject({
        'Content-Type': 'application/json',
        'X-CSRF-Token': 'test-csrf-token',
      });
    });

    it('should not add CSRF token to GET requests', async () => {
      api.setCsrfToken('test-csrf-token');

      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => [mockPost],
      });

      await api.getPosts();

      const callArgs = fetchMock.mock.calls[0];
      expect(callArgs[1].headers).not.toHaveProperty('X-CSRF-Token');
      expect(callArgs[1].method || 'GET').toBe('GET');
    });
  });

  describe('uploadMedia', () => {
    it('should upload a file', async () => {
      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      
      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ url: 'https://example.com/test.jpg', filename: 'test.jpg' }),
      });

      const result = await api.uploadMedia(file);

      expect(result).toEqual({ url: 'https://example.com/test.jpg', filename: 'test.jpg' });
    });

    it('should upload a profile image', async () => {
      const file = new File(['test'], 'avatar.jpg', { type: 'image/jpeg' });
      
      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ url: 'https://example.com/avatar.jpg', filename: 'avatar.jpg' }),
      });

      const result = await api.uploadMedia(file, true);

      expect(result).toEqual({ url: 'https://example.com/avatar.jpg', filename: 'avatar.jpg' });
    });
  });
});
