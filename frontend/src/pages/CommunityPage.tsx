import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api';
import type { Community, Post, User } from '../types';
import { PostCard } from '../components/PostCard';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Users, MessageSquare, ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Textarea } from '@/components/ui/textarea';

export function CommunityPage() {
    const { id } = useParams<{ id: string }>();
    const [community, setCommunity] = useState<Community | null>(null);
    const [posts, setPosts] = useState<Post[]>([]);
    const [members, setMembers] = useState<User[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');
    const [newPostContent, setNewPostContent] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);

    useEffect(() => {
        if (id) {
            loadCommunity();
        }
    }, [id]);

    const loadCommunity = async () => {
        try {
            setIsLoading(true);
            const [communityData, postsData, membersData] = await Promise.all([
                api.getCommunity(Number(id)),
                api.getCommunityPosts(Number(id)),
                api.getCommunityMembers(Number(id)),
            ]);
            setCommunity(communityData);
            setPosts(postsData);
            setMembers(membersData);
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to load community');
        } finally {
            setIsLoading(false);
        }
    };

    const handleJoin = async () => {
        if (!community) return;
        try {
            await api.joinCommunity(community.id);
            loadCommunity();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to join community');
        }
    };

    const handleLeave = async () => {
        if (!community) return;
        try {
            await api.leaveCommunity(community.id);
            loadCommunity();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to leave community');
        }
    };

    const handleCreatePost = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!community || !newPostContent.trim()) return;

        try {
            setIsSubmitting(true);
            await api.createCommunityPost(community.id, {
                content: newPostContent,
            });
            setNewPostContent('');
            loadCommunity();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to create post');
        } finally {
            setIsSubmitting(false);
        }
    };

    const handlePostUpdate = (updatedPost: Post) => {
        setPosts(prev => prev.map(p => p.id === updatedPost.id ? updatedPost : p));
    };

    if (isLoading) {
        return (
            <div className="max-w-4xl mx-auto p-4">
                <div className="text-center py-12 text-muted-foreground">Loading...</div>
            </div>
        );
    }

    if (!community) {
        return (
            <div className="max-w-4xl mx-auto p-4">
                <div className="text-center py-12 text-destructive">
                    {error || 'Community not found'}
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto p-4">
            {/* Header */}
            <div className="mb-6">
                <Link 
                    to="/communities"
                    className="inline-flex items-center text-muted-foreground hover:text-foreground mb-4"
                >
                    <ArrowLeft className="h-4 w-4 mr-1" />
                    Back to Communities
                </Link>
            </div>

            {/* Community Header Card */}
            <Card className="mb-6">
                <CardContent className="pt-6">
                    {community.banner_url && (
                        <div className="h-32 -mx-6 -mt-6 mb-4 rounded-t-lg overflow-hidden">
                            <img 
                                src={community.banner_url} 
                                alt={`${community.name} banner`}
                                className="w-full h-full object-cover"
                            />
                        </div>
                    )}
                    <div className="flex items-start justify-between">
                        <div className="flex items-start gap-4">
                            {community.icon_url ? (
                                <img 
                                    src={community.icon_url} 
                                    alt={community.name}
                                    className="h-16 w-16 rounded-full object-cover"
                                />
                            ) : (
                                <div className="h-16 w-16 rounded-full bg-primary/10 flex items-center justify-center">
                                    <span className="text-2xl font-bold text-primary">
                                        {community.name.charAt(0).toUpperCase()}
                                    </span>
                                </div>
                            )}
                            <div>
                                <h1 className="text-2xl font-bold">{community.name}</h1>
                                <p className="text-muted-foreground mt-1">
                                    {community.description || 'No description'}
                                </p>
                                <div className="flex items-center gap-4 mt-3 text-sm text-muted-foreground">
                                    <span className="flex items-center gap-1">
                                        <Users className="h-4 w-4" />
                                        {community.member_count} members
                                    </span>
                                    <span className="flex items-center gap-1">
                                        <MessageSquare className="h-4 w-4" />
                                        {community.post_count} posts
                                    </span>
                                </div>
                            </div>
                        </div>
                        {community.is_member ? (
                            <Button variant="outline" onClick={handleLeave}>
                                Leave Community
                            </Button>
                        ) : (
                            <Button onClick={handleJoin}>
                                Join Community
                            </Button>
                        )}
                    </div>
                </CardContent>
            </Card>

            {error && (
                <div className="text-center py-4 text-destructive mb-4">{error}</div>
            )}

            <div className="grid md:grid-cols-3 gap-6">
                {/* Main Content - Posts */}
                <div className="md:col-span-2 space-y-4">
                    {community.is_member && (
                        <Card>
                            <CardContent className="pt-6">
                                <form onSubmit={handleCreatePost}>
                                    <Textarea
                                        value={newPostContent}
                                        onChange={(e) => setNewPostContent(e.target.value)}
                                        placeholder={`Post to ${community.name}...`}
                                        rows={3}
                                        className="mb-3"
                                        maxLength={280}
                                    />
                                    <div className="flex items-center justify-between">
                                        <span className="text-sm text-muted-foreground">
                                            {newPostContent.length}/280
                                        </span>
                                        <Button 
                                            type="submit" 
                                            disabled={!newPostContent.trim() || isSubmitting}
                                        >
                                            {isSubmitting ? 'Posting...' : 'Post'}
                                        </Button>
                                    </div>
                                </form>
                            </CardContent>
                        </Card>
                    )}

                    {posts.length === 0 ? (
                        <div className="text-center py-12 text-muted-foreground">
                            No posts yet. {community.is_member && 'Be the first to post!'}
                        </div>
                    ) : (
                        posts.map(post => (
                            <PostCard 
                                key={post.id} 
                                post={post}
                                onUpdate={handlePostUpdate}
                            />
                        ))
                    )}
                </div>

                {/* Sidebar - Members */}
                <div className="space-y-4">
                    <Card>
                        <CardContent className="pt-6">
                            <h3 className="font-semibold mb-4">Members</h3>
                            {members.length === 0 ? (
                                <p className="text-sm text-muted-foreground">No members yet</p>
                            ) : (
                                <div className="space-y-3">
                                    {members.slice(0, 10).map((member) => (
                                        <Link 
                                            key={member.id}
                                            to={`/profile/${member.username}`}
                                            className="flex items-center gap-3 hover:bg-muted p-2 rounded-lg -mx-2 transition-colors"
                                        >
                                            <Avatar className="h-8 w-8">
                                                <AvatarImage 
                                                    src={member.avatar_url || undefined} 
                                                    alt={member.username}
                                                />
                                                <AvatarFallback>
                                                    {(member.display_name || member.username).slice(0, 2).toUpperCase()}
                                                </AvatarFallback>
                                            </Avatar>
                                            <div className="min-w-0">
                                                <p className="text-sm font-medium truncate">
                                                    {member.display_name || member.username}
                                                </p>
                                                <p className="text-xs text-muted-foreground">
                                                    @{member.username}
                                                </p>
                                            </div>
                                        </Link>
                                    ))}
                                    {members.length > 10 && (
                                        <p className="text-sm text-muted-foreground text-center">
                                            +{members.length - 10} more
                                        </p>
                                    )}
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </div>
            </div>
        </div>
    );
}
