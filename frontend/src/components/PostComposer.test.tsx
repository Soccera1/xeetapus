import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { PostComposer } from './PostComposer';
import { useAuth } from '../context/AuthContext';
import { api } from '../api';

// Mock modules
vi.mock('../context/AuthContext', () => ({
  useAuth: vi.fn(),
}));

vi.mock('../api', () => ({
  api: {
    createPost: vi.fn(),
    uploadMedia: vi.fn(),
  },
}));

const mockUser = {
  id: 1,
  username: 'testuser',
  email: 'test@example.com',
  display_name: 'Test User',
  avatar_url: 'https://example.com/avatar.png',
  created_at: '2024-01-01T00:00:00Z',
};

function renderPostComposer(props = {}) {
  const defaultProps = {
    onPostCreated: vi.fn(),
  };

  return render(
    <BrowserRouter>
      <PostComposer {...defaultProps} {...props} />
    </BrowserRouter>
  );
}

describe('PostComposer', () => {
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
  });

  describe('Rendering', () => {
    it('should render compose form', () => {
      renderPostComposer();

      expect(screen.getByPlaceholderText("What's happening?")).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /post/i })).toBeInTheDocument();
    });

    it('should render character counter', () => {
      renderPostComposer();

      expect(screen.getByText('0/280')).toBeInTheDocument();
    });

    it('should render media upload button', () => {
      renderPostComposer();

      expect(screen.getByRole('button', { name: /image/i })).toBeInTheDocument();
    });

    it('should render poll button', () => {
      renderPostComposer();

      expect(screen.getByRole('button', { name: /poll/i })).toBeInTheDocument();
    });

    it('should render user avatar', () => {
      renderPostComposer();

      expect(screen.getByAltText('')).toBeInTheDocument();
    });

    it('should show reply context when replying', () => {
      const replyToPost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ replyToId: 123, replyToPost });

      expect(screen.getByText('Replying to')).toBeInTheDocument();
      expect(screen.getByText('@otheruser')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Post your reply')).toBeInTheDocument();
    });

    it('should show quote post context', () => {
      const quotePost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post to quote',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ quotePost });

      expect(screen.getByText('Quoting')).toBeInTheDocument();
      expect(screen.getByText('Original post to quote')).toBeInTheDocument();
    });
  });

  describe('Text Input', () => {
    it('should update content on typing', () => {
      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      expect(textarea).toHaveValue('Test post');
      expect(screen.getByText('9/280')).toBeInTheDocument();
    });

    it('should limit to 280 characters', () => {
      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?") as HTMLTextAreaElement;
      const longText = 'a'.repeat(281);

      fireEvent.change(textarea, { target: { value: longText } });

      expect(textarea.value.length).toBe(280);
    });

    it('should show warning when approaching character limit', () => {
      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'a'.repeat(265) } });

      expect(screen.getByText('265/280')).toHaveClass('text-yellow-500');
    });
  });

  describe('Post Submission', () => {
    it('should submit post on button click', async () => {
      vi.mocked(api.createPost).mockResolvedValue({ id: 1, content: 'Test post', created: true });
      const onPostCreated = vi.fn();

      renderPostComposer({ onPostCreated });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(api.createPost).toHaveBeenCalledWith({
          content: 'Test post',
          media_urls: undefined,
          reply_to_id: undefined,
          quote_to_id: undefined,
        });
        expect(onPostCreated).toHaveBeenCalled();
      });
    });

    it('should disable submit button when empty', () => {
      renderPostComposer();

      const postButton = screen.getByRole('button', { name: /post/i });
      expect(postButton).toBeDisabled();
    });

    it('should disable submit button when over character limit', () => {
      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'a'.repeat(281) } });

      const postButton = screen.getByRole('button', { name: /post/i });
      expect(postButton).toBeDisabled();
    });

    it('should clear form after successful submission', async () => {
      vi.mocked(api.createPost).mockResolvedValue({ id: 1, content: 'Test post', created: true });
      const onPostCreated = vi.fn();

      renderPostComposer({ onPostCreated });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(textarea).toHaveValue('');
        expect(screen.getByText('0/280')).toBeInTheDocument();
      });
    });

    it('should show loading state while submitting', async () => {
      vi.mocked(api.createPost).mockImplementation(() => new Promise<{ id: number; content: string; created: boolean }>(() => {}));

      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(postButton).toHaveTextContent('Posting...');
        expect(postButton).toBeDisabled();
      });
    });

    it('should handle submission errors', async () => {
      vi.mocked(api.createPost).mockRejectedValue(new Error('Failed to create post'));
      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});

      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Failed to create post');
      });

      alertSpy.mockRestore();
    });

    it('should submit reply with reply_to_id', async () => {
      vi.mocked(api.createPost).mockResolvedValue({ id: 2, content: 'Reply', created: true });
      const onPostCreated = vi.fn();
      const replyToPost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ replyToId: 123, replyToPost, onPostCreated });

      const textarea = screen.getByPlaceholderText('Post your reply');
      fireEvent.change(textarea, { target: { value: '@otheruser Test reply' } });

      const replyButton = screen.getByRole('button', { name: /reply/i });
      fireEvent.click(replyButton);

      await waitFor(() => {
        expect(api.createPost).toHaveBeenCalledWith({
          content: '@otheruser Test reply',
          media_urls: undefined,
          reply_to_id: 123,
          quote_to_id: undefined,
        });
      });
    });

    it('should submit quote post', async () => {
      vi.mocked(api.createPost).mockResolvedValue({ id: 2, content: 'Quote', created: true });
      const onPostCreated = vi.fn();
      const quotePost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ quotePost, onPostCreated });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'My quote comment' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(api.createPost).toHaveBeenCalledWith({
          content: 'My quote comment',
          media_urls: undefined,
          reply_to_id: undefined,
          quote_to_id: 123,
        });
      });
    });
  });

  describe('Media Upload', () => {
    it('should handle file selection', async () => {
      renderPostComposer();

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const fileInput = document.getElementById('media-upload') as HTMLInputElement;

      Object.defineProperty(fileInput, 'files', {
        value: [file],
      });

      fireEvent.change(fileInput);

      await waitFor(() => {
        expect(screen.getByAltText('Preview 1')).toBeInTheDocument();
      });
    });

    it('should limit file count to 4', async () => {
      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      renderPostComposer();

      const fileInput = document.getElementById('media-upload') as HTMLInputElement;
      const files = [
        new File(['1'], '1.jpg', { type: 'image/jpeg' }),
        new File(['2'], '2.jpg', { type: 'image/jpeg' }),
        new File(['3'], '3.jpg', { type: 'image/jpeg' }),
        new File(['4'], '4.jpg', { type: 'image/jpeg' }),
        new File(['5'], '5.jpg', { type: 'image/jpeg' }),
      ];

      Object.defineProperty(fileInput, 'files', {
        value: files,
      });

      fireEvent.change(fileInput);

      expect(alertSpy).toHaveBeenCalledWith('You can only upload up to 4 images/videos');
      alertSpy.mockRestore();
    });

    it('should upload files when submitting', async () => {
      vi.mocked(api.uploadMedia).mockResolvedValue({ url: 'https://example.com/test.jpg', filename: 'test.jpg' });
      vi.mocked(api.createPost).mockResolvedValue({ id: 1, content: 'Test', created: true });

      renderPostComposer();

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const fileInput = document.getElementById('media-upload') as HTMLInputElement;

      Object.defineProperty(fileInput, 'files', {
        value: [file],
      });

      fireEvent.change(fileInput);

      await waitFor(() => {
        expect(screen.getByAltText('Preview 1')).toBeInTheDocument();
      });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Test post' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(api.uploadMedia).toHaveBeenCalled();
        expect(api.createPost).toHaveBeenCalledWith(
          expect.objectContaining({
            content: 'Test post',
            media_urls: 'https://example.com/test.jpg',
          })
        );
      });
    });

    it('should remove uploaded file', async () => {
      renderPostComposer();

      const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
      const fileInput = document.getElementById('media-upload') as HTMLInputElement;

      Object.defineProperty(fileInput, 'files', {
        value: [file],
      });

      fireEvent.change(fileInput);

      await waitFor(() => {
        expect(screen.getByAltText('Preview 1')).toBeInTheDocument();
      });

      const removeButton = screen.getByRole('button', { name: /x/i });
      fireEvent.click(removeButton);

      expect(screen.queryByAltText('Preview 1')).not.toBeInTheDocument();
    });
  });

  describe('Poll Creation', () => {
    it('should show poll form when poll button clicked', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      expect(screen.getByText('Create a poll')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Option 1')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Option 2')).toBeInTheDocument();
    });

    it('should add poll option', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const addButton = screen.getByRole('button', { name: /add option/i });
      fireEvent.click(addButton);

      expect(screen.getByPlaceholderText('Option 3')).toBeInTheDocument();
    });

    it('should not add more than 4 options', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const addButton = screen.getByRole('button', { name: /add option/i });
      fireEvent.click(addButton);
      fireEvent.click(addButton);

      expect(screen.queryByPlaceholderText('Option 5')).not.toBeInTheDocument();
    });

    it('should remove poll option', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const addButton = screen.getByRole('button', { name: /add option/i });
      fireEvent.click(addButton);

      expect(screen.getByPlaceholderText('Option 3')).toBeInTheDocument();

      const removeButtons = screen.getAllByRole('button', { name: /trash/i });
      fireEvent.click(removeButtons[2]);

      expect(screen.queryByPlaceholderText('Option 3')).not.toBeInTheDocument();
    });

    it('should not remove option when only 2 exist', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const removeButtons = screen.getAllByRole('button', { name: /trash/i });
      expect(removeButtons.length).toBe(0);
    });

    it('should update poll option text', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const option1Input = screen.getByPlaceholderText('Option 1');
      fireEvent.change(option1Input, { target: { value: 'First option' } });

      expect(option1Input).toHaveValue('First option');
    });

    it('should select poll duration', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const durationSelect = screen.getByRole('combobox');
      fireEvent.change(durationSelect, { target: { value: '60' } });

      expect(durationSelect).toHaveValue('60');
    });

    it('should hide poll when poll button clicked again', () => {
      renderPostComposer();

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      expect(screen.getByText('Create a poll')).toBeInTheDocument();

      fireEvent.click(pollButton);

      expect(screen.queryByText('Create a poll')).not.toBeInTheDocument();
    });

    it('should submit post with poll', async () => {
      vi.mocked(api.createPost).mockResolvedValue({ id: 1, content: 'Test', created: true });
      const onPostCreated = vi.fn();

      renderPostComposer({ onPostCreated });

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'What is your favorite color?' } });

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const option1Input = screen.getByPlaceholderText('Option 1');
      const option2Input = screen.getByPlaceholderText('Option 2');

      fireEvent.change(option1Input, { target: { value: 'Red' } });
      fireEvent.change(option2Input, { target: { value: 'Blue' } });

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(api.createPost).toHaveBeenCalledWith({
          content: 'What is your favorite color?',
          media_urls: undefined,
          reply_to_id: undefined,
          quote_to_id: undefined,
          poll: {
            question: 'What is your favorite color?',
            options: ['Red', 'Blue'],
            duration_minutes: 1440,
          },
        });
      });
    });

    it('should require at least 2 poll options', async () => {
      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      vi.mocked(api.createPost).mockResolvedValue({ id: 1, content: 'Test', created: true });

      renderPostComposer();

      const textarea = screen.getByPlaceholderText("What's happening?");
      fireEvent.change(textarea, { target: { value: 'Poll question' } });

      const pollButton = screen.getByRole('button', { name: /poll/i });
      fireEvent.click(pollButton);

      const option1Input = screen.getByPlaceholderText('Option 1');
      fireEvent.change(option1Input, { target: { value: 'Option 1' } });
      // Leave option 2 empty

      const postButton = screen.getByRole('button', { name: /post/i });
      fireEvent.click(postButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Please provide at least 2 poll options');
      });

      alertSpy.mockRestore();
    });

    it('should disable poll button when quoting', () => {
      const quotePost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ quotePost });

      const pollButton = screen.getByRole('button', { name: /poll/i });
      expect(pollButton).toBeDisabled();
    });
  });

  describe('Quote Post', () => {
    it('should clear quote post when X clicked', () => {
      const quotePost = {
        id: 123,
        user_id: 2,
        username: 'otheruser',
        display_name: 'Other User',
        content: 'Original post to quote',
        avatar_url: '',
        is_liked: false,
        is_reposted: false,
        is_bookmarked: false,
        created_at: '2024-01-01T00:00:00Z',
        likes_count: 0,
        comments_count: 0,
        reposts_count: 0,
      };

      renderPostComposer({ quotePost });

      expect(screen.getByText('Quoting')).toBeInTheDocument();

      const clearButton = screen.getByRole('button', { name: /x/i });
      fireEvent.click(clearButton);

      expect(screen.queryByText('Quoting')).not.toBeInTheDocument();
    });
  });
});
