import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { render } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import App from '../App';
import { api } from '../api';

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
    getTimeline: vi.fn(),
    getExplore: vi.fn(),
    getPosts: vi.fn(),
  },
}));

const mockReload = vi.fn();
Object.defineProperty(window, 'location', {
  value: {
    reload: mockReload,
  },
  writable: true,
});

describe('Authentication Flow Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Unauthenticated User', () => {
    it('should redirect to auth page', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      render(<App />);

      expect(screen.getByText('Join the conversation')).toBeInTheDocument();
    });

    it('should show login form by default', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      render(<App />);

      expect(screen.getByRole('tab', { name: 'Login' })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: 'Register' })).toBeInTheDocument();
    });
  });

  describe('Login Flow', () => {
    beforeEach(() => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
    });

    it('should successfully login and redirect to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.login).mockResolvedValue(mockUser);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(<App />);

      const usernameInput = screen.getByLabelText('Username');
      const passwordInput = screen.getByLabelText('Password');
      const loginButton = screen.getByRole('button', { name: 'Login' });

      await userEvent.type(usernameInput, 'testuser');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(loginButton);

      await waitFor(() => {
        expect(api.login).toHaveBeenCalledWith({
          username: 'testuser',
          password: 'password123',
        });
      });
    });

    it('should show error message on failed login', async () => {
      vi.mocked(api.login).mockRejectedValue(new Error('Invalid credentials'));

      render(<App />);

      const usernameInput = screen.getByLabelText('Username');
      const passwordInput = screen.getByLabelText('Password');
      const loginButton = screen.getByRole('button', { name: 'Login' });

      await userEvent.type(usernameInput, 'testuser');
      await userEvent.type(passwordInput, 'wrongpassword');
      await userEvent.click(loginButton);

      await waitFor(() => {
        expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
      });
    });
  });

  describe('Registration Flow', () => {
    beforeEach(() => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
    });

    it('should successfully register and redirect to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'newuser',
        email: 'new@example.com',
        display_name: 'New User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.register).mockResolvedValue(mockUser);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(<App />);

      const registerTab = screen.getByRole('tab', { name: 'Register' });
      await userEvent.click(registerTab);

      const usernameInput = screen.getByLabelText('Username');
      const emailInput = screen.getByLabelText('Email');
      const passwordInput = screen.getByLabelText('Password');
      const registerButton = screen.getByRole('button', { name: 'Register' });

      await userEvent.type(usernameInput, 'newuser');
      await userEvent.type(emailInput, 'new@example.com');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(registerButton);

      await waitFor(() => {
        expect(api.register).toHaveBeenCalledWith({
          username: 'newuser',
          email: 'new@example.com',
          password: 'password123',
        });
      });
    });

    it('should show error message on failed registration', async () => {
      vi.mocked(api.register).mockRejectedValue(new Error('Username already exists'));

      render(<App />);

      const registerTab = screen.getByRole('tab', { name: 'Register' });
      await userEvent.click(registerTab);

      const usernameInput = screen.getByLabelText('Username');
      const emailInput = screen.getByLabelText('Email');
      const passwordInput = screen.getByLabelText('Password');
      const registerButton = screen.getByRole('button', { name: 'Register' });

      await userEvent.type(usernameInput, 'existinguser');
      await userEvent.type(emailInput, 'test@example.com');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(registerButton);

      await waitFor(() => {
        expect(screen.getByText('Username already exists')).toBeInTheDocument();
      });
    });
  });

  describe('Protected Routes', () => {
    it('should redirect unauthenticated user from timeline to auth page', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      window.history.pushState({}, '', '/timeline');

      render(<App />);

      expect(screen.getByText('Join the conversation')).toBeInTheDocument();
    });

    it('should redirect authenticated user from auth page to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(<App />);

      await waitFor(() => {
        expect(screen.queryByText('Join the conversation')).not.toBeInTheDocument();
      });
    });
  });
});

