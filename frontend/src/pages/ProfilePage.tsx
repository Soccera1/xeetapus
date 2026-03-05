import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../api';
import type { Profile as ProfileType, Post } from '../types';
import { PostCard } from '../components/PostCard';
import { useAuth } from '../context/AuthContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Pin, UserPlus, UserMinus } from 'lucide-react';

export function ProfilePage() {
    const { username } = useParams<{ username?: string }>();
    const { user } = useAuth();
    const [profile, setProfile] = useState<ProfileType | null>(null);
    const [posts, setPosts] = useState<Post[]>([]);
    const [pinnedPost, setPinnedPost] = useState<Post | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');

    const targetUsername = username || user?.username;

    useEffect(() => {
        if (!targetUsername) return;

        const loadData = async () => {
            try {
                setIsLoading(true);
                const [profileData, postsData] = await Promise.all([
                    api.getProfile(targetUsername),
                    api.getUserPosts(targetUsername)
                ]);
                setProfile(profileData);
                
                // Separate pinned post from regular posts
                const pinned = postsData.find(p => p.is_pinned);
                if (pinned) {
                    setPinnedPost(pinned);
                    setPosts(postsData.filter(p => p.id !== pinned.id));
                } else {
                    setPinnedPost(null);
                    setPosts(postsData);
                }
                
                setError('');
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to load profile');
            } finally {
                setIsLoading(false);
            }
        };

        loadData();
    }, [targetUsername]);

    const handleFollow = async () => {
        if (!profile) return;

        try {
            if (profile.is_following) {
                await api.unfollowUser(profile.username);
                setProfile({ ...profile, is_following: false, followers_count: profile.followers_count - 1 });
            } else {
                await api.followUser(profile.username);
                setProfile({ ...profile, is_following: true, followers_count: profile.followers_count + 1 });
            }
        } catch (err) {
            alert(err instanceof Error ? err.message : 'Failed to follow/unfollow');
        }
    };

    const handlePostUpdate = (updatedPost: Post) => {
        if (updatedPost.is_pinned) {
            // If this post is now pinned, update pinned post
            if (pinnedPost && pinnedPost.id !== updatedPost.id) {
                // Another post was pinned before - add it back to posts
                setPosts(prev => [pinnedPost, ...prev.filter(p => p.id !== updatedPost.id)]);
            } else {
                setPosts(prev => prev.filter(p => p.id !== updatedPost.id));
            }
            setPinnedPost(updatedPost);
        } else {
            // Post was unpinned
            if (pinnedPost?.id === updatedPost.id) {
                setPinnedPost(null);
                setPosts(prev => [updatedPost, ...prev]);
            } else {
                setPosts(prev => prev.map(p => p.id === updatedPost.id ? updatedPost : p));
            }
        }
    };

    const handleDeletePost = (postId: number) => {
        if (pinnedPost?.id === postId) {
            setPinnedPost(null);
        } else {
            setPosts(prev => prev.filter(p => p.id !== postId));
        }
        if (profile) {
            setProfile({ ...profile, posts_count: profile.posts_count - 1 });
        }
    };

    if (isLoading) return <div className="text-center py-12 text-muted-foreground">Loading...</div>;
    if (error) return <div className="text-center py-12 text-destructive">{error}</div>;
    if (!profile) return <div className="text-center py-12 text-destructive">Profile not found</div>;

    const isOwnProfile = user?.username === profile.username;
    const displayName = profile.display_name || profile.username;
    const initials = displayName.slice(0, 2).toUpperCase();

    return (
        <div className="max-w-2xl mx-auto p-4">
            <Card className="mb-6">
                <CardContent className="pt-6">
                    <div className="flex flex-col items-center text-center">
                        <Avatar className="h-32 w-32 mb-4">
                            <AvatarImage src={profile.avatar_url || undefined} alt={profile.username} />
                            <AvatarFallback className="text-3xl">{initials}</AvatarFallback>
                        </Avatar>
                        <h1 className="text-2xl font-bold">{displayName}</h1>
                        <p className="text-muted-foreground mb-2">@{profile.username}</p>
                        {profile.bio && (
                            <p className="text-foreground mb-4 max-w-md">{profile.bio}</p>
                        )}
                        <div className="flex items-center gap-6 mb-4 text-sm">
                            <span><strong className="text-foreground">{profile.posts_count}</strong> <span className="text-muted-foreground">posts</span></span>
                            <span><strong className="text-foreground">{profile.followers_count}</strong> <span className="text-muted-foreground">followers</span></span>
                            <span><strong className="text-foreground">{profile.following_count}</strong> <span className="text-muted-foreground">following</span></span>
                        </div>
                        {!isOwnProfile && (
                            <Button
                                variant={profile.is_following ? "outline" : "default"}
                                onClick={handleFollow}
                                className="min-w-[120px]"
                            >
                                {profile.is_following ? (
                                    <><UserMinus className="h-4 w-4 mr-2" /> Unfollow</>
                                ) : (
                                    <><UserPlus className="h-4 w-4 mr-2" /> Follow</>
                                )}
                            </Button>
                        )}
                    </div>
                </CardContent>
            </Card>

            <Tabs defaultValue="posts" className="space-y-4">
                <TabsList className="grid w-full grid-cols-3">
                    <TabsTrigger value="posts">Posts</TabsTrigger>
                    <TabsTrigger value="replies">Replies</TabsTrigger>
                    <TabsTrigger value="media">Media</TabsTrigger>
                </TabsList>

                <TabsContent value="posts" className="space-y-4">
                    {/* Pinned Post */}
                    {pinnedPost && (
                        <div className="space-y-4">
                            <div className="flex items-center gap-2 px-2">
                                <Pin className="h-4 w-4 text-blue-500" />
                                <span className="font-semibold text-sm">Pinned Post</span>
                            </div>
                            <PostCard
                                post={pinnedPost}
                                onUpdate={handlePostUpdate}
                                onDelete={handleDeletePost}
                            />
                            <Separator />
                        </div>
                    )}

                    {/* Regular Posts */}
                    {posts.length === 0 ? (
                        <div className="text-center py-12 text-muted-foreground">
                            {isOwnProfile ? 'You haven\'t posted yet.' : 'No posts yet.'}
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {posts.map(post => (
                                <PostCard
                                    key={post.id}
                                    post={post}
                                    onUpdate={handlePostUpdate}
                                    onDelete={handleDeletePost}
                                />
                            ))}
                        </div>
                    )}
                </TabsContent>

                <TabsContent value="replies">
                    <div className="text-center py-12 text-muted-foreground">
                        Replies feature coming soon...
                    </div>
                </TabsContent>

                <TabsContent value="media">
                    <div className="text-center py-12 text-muted-foreground">
                        Media gallery coming soon...
                    </div>
                </TabsContent>
            </Tabs>
        </div>
    );
}
