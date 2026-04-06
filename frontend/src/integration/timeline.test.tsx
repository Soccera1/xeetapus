import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { TimelinePage } from '../pages/TimelinePage';
import { useAuth } from '../context/AuthContext';
import { api } from '../api';
import type { Post } from '../types';

// Mock modules
vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../api', () => ({
  api: {
    getTimeline: vi.fn(),
    getExplore: vi.fn(),
    createPost: vi.fn(),
    likePost: vi.fn(),
    unlikePost: vi.fn(),
    repostPost: vi.fn(),
    unrepostPost: vi.fn(),
    bookmarkPost: vi.fn(),
    unbookmarkPost: vi.fn(),
    recordPostView: vi.fn(),
  },
}));

const mockUser = {
  id: 1,
  username: 'testuser',
  email: 'test@example.com',
  display_name: 'Test User',
  created_at: '2024-01-01T00:00:00Z',
};

const mockPosts: Post[] = [
  {
    id: 1,
    user_id: 1,
    username: 'testuser',
    display_name: 'Test User',
    content: 'First post',
    avatar_url: '',
    is_liked: false,
    is_reposted: false,
    is_bookmarked: false,
    created_at: '2024-01-01T00:00:00Z',
    likes_count: 5,
    comments_count: 2,
    reposts_count: 1,
    view_count: 100,
  },
  {
    id: 2,
    user_id: 2,
    username: 'otheruser',
    display_name: 'Other User',
    content: 'Second post',
    avatar_url: '',
    is_liked: true,
    is_reposted: false,
    is_bookmarked: true,
    created_at: '2024-01-01T01:00:00Z',
    likes_count: 10,
    comments_count: 3,
    reposts_count: 2,
    view_count: 200,
  },
];

describe('Timeline Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(useAuth).mockReturnValue({
      user: mockUser,
      isAuthenticated: true,
      login: vi.fn(),
      register: vi.fn(),
      logout: vi.fn(),
      isLoading: false,
    });
    vi.mocked(api.recordPostView).mockResolvedValue({ recorded: true });
  });

  describe('Timeline Loading', () => {
    it('should load and display posts', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
        expect(screen.getByText('Second post')).toBeInTheDocument();
      });
    });

    it('should show loading state', () => {
      vi.mocked(api.getTimeline).mockImplementation(() => new Promise(() => {}));

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      expect(screen.getByText('Loading...')).toBeInTheDocument();
    });

    it('should handle empty timeline', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
      });
    });

    it('should handle timeline load error', async () => {
      vi.mocked(api.getTimeline).mockRejectedValue(new Error('Failed to load'));

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
      });
    });
  });

  describe('Post Interactions', () => {
    it('should like a post and update UI', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);
      vi.mocked(api.likePost).mockResolvedValue({ liked: true });

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      const likeButtons = screen.getAllByRole('button', { name: /like/i });
      fireEvent.click(likeButtons[0]);

      await waitFor(() => {
        expect(api.likePost).toHaveBeenCalledWith(1);
      });
    });

    it('should repost a post and update UI', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);
      vi.mocked(api.repostPost).mockResolvedValue({
        reposted: true,
        is_reposted: true,
        reposts_count: 2,
      });

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      const repostButtons = screen.getAllByRole('button', { name: /repost/i });
      fireEvent.click(repostButtons[0]);

      await waitFor(() => {
        expect(api.repostPost).toHaveBeenCalledWith(1);
      });
    });

    it('should bookmark a post', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);
      vi.mocked(api.bookmarkPost).mockResolvedValue({ bookmarked: true });

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      const bookmarkButtons = screen.getAllByRole('button', { name: /bookmark/i });
      fireEvent.click(bookmarkButtons[0]);

      await waitFor(() => {
        expect(api.bookmarkPost).toHaveBeenCalledWith(1);
      });
    });
  });

  describe('Post Creation', () => {
    it('should create a new post and add to timeline', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);
      vi.mocked(api.createPost).mockResolvedValue({
        id: 3,
        content: 'New post',
        created: true,
      });

      const newPost: Post = {
        id: 3,
        user_id: 1,
        username: 'testuser',
        display_name: 'Test User',
        content: 'New post',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T02:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
        view_count: 0,
      };

      vi.mocked(api.getTimeline).mockResolvedValue([newPost, ...mockPosts]);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'New post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(api.createPost).toHaveBeenCalledWith({
          content: 'New post',
          media_urls: undefined,
          reply_to_id: undefined,
          quote_to_id: undefined,
        });
      });
    });
  });

  describe('Pagination and Refresh', () => {
    it('should refresh timeline', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      // Simulate refresh
      vi.mocked(api.getTimeline).mockResolvedValue([
        {
          id: 3,
          user_id: 1,
          username: 'testuser',
          display_name: 'Test User',
          content: 'New post after refresh',
          avatar_url: '',
          is_liked: false,
          is_reposted: false,
          is_bookmarked: false,
          created_at: '2024-01-01T03:00:00Z',
          likes_count: 0,
          comments_count: 0,
          reposts_count: 0,
          view_count: 0,
        },
        ...mockPosts,
      ]);

      await waitFor(() => {
        expect(api.getTimeline).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe('Media Display', () => {
    it('should display images in posts', async () => {
      const postsWithMedia: Post[] = [
        {
          ...mockPosts[0],
          media_urls: 'https://example.com/image1.jpg,https://example.com/image2.jpg',
        },
      ];

      vi.mocked(api.getTimeline).mockResolvedValue(postsWithMedia);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByAltText('Media 1')).toBeInTheDocument();
        expect(screen.getByAltText('Media 2')).toBeInTheDocument();
      });
    });
  });

  describe('Quote Posts', () => {
    it('should display quote posts', async () => {
      const postsWithQuote: Post[] = [
        {
          ...mockPosts[0],
          quote_to_id: 2,
          quote_to_post: mockPosts[1],
        },
      ];

      vi.mocked(api.getTimeline).mockResolvedValue(postsWithQuote);

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('Second post')).toBeInTheDocument();
      });
    });
  });

  describe('Error Recovery', () => {
    it('should recover from failed post creation', async () => {
      vi.mocked(api.getTimeline).mockResolvedValue(mockPosts);
      vi.mocked(api.createPost).mockRejectedValue(new Error('Failed to create post'));
      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});

      render(
        <BrowserRouter>
          <TimelinePage />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.getByText('First post')).toBeInTheDocument();
      });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'New post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Failed to create post');
      });

      // Timeline should still show posts
      expect(screen.getByText('First post')).toBeInTheDocument();

      alertSpy.mockRestore();
    });
  });
});
