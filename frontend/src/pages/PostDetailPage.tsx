import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { api } from '../api';
import type { Post, Comment } from '../types';
import { PostCard } from '../components/PostCard';
import { PostComposer } from '../components/PostComposer';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';

import { ArrowLeft, Loader2 } from 'lucide-react';

export function PostDetailPage() {
    const { id } = useParams<{ id: string }>();
    const [post, setPost] = useState<Post | null>(null);
    const [_replies, setReplies] = useState<Post[]>([]);
    const [parentPosts, setParentPosts] = useState<Post[]>([]);
    const [comments, setComments] = useState<Comment[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        if (!id) return;

        const loadData = async () => {
            try {
                setIsLoading(true);
                const postId = parseInt(id);

                // Load main post
                const postData = await api.getPost(postId);
                setPost(postData);

                // Load parent posts if this is a reply
                const parents: Post[] = [];
                let currentPost = postData;
                while (currentPost.reply_to_id) {
                    try {
                        const parent = await api.getPost(currentPost.reply_to_id);
                        parents.unshift(parent);
                        currentPost = parent;
                    } catch {
                        break;
                    }
                }
                setParentPosts(parents);

                // Load replies (posts that reply to this one)
                // This would need a new API endpoint - for now we'll skip it
                setReplies([]);

                // Load comments
                const commentsData = await api.getComments(postId);
                setComments(commentsData);

                setError('');
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to load post');
            } finally {
                setIsLoading(false);
            }
        };

        loadData();
    }, [id]);

    const handleReplyCreated = async () => {
        if (!id) return;
        // Refresh comments
        try {
            const commentsData = await api.getComments(parseInt(id));
            setComments(commentsData);
            // Also update the post comment count
            if (post) {
                setPost({ ...post, comments_count: post.comments_count + 1 });
            }
        } catch (err) {
            console.error('Failed to refresh comments:', err);
        }
    };

    const formatTime = (timestamp: string): string => {
        const date = new Date(timestamp + 'Z');
        return date.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
        });
    };

    if (isLoading) {
        return (
            <div className="max-w-2xl mx-auto p-4">
                <div className="flex items-center justify-center py-12">
                    <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                </div>
            </div>
        );
    }

    if (error || !post) {
        return (
            <div className="max-w-2xl mx-auto p-4">
                <div className="text-center py-12 text-destructive">
                    {error || 'Post not found'}
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto p-4">
            {/* Back button */}
            <div className="flex items-center gap-4 mb-4">
                <Button variant="ghost" size="sm" asChild>
                    <Link to="/timeline">
                        <ArrowLeft className="h-4 w-4 mr-2" />
                        Back
                    </Link>
                </Button>
                <h1 className="text-xl font-bold">Post</h1>
            </div>

            {/* Parent posts (thread view) */}
            {parentPosts.length > 0 && (
                <div className="space-y-4 mb-4">
                    {parentPosts.map((parentPost, idx) => (
                        <div key={parentPost.id} className="relative">
                            <PostCard post={parentPost} />
                            {idx < parentPosts.length - 1 && (
                                <div className="absolute left-6 top-16 bottom-0 w-0.5 bg-border -mb-4" />
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* Main post */}
            <div className="mb-6">
                <PostCard 
                    post={post} 
                    onUpdate={(updatedPost) => setPost(updatedPost)}
                />
            </div>

            {/* Reply composer */}
            <div className="mb-6">
                <PostComposer 
                    onPostCreated={handleReplyCreated}
                    replyToId={post.id}
                    replyToPost={post}
                />
            </div>

            {/* Comments section */}
            <div>
                <h2 className="text-xl font-bold mb-4">
                    Comments ({post.comments_count})
                </h2>
                
                {comments.length === 0 ? (
                    <div className="text-center py-12 text-muted-foreground">
                        No comments yet. Be the first to comment!
                    </div>
                ) : (
                    <div className="space-y-4">
                        {comments.map((comment) => {
                            const displayName = comment.display_name || comment.username;
                            const initials = displayName.slice(0, 2).toUpperCase();

                            return (
                                <Card key={comment.id}>
                                    <CardContent className="pt-4">
                                        <div className="flex gap-3">
                                            <Avatar className="h-10 w-10">
                                                <AvatarImage 
                                                    src={comment.avatar_url || undefined} 
                                                    alt={comment.username} 
                                                />
                                                <AvatarFallback>{initials}</AvatarFallback>
                                            </Avatar>
                                            <div className="flex-1">
                                                <div className="flex items-center gap-2 mb-1">
                                                    <Link 
                                                        to={`/profile/${comment.username}`}
                                                        className="font-semibold hover:underline"
                                                    >
                                                        {displayName}
                                                    </Link>
                                                    <span className="text-muted-foreground text-sm">
                                                        @{comment.username}
                                                    </span>
                                                    <span className="text-muted-foreground text-xs">·</span>
                                                    <span className="text-muted-foreground text-xs">
                                                        {formatTime(comment.created_at)}
                                                    </span>
                                                </div>
                                                <p className="text-foreground whitespace-pre-wrap">
                                                    {comment.content}
                                                </p>
                                            </div>
                                        </div>
                                    </CardContent>
                                </Card>
                            );
                        })}
                    </div>
                )}
            </div>
        </div>
    );
}