describe('Authentication Flow Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Unauthenticated User', () => {
    it('should redirect to auth page', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      expect(screen.getByText('Join the conversation')).toBeInTheDocument();
    });

    it('should show login form by default', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      expect(screen.getByRole('tab', { name: 'Login' })).toBeInTheDocument();
      expect(screen.getByRole('tab', { name: 'Register' })).toBeInTheDocument();
    });
  });

  describe('Login Flow', () => {
    beforeEach(() => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
    });

    it('should successfully login and redirect to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.login).mockResolvedValue(mockUser);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      const usernameInput = screen.getByLabelText('Username');
      const passwordInput = screen.getByLabelText('Password');
      const loginButton = screen.getByRole('button', { name: 'Login' });

      await userEvent.type(usernameInput, 'testuser');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(loginButton);

      await waitFor(() => {
        expect(api.login).toHaveBeenCalledWith({
          username: 'testuser',
          password: 'password123',
        });
      });
    });

    it('should show error message on failed login', async () => {
      vi.mocked(api.login).mockRejectedValue(new Error('Invalid credentials'));

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      const usernameInput = screen.getByLabelText('Username');
      const passwordInput = screen.getByLabelText('Password');
      const loginButton = screen.getByRole('button', { name: 'Login' });

      await userEvent.type(usernameInput, 'testuser');
      await userEvent.type(passwordInput, 'wrongpassword');
      await userEvent.click(loginButton);

      await waitFor(() => {
        expect(screen.getByText('Invalid credentials')).toBeInTheDocument();
      });
    });
  });

  describe('Registration Flow', () => {
    beforeEach(() => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);
    });

    it('should successfully register and redirect to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'newuser',
        email: 'new@example.com',
        display_name: 'New User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.register).mockResolvedValue(mockUser);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      const registerTab = screen.getByRole('tab', { name: 'Register' });
      await userEvent.click(registerTab);

      const usernameInput = screen.getByLabelText('Username');
      const emailInput = screen.getByLabelText('Email');
      const passwordInput = screen.getByLabelText('Password');
      const registerButton = screen.getByRole('button', { name: 'Register' });

      await userEvent.type(usernameInput, 'newuser');
      await userEvent.type(emailInput, 'new@example.com');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(registerButton);

      await waitFor(() => {
        expect(api.register).toHaveBeenCalledWith({
          username: 'newuser',
          email: 'new@example.com',
          password: 'password123',
        });
      });
    });

    it('should show error message on failed registration', async () => {
      vi.mocked(api.register).mockRejectedValue(new Error('Username already exists'));

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      const registerTab = screen.getByRole('tab', { name: 'Register' });
      await userEvent.click(registerTab);

      const usernameInput = screen.getByLabelText('Username');
      const emailInput = screen.getByLabelText('Email');
      const passwordInput = screen.getByLabelText('Password');
      const registerButton = screen.getByRole('button', { name: 'Register' });

      await userEvent.type(usernameInput, 'existinguser');
      await userEvent.type(emailInput, 'test@example.com');
      await userEvent.type(passwordInput, 'password123');
      await userEvent.click(registerButton);

      await waitFor(() => {
        expect(screen.getByText('Username already exists')).toBeInTheDocument();
      });
    });
  });

  describe('Protected Routes', () => {
    it('should redirect unauthenticated user from timeline to auth page', () => {
      vi.mocked(api.isAuthenticated).mockReturnValue(false);

      window.history.pushState({}, '', '/timeline');

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      expect(screen.getByText('Join the conversation')).toBeInTheDocument();
    });

    it('should redirect authenticated user from auth page to timeline', async () => {
      const mockUser = {
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        display_name: 'Test User',
        created_at: '2024-01-01T00:00:00Z',
      };

      vi.mocked(api.isAuthenticated).mockReturnValue(true);
      vi.mocked(api.me).mockResolvedValue(mockUser);
      vi.mocked(api.getTimeline).mockResolvedValue([]);

      render(
        <BrowserRouter>
          <App />
        </BrowserRouter>
      );

      await waitFor(() => {
        expect(screen.queryByText('Join the conversation')).not.toBeInTheDocument();
      });
    });
  });
});
