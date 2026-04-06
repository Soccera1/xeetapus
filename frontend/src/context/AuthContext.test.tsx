import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider, useAuth } from '../context/AuthContext';
import { api } from '../api';
import type { User } from '../types';

// Mock the api module
vi.mock('../api', () => ({
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

const mockUser: User = {
  id: 1,
  username: 'testuser',
  email: 'test@example.com',
  display_name: 'Test User',
  bio: 'Test bio',
  avatar_url: 'https://example.com/avatar.png',
  created_at: '2024-01-01T00:00:00Z',
  token: 'test-token',
};

function wrapper({ children }: { children: React.ReactNode }) {
  return (
    <BrowserRouter>
      <AuthProvider>{children}</AuthProvider>
    </BrowserRouter>
  );
}

describe('AuthContext', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('AuthProvider', () => {
    it('should provide initial state', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.me).mockResolvedValue(mockUser);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(result.current.user).toBe(null);
      expect(result.current.isAuthenticated).toBe(false);
    });

    it('should load user on mount if authenticated', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(result.current.user).toEqual(mockUser);
      expect(result.current.isAuthenticated).toBe(true);
      expect(api.me).toHaveBeenCalled();
    });

    it('should handle authentication error on mount', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockRejectedValue(new Error('Unauthorized'));
      vi.mocked(api.logout).mockResolvedValue(undefined);
      vi.mocked(api.clearToken).mockReturnValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(result.current.user).toBe(null);
      expect(result.current.isAuthenticated).toBe(false);
    });

    it('should not call api.me if not authenticated', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(api.me).not.toHaveBeenCalled();
      expect(result.current.user).toBe(null);
    });
  });

  describe('login', () => {
    it('should login successfully', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.login).mockResolvedValue(mockUser);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      await act(async () => {
        await result.current.login('testuser', 'password123');
      });

      expect(api.login).toHaveBeenCalledWith({
        username: 'testuser',
        password: 'password123',
      });
      expect(result.current.user).toEqual(mockUser);
      expect(result.current.isAuthenticated).toBe(true);
    });

    it('should handle login error', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.login).mockRejectedValue(new Error('Invalid credentials'));

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      await expect(async () => {
        await act(async () => {
          await result.current.login('testuser', 'wrongpassword');
        });
      }).rejects.toThrow('Invalid credentials');

      expect(result.current.user).toBe(null);
      expect(result.current.isAuthenticated).toBe(false);
    });
  });

  describe('register', () => {
    it('should register successfully', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.register).mockResolvedValue(mockUser);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      await act(async () => {
        await result.current.register('testuser', 'test@example.com', 'password123');
      });

      expect(api.register).toHaveBeenCalledWith({
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
      });
      expect(result.current.user).toEqual(mockUser);
      expect(result.current.isAuthenticated).toBe(true);
    });

    it('should handle registration error', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.register).mockRejectedValue(new Error('Username already exists'));

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      await expect(async () => {
        await act(async () => {
          await result.current.register('testuser', 'test@example.com', 'password123');
        });
      }).rejects.toThrow('Username already exists');

      expect(result.current.user).toBe(null);
      expect(result.current.isAuthenticated).toBe(false);
    });
  });

  describe('logout', () => {
    it('should logout successfully', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.logout).mockResolvedValue(undefined);
      vi.mocked(api.clearToken).mockReturnValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(result.current.user).toEqual(mockUser);
      expect(result.current.isAuthenticated).toBe(true);

      await act(async () => {
        result.current.logout();
      });

      await waitFor(() => {
        expect(result.current.user).toBe(null);
        expect(result.current.isAuthenticated).toBe(false);
      });

      expect(api.logout).toHaveBeenCalled();
    });
  });

  describe('useAuth hook', () => {
    it('should throw error when used outside AuthProvider', () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
      
      expect(() => {
        renderHook(() => useAuth());
      }).toThrow('useAuth must be used within an AuthProvider');

      consoleError.mockRestore();
    });
  });

  describe('integration scenarios', () => {
    it('should handle complete login flow', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.login).mockResolvedValue(mockUser);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      expect(result.current.isAuthenticated).toBe(false);
      expect(result.current.user).toBe(null);

      await act(async () => {
        await result.current.login('testuser', 'password123');
      });

      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.user).toEqual(mockUser);
    });

    it('should handle login then logout flow', async () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.login).mockResolvedValue(mockUser);
      vi.mocked(api.logout).mockResolvedValue(undefined);
      vi.mocked(api.clearToken).mockReturnValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // Login
      await act(async () => {
        await result.current.login('testuser', 'password123');
      });

      expect(result.current.isAuthenticated).toBe(true);
      expect(result.current.user).toEqual(mockUser);

      // Logout
      act(() => {
        result.current.logout();
      });

      await waitFor(() => {
        expect(result.current.isAuthenticated).toBe(false);
        expect(result.current.user).toBe(null);
      });
    });

    it('should handle multiple login attempts', async () => {
      const anotherUser: User = {
        ...mockUser,
        id: 2,
        username: 'anotheruser',
        email: 'another@example.com',
      };

      vi.mocked(api.isAuthenticated).mockReturnValue(false);
      vi.mocked(api.login)
        .mockResolvedValueOnce(mockUser)
        .mockResolvedValueOnce(anotherUser);
      vi.mocked(api.logout).mockResolvedValue(undefined);
      vi.mocked(api.clearToken).mockReturnValue(undefined);

      const { result } = renderHook(() => useAuth(), { wrapper });

      await waitFor(() => {
        expect(result.current.isLoading).toBe(false);
      });

      // First login
      await act(async () => {
        await result.current.login('testuser', 'password123');
      });

      expect(result.current.user).toEqual(mockUser);

      // Logout
      act(() => {
        result.current.logout();
      });

      await waitFor(() => {
        expect(result.current.user).toBe(null);
      });

      // Second login
      await act(async () => {
        await result.current.login('anotheruser', 'password123');
      });

      expect(result.current.user).toEqual(anotherUser);
    });
  });
});
