import { useState } from 'react';
import { api } from '../api';
import type { Post, User } from '../types';
import { PostCard } from '../components/PostCard';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Search } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export function SearchPage() {
    const [query, setQuery] = useState('');
    const [users, setUsers] = useState<User[]>([]);
    const [posts, setPosts] = useState<Post[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');
    const [hasSearched, setHasSearched] = useState(false);
    const navigate = useNavigate();

    const handleSearch = async () => {
        if (!query.trim()) return;
        
        try {
            setIsLoading(true);
            setError('');
            setHasSearched(true);
            
            const [usersData, postsData] = await Promise.all([
                api.searchUsers(query),
                api.searchPosts(query)
            ]);
            
            setUsers(usersData);
            setPosts(postsData);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to search');
        } finally {
            setIsLoading(false);
        }
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            handleSearch();
        }
    };

    const handlePostUpdate = (updatedPost: Post) => {
        setPosts(posts.map(p => p.id === updatedPost.id ? updatedPost : p));
    };

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Search</h1>
            
            <div className="flex gap-2 mb-6">
                <Input
                    type="text"
                    placeholder="Search users and posts..."
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    onKeyDown={handleKeyDown}
                    className="flex-1"
                />
                <Button onClick={handleSearch} disabled={isLoading || !query.trim()}>
                    <Search className="h-4 w-4 mr-2" />
                    Search
                </Button>
            </div>
            
            {isLoading ? (
                <div className="text-center py-12 text-muted-foreground">Searching...</div>
            ) : error ? (
                <div className="text-center py-12 text-destructive">{error}</div>
            ) : hasSearched ? (
                <Tabs defaultValue="posts" className="w-full">
                    <TabsList className="grid w-full grid-cols-2">
                        <TabsTrigger value="posts">Posts ({posts.length})</TabsTrigger>
                        <TabsTrigger value="users">Users ({users.length})</TabsTrigger>
                    </TabsList>
                    
                    <TabsContent value="posts" className="mt-4">
                        {posts.length === 0 ? (
                            <div className="text-center py-12 text-muted-foreground">
                                No posts found matching "{query}"
                            </div>
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
                    </TabsContent>
                    
                    <TabsContent value="users" className="mt-4">
                        {users.length === 0 ? (
                            <div className="text-center py-12 text-muted-foreground">
                                No users found matching "{query}"
                            </div>
                        ) : (
                            <div className="space-y-2">
                                {users.map(user => (
                                    <div
                                        key={user.id}
                                        className="flex items-center gap-3 p-4 rounded-lg border cursor-pointer hover:bg-muted/50 transition-colors"
                                        onClick={() => navigate(`/${user.username}`)}
                                    >
                                        <Avatar className="h-12 w-12">
                                            <AvatarImage src={user.avatar_url || undefined} alt={user.username} />
                                            <AvatarFallback>
                                                {(user.display_name || user.username).slice(0, 2).toUpperCase()}
                                            </AvatarFallback>
                                        </Avatar>
                                        <div>
                                            <p className="font-semibold">{user.display_name || user.username}</p>
                                            <p className="text-muted-foreground text-sm">@{user.username}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </TabsContent>
                </Tabs>
            ) : (
                <div className="text-center py-12 text-muted-foreground">
                    Enter a search term to find users and posts
                </div>
            )}
        </div>
    );
}