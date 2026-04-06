import { useEffect, useState } from 'react';
import { api } from '../api';
import type { Post } from '../types';
import { PostCard } from '../components/PostCard';

export function ExplorePage() {
    const [posts, setPosts] = useState<Post[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        const loadPosts = async () => {
            try {
                setIsLoading(true);
                const data = await api.getExplore();
                setPosts(data);
                setError('');
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to load posts');
            } finally {
                setIsLoading(false);
            }
        };

        loadPosts();
    }, []);

    const handlePostUpdate = (updatedPost: Post) => {
        setPosts(prev => prev.map(p => p.id === updatedPost.id ? updatedPost : p));
    };

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Explore</h1>
            
            {isLoading ? (
                <div className="text-center py-12 text-muted-foreground">Loading...</div>
            ) : error ? (
                <div className="text-center py-12 text-destructive">{error}</div>
            ) : posts.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">No posts yet.</div>
            ) : (
                <div className="space-y-4">
                    {posts.map(post => (
                        <PostCard 
                            key={post.id} 
                            post={post}
                            onUpdate={handlePostUpdate}
                        />
                    ))}
                </div>
            )}
        </div>
    );
}
