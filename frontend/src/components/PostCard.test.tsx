import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { PostCard } from './PostCard';
import { useAuth } from '../context/AuthContext';
import { api } from '../api';
import type { Post } from '../types';

// Mock modules
vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../api', () => ({
  api: {
    likePost: vi.fn(),
    unlikePost: vi.fn(),
    repostPost: vi.fn(),
    unrepostPost: vi.fn(),
    bookmarkPost: vi.fn(),
    unbookmarkPost: vi.fn(),
    deletePost: vi.fn(),
    pinPost: vi.fn(),
    unpinPost: vi.fn(),
    recordPostView: vi.fn(),
    voteOnPoll: vi.fn(),
    getPollResults: vi.fn(),
  },
}));

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

const mockPost: Post = {
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
  likes_count: 10,
  comments_count: 5,
  reposts_count: 2,
  view_count: 100,
};

const mockUser = {
  id: 1,
  username: 'testuser',
  email: 'test@example.com',
  display_name: 'Test User',
  created_at: '2024-01-01T00:00:00Z',
};

function renderPostCard(post: Post = mockPost) {
  return render(
    <BrowserRouter>
      <PostCard post={post} />
    </BrowserRouter>
  );
}

describe('PostCard', () => {
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

  describe('Rendering', () => {
    it('should render post content', () => {
      renderPostCard();

      expect(screen.getByText('Test post content')).toBeInTheDocument();
      expect(screen.getByText('Test User')).toBeInTheDocument();
      expect(screen.getByText('@testuser')).toBeInTheDocument();
    });

    it('should render avatar', () => {
      renderPostCard();

      expect(screen.getByAltText('testuser')).toBeInTheDocument();
    });

    it('should render like, repost, comment buttons', () => {
      renderPostCard();

      expect(screen.getByRole('button', { name: /like/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /repost/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /comment/i })).toBeInTheDocument();
    });

    it('should render bookmark button', () => {
      renderPostCard();

      expect(screen.getByRole('button', { name: /bookmark/i })).toBeInTheDocument();
    });

    it('should render view count', () => {
      renderPostCard();

      expect(screen.getByText('100')).toBeInTheDocument();
    });

    it('should display like count', () => {
      renderPostCard();

      expect(screen.getByText('10')).toBeInTheDocument();
    });

    it('should display repost count', () => {
      renderPostCard();

      expect(screen.getByText('2')).toBeInTheDocument();
    });

    it('should display comment count', () => {
      renderPostCard();

      expect(screen.getByText('5')).toBeInTheDocument();
    });

    it('should show pinned indicator for pinned posts', () => {
      const pinnedPost = { ...mockPost, is_pinned: true };
      renderPostCard(pinnedPost);

      expect(screen.getByText('Pinned post')).toBeInTheDocument();
    });

    it('should show reply indicator for reply posts', () => {
      const replyPost = { ...mockPost, reply_to_id: 123 };
      renderPostCard(replyPost);

      expect(screen.getByText('Replying to a post')).toBeInTheDocument();
    });

    it('should show delete button for own posts', () => {
      renderPostCard();

      expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
    });

    it('should not show delete button for other users posts', () => {
      vi.mocked(useAuth).mockReturnValue({
        user: { ...mockUser, id: 2 },
        isAuthenticated: true,
        login: vi.fn(),
        register: vi.fn(),
        logout: vi.fn(),
        isLoading: false,
      });

      renderPostCard();

      expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument();
    });
  });

  describe('Interactions', () => {
    describe('Like functionality', () => {
      it('should like a post', async () => {
        vi.mocked(api.likePost).mockResolvedValue({ liked: true });

        renderPostCard();

        const likeButton = screen.getByRole('button', { name: /like/i });
        fireEvent.click(likeButton);

        await waitFor(() => {
          expect(api.likePost).toHaveBeenCalledWith(1);
        });
      });

      it('should unlike a post', async () => {
        vi.mocked(api.unlikePost).mockResolvedValue({ unliked: true });
        const likedPost = { ...mockPost, is_liked: true, likes_count: 11 };

        renderPostCard(likedPost);

        const likeButton = screen.getByRole('button', { name: /like/i });
        fireEvent.click(likeButton);

        await waitFor(() => {
          expect(api.unlikePost).toHaveBeenCalledWith(1);
        });
      });

      it('should update like count after liking', async () => {
        vi.mocked(api.likePost).mockResolvedValue({ liked: true });

        renderPostCard();

        const likeButton = screen.getByRole('button', { name: /like/i });
        fireEvent.click(likeButton);

        await waitFor(() => {
          expect(screen.getByText('11')).toBeInTheDocument();
        });
      });

      it('should show error on like failure', async () => {
        vi.mocked(api.likePost).mockRejectedValue(new Error('Failed to like'));
        const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});

        renderPostCard();

        const likeButton = screen.getByRole('button', { name: /like/i });
        fireEvent.click(likeButton);

        await waitFor(() => {
          expect(alertSpy).toHaveBeenCalledWith('Failed to like');
        });

        alertSpy.mockRestore();
      });
    });

    describe('Repost functionality', () => {
      it('should repost a post', async () => {
        vi.mocked(api.repostPost).mockResolvedValue({ reposted: true, is_reposted: true, reposts_count: 3 });

        renderPostCard();

        const repostButton = screen.getByRole('button', { name: /repost/i });
        fireEvent.click(repostButton);

        await waitFor(() => {
          expect(api.repostPost).toHaveBeenCalledWith(1);
        });
      });

      it('should unrepost a post', async () => {
        vi.mocked(api.unrepostPost).mockResolvedValue({ unreposted: true, is_reposted: false, reposts_count: 1 });
        const repostedPost = { ...mockPost, is_reposted: true, reposts_count: 2 };

        renderPostCard(repostedPost);

        const repostButton = screen.getByRole('button', { name: /repost/i });
        fireEvent.click(repostButton);

        await waitFor(() => {
          expect(api.unrepostPost).toHaveBeenCalledWith(1);
        });
      });

      it('should prevent multiple reposts while processing', async () => {
        vi.mocked(api.repostPost).mockImplementation(() => new Promise<{ reposted: boolean; is_reposted: boolean; reposts_count: number }>(() => {}));

        renderPostCard();

        const repostButton = screen.getByRole('button', { name: /repost/i });
        fireEvent.click(repostButton);
        fireEvent.click(repostButton);

        await waitFor(() => {
          expect(api.repostPost).toHaveBeenCalledTimes(1);
        });
      });
    });

    describe('Bookmark functionality', () => {
      it('should bookmark a post', async () => {
        vi.mocked(api.bookmarkPost).mockResolvedValue({ bookmarked: true });

        renderPostCard();

        const bookmarkButton = screen.getByRole('button', { name: /bookmark/i });
        fireEvent.click(bookmarkButton);

        await waitFor(() => {
          expect(api.bookmarkPost).toHaveBeenCalledWith(1);
        });
      });

      it('should unbookmark a post', async () => {
        vi.mocked(api.unbookmarkPost).mockResolvedValue({ unbookmarked: true });
        const bookmarkedPost = { ...mockPost, is_bookmarked: true };

        renderPostCard(bookmarkedPost);

        const bookmarkButton = screen.getByRole('button', { name: /bookmark/i });
        fireEvent.click(bookmarkButton);

        await waitFor(() => {
          expect(api.unbookmarkPost).toHaveBeenCalledWith(1);
        });
      });
    });

    describe('Delete functionality', () => {
      it('should delete a post after confirmation', async () => {
        vi.mocked(api.deletePost).mockResolvedValue({ deleted: true });
        vi.spyOn(window, 'confirm').mockReturnValue(true);

        const onDelete = vi.fn();
        render(
          <BrowserRouter>
            <PostCard post={mockPost} onDelete={onDelete} />
          </BrowserRouter>
        );

        const deleteButton = screen.getByRole('button', { name: /delete/i });
        fireEvent.click(deleteButton);

        await waitFor(() => {
          expect(api.deletePost).toHaveBeenCalledWith(1);
          expect(onDelete).toHaveBeenCalledWith(1);
        });
      });

      it('should not delete if not confirmed', async () => {
        vi.spyOn(window, 'confirm').mockReturnValue(false);

        renderPostCard();

        const deleteButton = screen.getByRole('button', { name: /delete/i });
        fireEvent.click(deleteButton);

        expect(api.deletePost).not.toHaveBeenCalled();
      });
    });

    describe('Pin functionality', () => {
      it('should pin a post', async () => {
        vi.mocked(api.pinPost).mockResolvedValue({ pinned: true });
        const onUpdate = vi.fn();

        render(
          <BrowserRouter>
            <PostCard post={mockPost} onUpdate={onUpdate} />
          </BrowserRouter>
        );

        const pinButton = screen.getByRole('button', { name: /pin/i });
        fireEvent.click(pinButton);

        await waitFor(() => {
          expect(api.pinPost).toHaveBeenCalledWith(1);
        });
      });

      it('should unpin a post', async () => {
        vi.mocked(api.unpinPost).mockResolvedValue({ unpinned: true });
        const pinnedPost = { ...mockPost, is_pinned: true };
        const onUpdate = vi.fn();

        render(
          <BrowserRouter>
            <PostCard post={pinnedPost} onUpdate={onUpdate} />
          </BrowserRouter>
        );

        const pinButton = screen.getByRole('button', { name: /unpin/i });
        fireEvent.click(pinButton);

        await waitFor(() => {
          expect(api.unpinPost).toHaveBeenCalledWith(1);
        });
      });
    });

    describe('Reply and Quote', () => {
      it('should navigate to post detail on reply', () => {
        renderPostCard();

        const replyButton = screen.getByRole('button', { name: /comment/i });
        fireEvent.click(replyButton);

        expect(mockNavigate).toHaveBeenCalledWith('/post/1');
      });

      it('should navigate with quote post on quote', () => {
        renderPostCard();

        const quoteButton = screen.getByRole('button', { name: /quote/i });
        fireEvent.click(quoteButton);

        expect(mockNavigate).toHaveBeenCalledWith('/timeline', { state: { quotePost: mockPost } });
      });
    });
  });

  describe('Media Display', () => {
    it('should display images', () => {
      const postWithMedia = {
        ...mockPost,
        media_urls: 'https://example.com/image1.jpg,https://example.com/image2.jpg',
      };

      renderPostCard(postWithMedia);

      expect(screen.getByAltText('Media 1')).toBeInTheDocument();
      expect(screen.getByAltText('Media 2')).toBeInTheDocument();
    });
  });

  describe('Poll Display', () => {
    it('should display poll with options', () => {
      const postWithPoll = {
        ...mockPost,
        poll: {
          id: 1,
          post_id: 1,
          question: 'Test poll?',
          duration_minutes: 60,
          created_at: '2024-01-01T00:00:00Z',
          options: [
            { id: 1, poll_id: 1, option_text: 'Option 1', position: 1, vote_count: 10 },
            { id: 2, poll_id: 1, option_text: 'Option 2', position: 2, vote_count: 5 },
          ],
          has_voted: false,
        },
      };

      renderPostCard(postWithPoll);

      expect(screen.getByText('Test poll?')).toBeInTheDocument();
      expect(screen.getByText('Option 1')).toBeInTheDocument();
      expect(screen.getByText('Option 2')).toBeInTheDocument();
    });

    it('should handle vote on poll', async () => {
      vi.mocked(api.voteOnPoll).mockResolvedValue({ message: 'Vote recorded' });
      vi.mocked(api.getPollResults).mockResolvedValue({
        options: [
          { id: 1, poll_id: 1, option_text: 'Option 1', position: 1, vote_count: 11 },
          { id: 2, poll_id: 1, option_text: 'Option 2', position: 2, vote_count: 5 },
        ],
        total_votes: 16,
      });

      const postWithPoll = {
        ...mockPost,
        poll: {
          id: 1,
          post_id: 1,
          question: 'Test poll?',
          duration_minutes: 60,
          created_at: '2024-01-01T00:00:00Z',
          options: [
            { id: 1, poll_id: 1, option_text: 'Option 1', position: 1, vote_count: 10 },
            { id: 2, poll_id: 1, option_text: 'Option 2', position: 2, vote_count: 5 },
          ],
          has_voted: false,
        },
      };

      renderPostCard(postWithPoll);

      const option1 = screen.getByText('Option 1');
      fireEvent.click(option1);

      await waitFor(() => {
        expect(api.voteOnPoll).toHaveBeenCalledWith(1, 1);
      });
    });
  });

  describe('Time Formatting', () => {
    it('should format recent time as minutes', () => {
      const recentPost = {
        ...mockPost,
        created_at: new Date(Date.now() - 5 * 60000).toISOString().slice(0, -1),
      };

      renderPostCard(recentPost);

      expect(screen.getByText(/5m/)).toBeInTheDocument();
    });

    it('should format time as hours', () => {
      const hourPost = {
        ...mockPost,
        created_at: new Date(Date.now() - 2 * 3600000).toISOString().slice(0, -1),
      };

      renderPostCard(hourPost);

      expect(screen.getByText(/2h/)).toBeInTheDocument();
    });

    it('should format time as days', () => {
      const dayPost = {
        ...mockPost,
        created_at: new Date(Date.now() - 3 * 86400000).toISOString().slice(0, -1),
      };

      renderPostCard(dayPost);

      expect(screen.getByText(/3d/)).toBeInTheDocument();
    });
  });

  describe('Number Formatting', () => {
    it('should format thousands with K', async () => {
      vi.mocked(api.likePost).mockResolvedValue({ liked: true });
      const popularPost = {
        ...mockPost,
        likes_count: 1500,
      };

      renderPostCard(popularPost);

      expect(screen.getByText('1.5K')).toBeInTheDocument();
    });

    it('should format millions with M', () => {
      const viralPost = {
        ...mockPost,
        likes_count: 2500000,
      };

      renderPostCard(viralPost);

      expect(screen.getByText('2.5M')).toBeInTheDocument();
    });
  });
});
