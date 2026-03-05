import { useState, useEffect } from 'react';
import { api } from '../api';
import type { Hashtag } from '../types';
import { Card, CardContent } from '../components/ui/card';
import { TrendingUp, Hash } from 'lucide-react';
import { Link } from 'react-router-dom';

export function TrendingPage() {
    const [trending, setTrending] = useState<Hashtag[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        loadTrending();
    }, []);

    const loadTrending = async () => {
        try {
            const data = await api.getTrendingHashtags();
            setTrending(data.trending);
        } catch (err) {
            setError('Failed to load trending hashtags');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <TrendingUp className="w-6 h-6" />
                Trending
            </h1>

            {trending.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <Hash className="w-12 h-12 mx-auto mb-4" />
                        <p>No trending hashtags yet</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="space-y-2">
                    {trending.map((hashtag, index) => (
                        <Card key={hashtag.id}>
                            <CardContent className="p-4">
                                <Link 
                                    to={`/hashtag/${hashtag.tag}`}
                                    className="flex items-center justify-between hover:bg-muted p-2 rounded-lg transition-colors"
                                >
                                    <div className="flex items-center gap-4">
                                        <span className="text-2xl font-bold text-muted-foreground w-8">
                                            {index + 1}
                                        </span>
                                        <div>
                                            <p className="font-semibold text-lg">
                                                #{hashtag.tag}
                                            </p>
                                            <p className="text-sm text-muted-foreground">
                                                {hashtag.use_count.toLocaleString()} posts
                                            </p>
                                        </div>
                                    </div>
                                    <Hash className="w-5 h-5 text-muted-foreground" />
                                </Link>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
