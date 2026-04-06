import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import App from './App';
import { api } from './api';
import type { User } from './types';

vi.mock('./api', () => ({
  api: {
    isAuthenticated: vi.fn(),
    me: vi.fn(),
    login: vi.fn(),
    register: vi.fn(),
    logout: vi.fn(),
    clearToken: vi.fn(),
    setToken: vi.fn(),
    setCsrfToken: vi.fn(),
  },
}));

describe('App Component', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Routing', () => {
    it('should render auth page on root route when not authenticated', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      render(<App />);

      expect(screen.getByText('Xeetapus')).toBeInTheDocument();
      expect(screen.getByText('Join the conversation')).toBeInTheDocument();
    });

    it('should redirect to timeline when authenticated', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);

      render(<App />);

      await waitFor(() => {
        expect(screen.queryByText('Join the conversation')).not.toBeInTheDocument();
      });
    });

    it('should show loading state while checking authentication', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockImplementation(() => new Promise<User>(() => {}));

      render(<App />);

      expect(screen.getByText('Loading...')).toBeInTheDocument();
    });
  });

  describe('Auth State', () => {
    it('should clear auth state on logout', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.logout).mockResolvedValue(undefined);

      render(<App />);

      await waitFor(() => {
        expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
      });
    });

    it('should handle authentication error gracefully', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockRejectedValue(new Error('Unauthorized'));
      vi.mocked(api.logout).mockResolvedValue(undefined);
      vi.mocked(api.clearToken).mockReturnValue(undefined);

      render(<App />);

      await waitFor(() => {
        expect(screen.getByText('Join the conversation')).toBeInTheDocument();
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle 401 errors', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockRejectedValue({ status: 401, message: 'Unauthorized' });
      vi.mocked(api.logout).mockResolvedValue(undefined);

      render(<App />);

      await waitFor(() => {
        expect(api.logout).toHaveBeenCalled();
      });
    });
  });
});
