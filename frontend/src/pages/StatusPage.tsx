import { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle2, Clock3, RefreshCw, Server, WifiOff, Activity } from 'lucide-react';
import { api } from '../api';
import type { HealthStatus } from '../types';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';

type ServiceState = 'operational' | 'degraded' | 'down';

function parseHealthTimestamp(value: string) {
    const normalized = value.includes('T') ? value : `${value.replace(' ', 'T')}Z`;
    const parsed = new Date(normalized);
    return Number.isNaN(parsed.getTime())
        ? value
        : new Intl.DateTimeFormat(undefined, {
            dateStyle: 'medium',
            timeStyle: 'short',
        }).format(parsed);
}

function stateLabel(state: ServiceState) {
    if (state === 'operational') return 'Operational';
    if (state === 'degraded') return 'Degraded';
    return 'Down';
}

function stateFromStatus(status: string): ServiceState {
    if (status === 'ok' || status === 'operational') return 'operational';
    if (status === 'degraded') return 'degraded';
    return 'down';
}

function stateStyles(state: ServiceState) {
    if (state === 'operational') return 'border-emerald-500/30 bg-emerald-500/10 text-emerald-200';
    if (state === 'degraded') return 'border-amber-500/30 bg-amber-500/10 text-amber-200';
    return 'border-rose-500/30 bg-rose-500/10 text-rose-200';
}

export function StatusPage() {
    const [health, setHealth] = useState<HealthStatus | null>(null);
    const [apiState, setApiState] = useState<ServiceState>('degraded');
    const [frontendState, setFrontendState] = useState<ServiceState>('operational');
    const [message, setMessage] = useState('Checking service health...');
    const [isLoading, setIsLoading] = useState(true);

    const checkStatus = async () => {
        setIsLoading(true);
        try {
            const response = await api.getHealth();
            setHealth(response);
            setApiState(stateFromStatus(response.status));
            setMessage(`Recorded ${response.checks} checks with ${response.uptime_percentage.toFixed(1)}% uptime across recent samples.`);
        } catch {
            setHealth(null);
            setApiState('down');
            setMessage('The API health check is unavailable right now.');
        } finally {
            setFrontendState(navigator.onLine ? 'operational' : 'down');
            setIsLoading(false);
        }
    };

    useEffect(() => {
        void checkStatus();
    }, []);

    const overallState: ServiceState =
        apiState === 'down' || frontendState === 'down'
            ? 'down'
            : apiState === 'degraded' || frontendState === 'degraded'
                ? 'degraded'
                : 'operational';

    const history = health?.history ?? [];
    const latestCheckedAt = health?.checked_at ?? null;
    const uptimePercentage = health?.uptime_percentage ?? 0;

    return (
        <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-b from-background via-background to-slate-950">
            <div className="mx-auto flex max-w-4xl flex-col gap-8 px-4 py-10">
                <section className="overflow-hidden rounded-3xl border border-border/70 bg-card/80 shadow-2xl shadow-slate-950/30 backdrop-blur">
                    <div className="relative px-6 py-8 sm:px-10 sm:py-12">
                        <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(34,197,94,0.18),transparent_35%),radial-gradient(circle_at_bottom_left,rgba(56,189,248,0.16),transparent_30%)]" />
                        <div className="relative flex flex-col gap-6">
                            <div className="flex flex-wrap items-center gap-3">
                                <span className={`inline-flex items-center gap-2 rounded-full border px-3 py-1 text-sm font-medium ${stateStyles(overallState)}`}>
                                    <Server className="h-4 w-4" />
                                    {stateLabel(overallState)}
                                </span>
                                <span className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/80 px-3 py-1 text-sm text-muted-foreground">
                                    <Clock3 className="h-4 w-4" />
                                    Last checked {latestCheckedAt ? parseHealthTimestamp(latestCheckedAt) : 'Not checked yet'}
                                </span>
                            </div>

                            <div className="max-w-2xl space-y-4">
                                <p className="text-sm uppercase tracking-[0.3em] text-muted-foreground">
                                    Xeetapus status
                                </p>
                                <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
                                    Service health, in one place.
                                </h1>
                                <p className="text-base text-muted-foreground sm:text-lg">
                                    Live availability plus a recent history of checks stored by the backend.
                                </p>
                            </div>

                            <div className="flex flex-wrap items-center gap-3">
                                <Button onClick={() => void checkStatus()} disabled={isLoading} className="gap-2">
                                    <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
                                    Refresh status
                                </Button>
                                <span className="text-sm text-muted-foreground">
                                    {message}
                                </span>
                            </div>
                        </div>
                    </div>
                </section>

                <section className="grid gap-4 md:grid-cols-3">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                                <CheckCircle2 className="h-4 w-4" />
                                API
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2">
                            <div className="text-2xl font-bold">{stateLabel(apiState)}</div>
                            <p className="text-sm text-muted-foreground">
                                Backend health endpoint at <code className="rounded bg-muted px-1 py-0.5 text-xs">/api/health</code>
                            </p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                                <WifiOff className="h-4 w-4" />
                                Frontend
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2">
                            <div className="text-2xl font-bold">{stateLabel(frontendState)}</div>
                            <p className="text-sm text-muted-foreground">
                                Browser connectivity and app shell availability
                            </p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
                                <Activity className="h-4 w-4" />
                                Recent uptime
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2">
                            <div className="text-2xl font-bold">
                                {health ? `${uptimePercentage.toFixed(1)}%` : '—'}
                            </div>
                            <p className="text-sm text-muted-foreground">
                                {health ? `${health.checks} checks in the recent window` : 'No health history available yet'}
                            </p>
                        </CardContent>
                    </Card>
                </section>

                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Clock3 className="h-4 w-4" />
                            Recent checks
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {history.length === 0 ? (
                            <p className="text-sm text-muted-foreground">
                                No check history recorded yet.
                            </p>
                        ) : (
                            <div className="space-y-3">
                                {history.map((entry) => {
                                    const entryState = stateFromStatus(entry.status);

                                    return (
                                        <div
                                            key={`${entry.checked_at}-${entry.response_ms}`}
                                            className="flex flex-col gap-2 rounded-lg border border-border/70 bg-muted/20 p-4 sm:flex-row sm:items-center sm:justify-between"
                                        >
                                            <div className="space-y-1">
                                                <div className="flex flex-wrap items-center gap-2">
                                                    <span className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${stateStyles(entryState)}`}>
                                                        {stateLabel(entryState)}
                                                    </span>
                                                    <span className="text-sm text-muted-foreground">
                                                        {entry.service}
                                                    </span>
                                                </div>
                                                <p className="text-sm text-muted-foreground">
                                                    {parseHealthTimestamp(entry.checked_at)}
                                                </p>
                                            </div>
                                            <div className="text-sm font-medium">
                                                {entry.response_ms} ms
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        )}
                    </CardContent>
                </Card>

                {message && !health && (
                    <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-100">
                        <div className="flex items-center gap-2 font-medium">
                            <AlertTriangle className="h-4 w-4" />
                            Status check unavailable
                        </div>
                        <p className="mt-1 text-amber-100/90">{message}</p>
                    </div>
                )}
            </div>
        </div>
    );
}
