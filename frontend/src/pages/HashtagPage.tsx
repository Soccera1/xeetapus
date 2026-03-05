import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api';
import type { Post as PostType } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Hash } from 'lucide-react';
import { PostCard } from '../components/PostCard';

export function HashtagPage() {
    const { tag } = useParams<{ tag: string }>();
    const [posts, setPosts] = useState<PostType[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        if (tag) {
            loadPosts();
        }
    }, [tag]);

    const loadPosts = async () => {
        try {
            const data = await api.getPostsByHashtag(tag!);
            setPosts(data.posts);
        } catch (err) {
            setError('Failed to load posts');
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <Card className="mb-6">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-2xl">
                        <Hash className="w-6 h-6" />
                        {tag}
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <p className="text-muted-foreground">
                        {posts.length} post{posts.length !== 1 ? 's' : ''}
                    </p>
                </CardContent>
            </Card>

            {posts.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <Hash className="w-12 h-12 mx-auto mb-4" />
                        <p>No posts with #{tag} yet</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="space-y-4">
                    {posts.map((post) => (
                        <PostCard key={post.id} post={post} />
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
