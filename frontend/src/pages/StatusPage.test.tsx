import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { StatusPage } from './StatusPage';
import { api } from '../api';

vi.mock('../api', () => ({
  api: {
    getHealth: vi.fn(),
  },
}));

describe('StatusPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    Object.defineProperty(window.navigator, 'onLine', {
      configurable: true,
      value: true,
    });
  });

  it('shows the current service status', async () => {
    vi.mocked(api.getHealth).mockResolvedValue({
      status: 'ok',
      service: 'xeetapus',
      checked_at: '2026-04-15 18:00:00',
      response_ms: 7,
      uptime_percentage: 100,
      checks: 1,
      history: [
        {
          status: 'ok',
          service: 'xeetapus',
          checked_at: '2026-04-15 18:00:00',
          response_ms: 7,
        },
      ],
    });

    render(<StatusPage />);

    await waitFor(() => {
      expect(screen.getByText('Operational')).toBeInTheDocument();
    });

    expect(screen.getByText('Xeetapus status')).toBeInTheDocument();
    expect(screen.getByText('Refresh status')).toBeInTheDocument();
    expect(screen.getByText('/api/health')).toBeInTheDocument();
    expect(screen.getByText('Recent checks')).toBeInTheDocument();
  });

  it('falls back to down when the health check fails', async () => {
    vi.mocked(api.getHealth).mockRejectedValue(new Error('Network error'));

    render(<StatusPage />);

    await waitFor(() => {
      expect(screen.getAllByText('Down').length).toBeGreaterThan(0);
    });

    expect(screen.getAllByText('The API health check is unavailable right now.').length).toBeGreaterThan(0);
  });
});
