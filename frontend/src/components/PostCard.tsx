import type { Post } from '../types';
import { api } from '../api';
import { useState, useEffect } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Heart, MessageCircle, Repeat2, Bookmark, Eye, Pin, Image, Quote, Trash2, Bot } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { LlmChatDialog } from './LlmChatDialog';

interface PostCardProps {
    post: Post;
    onUpdate?: (post: Post) => void;
    onDelete?: (postId: number) => void;
}

export function PostCard({ post, onUpdate, onDelete }: PostCardProps) {
    const [localPost, setLocalPost] = useState(post);
    const [isReposting, setIsReposting] = useState(false);
    const { user } = useAuth();
    const navigate = useNavigate();

    useEffect(() => {
        setLocalPost(post);
    }, [post]);

    // Record view on mount
    useEffect(() => {
        const recordView = async () => {
            try {
                await api.recordPostView(localPost.id);
            } catch {
                // Silently fail for view tracking
            }
        };
        recordView();
    }, [localPost.id]);

    const handleLike = async () => {
        try {
            if (localPost.is_liked) {
                await api.unlikePost(localPost.id);
                const updated = { ...localPost, is_liked: false, likes_count: localPost.likes_count - 1 };
                setLocalPost(updated);
                onUpdate?.(updated);
            } else {
                await api.likePost(localPost.id);
                const updated = { ...localPost, is_liked: true, likes_count: localPost.likes_count + 1 };
                setLocalPost(updated);
                onUpdate?.(updated);
            }
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to like post');
        }
    };

    const normalizeCount = (value: number | undefined | null): number => {
        const count = Number(value);
        return Number.isFinite(count) ? count : 0;
    };

    const handleRepost = async () => {
        if (isReposting) return;

        try {
            setIsReposting(true);
            if (localPost.is_reposted) {
                const result = await api.unrepostPost(localPost.id);
                const updated = {
                    ...localPost,
                    is_reposted: result.is_reposted,
                    reposts_count: normalizeCount(result.reposts_count),
                };
                setLocalPost(updated);
                onUpdate?.(updated);
            } else {
                const result = await api.repostPost(localPost.id);
                const updated = {
                    ...localPost,
                    is_reposted: result.is_reposted,
                    reposts_count: normalizeCount(result.reposts_count),
                };
                setLocalPost(updated);
                onUpdate?.(updated);
            }
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to repost');
        } finally {
            setIsReposting(false);
        }
    };

    const handleBookmark = async () => {
        try {
            if (localPost.is_bookmarked) {
                await api.unbookmarkPost(localPost.id);
                const updated = { ...localPost, is_bookmarked: false };
                setLocalPost(updated);
                onUpdate?.(updated);
            } else {
                await api.bookmarkPost(localPost.id);
                const updated = { ...localPost, is_bookmarked: true };
                setLocalPost(updated);
                onUpdate?.(updated);
            }
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to bookmark');
        }
    };

    const handleVote = async (optionId: number) => {
        if (!localPost.poll || localPost.poll.has_voted) return;

        try {
            await api.voteOnPoll(localPost.poll.id, optionId);
            // Refresh poll results
            const results = await api.getPollResults(localPost.poll.id);
            const updatedPost = {
                ...localPost,
                poll: {
                    ...localPost.poll,
                    has_voted: true,
                    selected_option: optionId,
                    options: results.options,
                    vote_count: results.total_votes
                }
            };
            setLocalPost(updatedPost);
            onUpdate?.(updatedPost);
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to vote');
        }
    };

    const handlePin = async () => {
        try {
            if (localPost.is_pinned) {
                await api.unpinPost(localPost.id);
                const updated = { ...localPost, is_pinned: false };
                setLocalPost(updated);
                onUpdate?.(updated);
            } else {
                await api.pinPost(localPost.id);
                const updated = { ...localPost, is_pinned: true };
                setLocalPost(updated);
                onUpdate?.(updated);
            }
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to pin/unpin post');
        }
    };

    const handleDelete = async () => {
        if (!confirm('Are you sure you want to delete this post?')) return;

        try {
            await api.deletePost(localPost.id);
            onDelete?.(localPost.id);
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to delete post');
        }
    };

    const handleQuote = () => {
        navigate('/timeline', { state: { quotePost: localPost } });
    };

    const handleReply = () => {
        navigate(`/post/${localPost.id}`);
    };

    const formatTime = (timestamp: string): string => {
        const date = new Date(timestamp + 'Z');
        const now = new Date();
        const diff = now.getTime() - date.getTime();

        const minutes = Math.floor(diff / 60000);
        const hours = Math.floor(diff / 3600000);
        const days = Math.floor(diff / 86400000);

        if (minutes < 1) return 'just now';
        if (minutes < 60) return `${minutes}m`;
        if (hours < 24) return `${hours}h`;
        if (days < 7) return `${days}d`;
        return date.toLocaleDateString();
    };

    const formatNumber = (num: number | undefined | null): string => {
        if (num == null) return '0';
        if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
        return num.toString();
    };

    const displayName = localPost.display_name || localPost.username;
    const initials = displayName.slice(0, 2).toUpperCase();
    const isOwnPost = user?.id === localPost.user_id;

    // Parse media URLs
    const mediaUrls = localPost.media_urls ? localPost.media_urls.split(',') : [];

    return (
        <Card className={localPost.is_pinned ? 'border-blue-500 border-2' : ''}>
            <CardContent className="pt-6">
                {/* Pinned indicator */}
                {localPost.is_pinned && (
                    <div className="flex items-center gap-2 text-blue-500 text-sm mb-2 ml-14">
                        <Pin className="h-3 w-3" />
                        <span className="font-medium">Pinned post</span>
                    </div>
                )}

                {/* Reply indicator */}
                {localPost.reply_to_id && (
                    <div className="flex items-center gap-2 text-muted-foreground text-sm mb-2 ml-14">
                        <MessageCircle className="h-3 w-3" />
                        <span>Replying to a post</span>
                    </div>
                )}

                <div className="flex items-start gap-3">
                    <Link to={`/profile/${localPost.username}`}>
                        <Avatar className="h-12 w-12">
                            <AvatarImage src={localPost.avatar_url || undefined} alt={localPost.username} />
                            <AvatarFallback>{initials}</AvatarFallback>
                        </Avatar>
                    </Link>
                    <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-1">
                            <div className="flex items-center gap-2 flex-wrap">
                                <Link to={`/profile/${localPost.username}`}>
                                    <span className="font-semibold truncate hover:underline">{displayName}</span>
                                </Link>
                                <span className="text-muted-foreground text-sm">@{localPost.username}</span>
                                <span className="text-muted-foreground text-xs">·</span>
                                <span className="text-muted-foreground text-xs">{formatTime(localPost.created_at)}</span>
                            </div>
                            {isOwnPost && (
                                <div className="flex items-center gap-1">
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        className={`h-8 w-8 p-0 ${localPost.is_pinned ? 'text-blue-500' : ''}`}
                                        onClick={handlePin}
                                        title={localPost.is_pinned ? 'Unpin from profile' : 'Pin to profile'}
                                    >
                                        <Pin className="h-4 w-4" />
                                    </Button>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        className="h-8 w-8 p-0 text-destructive"
                                        onClick={handleDelete}
                                        title="Delete post"
                                    >
                                        <Trash2 className="h-4 w-4" />
                                    </Button>
                                </div>
                            )}
                        </div>

                        <p className="text-foreground whitespace-pre-wrap break-words mb-3">
                            {localPost.content}
                        </p>

                        {/* Media display */}
                        {mediaUrls.length > 0 && (
                            <div className={`grid gap-2 mb-3 ${mediaUrls.length > 1 ? 'grid-cols-2' : 'grid-cols-1'}`}>
                                {mediaUrls.map((url, idx) => (
                                    <div key={idx} className="relative rounded-lg overflow-hidden bg-muted">
                                        {url.match(/\.(jpg|jpeg|png|gif|webp)$/i) ? (
                                            <img
                                                src={url}
                                                alt={`Media ${idx + 1}`}
                                                className="w-full h-auto max-h-80 object-cover"
                                                loading="lazy"
                                            />
                                        ) : url.match(/\.(mp4|webm|mov)$/i) ? (
                                            <video
                                                src={url}
                                                controls
                                                className="w-full h-auto max-h-80"
                                            />
                                        ) : (
                                            <div className="flex items-center gap-2 p-4">
                                                <Image className="h-5 w-5" />
                                                <a href={url} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:underline">
                                                    View media
                                                </a>
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>
                        )}

                        {/* Quote post display */}
                        {localPost.quote_to_post && (
                            <div className="border rounded-lg p-3 mb-3 bg-muted/50">
                                <div className="flex items-center gap-2 mb-2">
                                    <Avatar className="h-5 w-5">
                                        <AvatarImage src={localPost.quote_to_post.avatar_url || undefined} />
                                        <AvatarFallback className="text-xs">
                                            {(localPost.quote_to_post.display_name || localPost.quote_to_post.username).slice(0, 2).toUpperCase()}
                                        </AvatarFallback>
                                    </Avatar>
                                    <span className="font-medium text-sm">{localPost.quote_to_post.display_name || localPost.quote_to_post.username}</span>
                                    <span className="text-muted-foreground text-sm">@{localPost.quote_to_post.username}</span>
                                </div>
                                <p className="text-sm text-muted-foreground line-clamp-3">
                                    {localPost.quote_to_post.content}
                                </p>
                            </div>
                        )}

                        {/* Poll display */}
                        {localPost.poll && (
                            <div className="space-y-2 mb-3">
                                <p className="font-medium">{localPost.poll.question}</p>
                                {localPost.poll.options.map((option) => {
                                    const totalVotes = localPost.poll!.options.reduce((sum, o) => sum + o.vote_count, 0);
                                    const percentage = totalVotes > 0 ? (option.vote_count / totalVotes) * 100 : 0;
                                    const isSelected = localPost.poll!.selected_option === option.id;

                                    return (
                                        <div
                                            key={option.id}
                                            onClick={() => !localPost.poll!.has_voted && handleVote(option.id)}
                                            className={`
                                                relative overflow-hidden rounded-lg border p-3 cursor-pointer transition-colors
                                                ${localPost.poll!.has_voted ? 'cursor-default' : 'hover:bg-muted'}
                                                ${isSelected ? 'border-blue-500 bg-blue-50' : ''}
                                            `}
                                        >
                                            {localPost.poll!.has_voted && (
                                                <div
                                                    className="absolute left-0 top-0 bottom-0 bg-muted transition-all"
                                                    style={{ width: `${percentage}%` }}
                                                />
                                            )}
                                            <div className="relative z-10 flex justify-between items-center">
                                                <span>{option.option_text}</span>
                                                {localPost.poll!.has_voted && (
                                                    <span className="text-sm font-medium">
                                                        {percentage.toFixed(0)}% ({option.vote_count})
                                                    </span>
                                                )}
                                            </div>
                                        </div>
                                    );
                                })}
                                <p className="text-xs text-muted-foreground">
                                    {localPost.poll.options.reduce((sum, o) => sum + o.vote_count, 0)} votes
                                    {localPost.poll.ends_at && (
                                        <> · {new Date(localPost.poll.ends_at) > new Date() ? 'Ends ' : 'Ended '}
                                        {formatTime(localPost.poll.ends_at)}</>
                                    )}
                                </p>
                            </div>
                        )}

                        {/* Action buttons */}
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-1 sm:gap-4">
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className={`gap-2 ${localPost.is_liked ? 'text-red-500 hover:text-red-600' : ''}`}
                                    onClick={handleLike}
                                >
                                    <Heart className={`h-4 w-4 ${localPost.is_liked ? 'fill-current' : ''}`} />
                                    <span className="hidden sm:inline">{formatNumber(localPost.likes_count)}</span>
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className={`gap-2 ${localPost.is_reposted ? 'text-green-500 hover:text-green-600' : ''}`}
                                    disabled={isReposting}
                                    onClick={handleRepost}
                                >
                                    <Repeat2 className={`h-4 w-4 ${localPost.is_reposted ? 'fill-current' : ''}`} />
                                    <span className="hidden sm:inline">{formatNumber(localPost.reposts_count)}</span>
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="gap-2"
                                    onClick={handleReply}
                                >
                                    <MessageCircle className="h-4 w-4" />
                                    <span className="hidden sm:inline">{formatNumber(localPost.comments_count)}</span>
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="gap-2"
                                    onClick={handleQuote}
                                >
                                    <Quote className="h-4 w-4" />
                                </Button>
                                <LlmChatDialog
                                    post={localPost}
                                    triggerLabel="AI"
                                    triggerIcon={<Bot className="h-4 w-4" />}
                                    triggerVariant="ghost"
                                    triggerSize="sm"
                                    triggerClassName="gap-2"
                                />
                            </div>

                            <div className="flex items-center gap-1 sm:gap-4">
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className={`gap-2 ${localPost.is_bookmarked ? 'text-blue-500 hover:text-blue-600' : ''}`}
                                    onClick={handleBookmark}
                                >
                                    <Bookmark className={`h-4 w-4 ${localPost.is_bookmarked ? 'fill-current' : ''}`} />
                                </Button>
                                <div className="flex items-center gap-1 text-muted-foreground text-sm">
                                    <Eye className="h-4 w-4" />
                                    <span>{formatNumber(localPost.view_count)}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
}
