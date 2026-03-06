import { useEffect, useState, useRef } from 'react';
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
import { Pin, UserPlus, UserMinus, Image as ImageIcon, MessageCircle, Edit, Check, X, Upload } from 'lucide-react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';

export function ProfilePage() {
    const { username } = useParams<{ username?: string }>();
    const { user } = useAuth();
    const [profile, setProfile] = useState<ProfileType | null>(null);
    const [posts, setPosts] = useState<Post[]>([]);
    const [replies, setReplies] = useState<Post[]>([]);
    const [mediaPosts, setMediaPosts] = useState<Post[]>([]);
    const [pinnedPost, setPinnedPost] = useState<Post | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');
    const [activeTab, setActiveTab] = useState('posts');
    const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
    const [editForm, setEditForm] = useState({
        display_name: '',
        bio: '',
        avatar_url: ''
    });
    const [avatarFile, setAvatarFile] = useState<File | null>(null);
    const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
    const [isUploadingAvatar, setIsUploadingAvatar] = useState(false);
    const fileInputRef = useRef<HTMLInputElement>(null);

    const targetUsername = username || user?.username;
    const isOwnProfile = user?.username === profile?.username;

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
                
                // Initialize edit form with current values
                setEditForm({
                    display_name: profileData.display_name || '',
                    bio: profileData.bio || '',
                    avatar_url: profileData.avatar_url || ''
                });
                
                setError('');
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to load profile');
            } finally {
                setIsLoading(false);
            }
        };

        loadData();
    }, [targetUsername]);

    // Load replies when tab is selected
    useEffect(() => {
        if (!targetUsername || activeTab !== 'replies' || replies.length > 0) return;

        const loadReplies = async () => {
            try {
                const repliesData = await api.getUserReplies(targetUsername);
                setReplies(repliesData);
            } catch (err) {
                console.error('Failed to load replies:', err);
            }
        };

        loadReplies();
    }, [activeTab, targetUsername, replies.length]);

    // Load media when tab is selected
    useEffect(() => {
        if (!targetUsername || activeTab !== 'media' || mediaPosts.length > 0) return;

        const loadMedia = async () => {
            try {
                const mediaData = await api.getUserMediaPosts(targetUsername);
                setMediaPosts(mediaData);
            } catch (err) {
                console.error('Failed to load media:', err);
            }
        };

        loadMedia();
    }, [activeTab, targetUsername, mediaPosts.length]);

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

    const handleAvatarSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            setAvatarFile(file);
            const reader = new FileReader();
            reader.onloadend = () => {
                setAvatarPreview(reader.result as string);
            };
            reader.readAsDataURL(file);
        }
    };

    const handleUpdateProfile = async () => {
        try {
            setIsUploadingAvatar(true);
            let avatarUrl = editForm.avatar_url;

            // Upload avatar if a new file was selected
            if (avatarFile) {
                const result = await api.uploadMedia(avatarFile, true);
                avatarUrl = result.url;
            }

            await api.updateProfile({
                display_name: editForm.display_name,
                bio: editForm.bio,
                avatar_url: avatarUrl
            });

            // Update local profile state
            setProfile(prev => prev ? { 
                ...prev, 
                display_name: editForm.display_name,
                bio: editForm.bio,
                avatar_url: avatarUrl
            } : null);

            // Reset avatar file state
            setAvatarFile(null);
            setAvatarPreview(null);
            setIsEditDialogOpen(false);
        } catch (err) {
            alert(err instanceof Error ? err.message : 'Failed to update profile');
        } finally {
            setIsUploadingAvatar(false);
        }
    };

    const handleTabChange = (value: string) => {
        setActiveTab(value);
    };

    if (isLoading) return <div className="text-center py-12 text-muted-foreground">Loading...</div>;
    if (error) return <div className="text-center py-12 text-destructive">{error}</div>;
    if (!profile) return <div className="text-center py-12 text-destructive">Profile not found</div>;

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
                        <div className="flex gap-2">
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
                            {isOwnProfile && (
                                <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
                                    <DialogTrigger asChild>
                                        <Button variant="outline" className="min-w-[120px]">
                                            <Edit className="h-4 w-4 mr-2" /> Edit Profile
                                        </Button>
                                    </DialogTrigger>
                                    <DialogContent className="sm:max-w-[425px]">
                                        <DialogHeader>
                                            <DialogTitle>Edit Profile</DialogTitle>
                                        </DialogHeader>
                                        <div className="grid gap-4 py-4">
                                            <div className="grid gap-2">
                                                <Label htmlFor="display_name">Display Name</Label>
                                                <Input
                                                    id="display_name"
                                                    value={editForm.display_name}
                                                    onChange={(e) => setEditForm({ ...editForm, display_name: e.target.value })}
                                                    placeholder="Your display name"
                                                    maxLength={50}
                                                />
                                            </div>
                                            <div className="grid gap-2">
                                                <Label htmlFor="bio">Bio</Label>
                                                <Textarea
                                                    id="bio"
                                                    value={editForm.bio}
                                                    onChange={(e) => setEditForm({ ...editForm, bio: e.target.value })}
                                                    placeholder="Tell us about yourself"
                                                    maxLength={160}
                                                    rows={3}
                                                />
                                                <p className="text-xs text-muted-foreground text-right">
                                                    {editForm.bio.length}/160
                                                </p>
                                            </div>
                                            <div className="grid gap-2">
                                                <Label>Avatar</Label>
                                                <div className="flex items-center gap-4">
                                                    <Avatar className="h-16 w-16">
                                                        <AvatarImage 
                                                            src={avatarPreview || editForm.avatar_url || undefined} 
                                                            alt="Avatar preview" 
                                                        />
                                                        <AvatarFallback className="text-lg">
                                                            {editForm.display_name?.slice(0, 2).toUpperCase() || 'U'}
                                                        </AvatarFallback>
                                                    </Avatar>
                                                    <div className="flex-1">
                                                        <input
                                                            ref={fileInputRef}
                                                            type="file"
                                                            accept="image/*,.svg"
                                                            onChange={handleAvatarSelect}
                                                            className="hidden"
                                                        />
                                                        <Button
                                                            type="button"
                                                            variant="outline"
                                                            onClick={() => fileInputRef.current?.click()}
                                                            className="w-full"
                                                        >
                                                            <Upload className="h-4 w-4 mr-2" />
                                                            {avatarFile ? 'Change Photo' : 'Upload Photo'}
                                                        </Button>
                                                        {avatarFile && (
                                                            <p className="text-xs text-muted-foreground mt-1">
                                                                Selected: {avatarFile.name}
                                                            </p>
                                                        )}
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                        <div className="flex justify-end gap-2">
                                            <Button variant="outline" onClick={() => setIsEditDialogOpen(false)}>
                                                <X className="h-4 w-4 mr-2" /> Cancel
                                            </Button>
                                            <Button onClick={handleUpdateProfile} disabled={isUploadingAvatar}>
                                                <Check className="h-4 w-4 mr-2" /> 
                                                {isUploadingAvatar ? 'Uploading...' : 'Save'}
                                            </Button>
                                        </div>
                                    </DialogContent>
                                </Dialog>
                            )}
                        </div>
                    </div>
                </CardContent>
            </Card>

            <Tabs value={activeTab} onValueChange={handleTabChange} className="space-y-4">
                <TabsList className="grid w-full grid-cols-3">
                    <TabsTrigger value="posts">Posts</TabsTrigger>
                    <TabsTrigger value="replies">
                        <MessageCircle className="h-4 w-4 mr-1" />
                        Replies
                    </TabsTrigger>
                    <TabsTrigger value="media">
                        <ImageIcon className="h-4 w-4 mr-1" />
                        Media
                    </TabsTrigger>
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

                <TabsContent value="replies" className="space-y-4">
                    {replies.length === 0 ? (
                        <div className="text-center py-12 text-muted-foreground">
                            {isOwnProfile ? 'You haven\'t replied to any posts yet.' : 'No replies yet.'}
                        </div>
                    ) : (
                        <div className="space-y-4">
                            {replies.map(post => (
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

                <TabsContent value="media" className="space-y-4">
                    {mediaPosts.length === 0 ? (
                        <div className="text-center py-12 text-muted-foreground">
                            {isOwnProfile ? 'You haven\'t posted any media yet.' : 'No media posts yet.'}
                        </div>
                    ) : (
                        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                            {mediaPosts.map(post => (
                                <div key={post.id} className="relative aspect-square group cursor-pointer overflow-hidden rounded-lg border">
                                    {post.media_urls && (
                                        <img
                                            src={post.media_urls.split(',')[0]}
                                            alt="Post media"
                                            className="w-full h-full object-cover transition-transform group-hover:scale-105"
                                        />
                                    )}
                                    <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                                        <div className="text-white text-center p-2">
                                            <p className="text-sm line-clamp-2">{post.content}</p>
                                            <div className="flex items-center justify-center gap-4 mt-2 text-xs">
                                                <span>♥ {post.likes_count}</span>
                                                <span>💬 {post.comments_count}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </TabsContent>
            </Tabs>
        </div>
    );
}
