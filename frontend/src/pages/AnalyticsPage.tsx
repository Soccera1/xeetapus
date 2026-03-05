import { useState, useEffect } from 'react';
import { api } from '../api';
import type { UserAnalytics } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Eye, FileText, Heart, Repeat, BarChart3 } from 'lucide-react';

export function AnalyticsPage() {
    const [analytics, setAnalytics] = useState<UserAnalytics | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        loadAnalytics();
    }, []);

    const loadAnalytics = async () => {
        try {
            const data = await api.getUserAnalytics();
            setAnalytics(data);
        } catch (err) {
            setError('Failed to load analytics');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;
    if (!analytics) return <div className="text-center py-12">Failed to load analytics</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <BarChart3 className="w-6 h-6" />
                Analytics
            </h1>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">
                            Total Views
                        </CardTitle>
                        <Eye className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold">
                            {analytics.total_views.toLocaleString()}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Across all your posts
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">
                            Total Posts
                        </CardTitle>
                        <FileText className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold">
                            {analytics.total_posts.toLocaleString()}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Posts you've created
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">
                            Likes Received
                        </CardTitle>
                        <Heart className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold">
                            {analytics.total_likes_received.toLocaleString()}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Total likes on your posts
                        </p>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium">
                            Reposts Received
                        </CardTitle>
                        <Repeat className="h-4 w-4 text-muted-foreground" />
                    </CardHeader>
                    <CardContent>
                        <div className="text-2xl font-bold">
                            {analytics.total_reposts_received.toLocaleString()}
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Times your posts were reposted
                        </p>
                    </CardContent>
                </Card>
            </div>

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
