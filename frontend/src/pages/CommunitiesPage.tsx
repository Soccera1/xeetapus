import { useEffect, useState } from 'react';
import { api } from '../api';
import type { Community } from '../types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, MessageSquare, Plus, Minus } from 'lucide-react';
import { Link } from 'react-router-dom';

export function CommunitiesPage() {
    const [communities, setCommunities] = useState<Community[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');
    const [showCreateForm, setShowCreateForm] = useState(false);
    const [newCommunity, setNewCommunity] = useState({
        name: '',
        description: '',
    });

    useEffect(() => {
        loadCommunities();
    }, []);

    const loadCommunities = async () => {
        try {
            setIsLoading(true);
            const data = await api.getCommunities();
            setCommunities(data);
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to load communities');
        } finally {
            setIsLoading(false);
        }
    };

    const handleCreateCommunity = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            await api.createCommunity(newCommunity);
            setShowCreateForm(false);
            setNewCommunity({ name: '', description: '' });
            loadCommunities();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to create community');
        }
    };

    const handleJoinCommunity = async (id: number) => {
        try {
            await api.joinCommunity(id);
            loadCommunities();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to join community');
        }
    };

    const handleLeaveCommunity = async (id: number) => {
        try {
            await api.leaveCommunity(id);
            loadCommunities();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to leave community');
        }
    };

    return (
        <div className="max-w-4xl mx-auto p-4">
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold">Communities</h1>
                <Button onClick={() => setShowCreateForm(!showCreateForm)}>
                    {showCreateForm ? (
                        <>
                            <Minus className="h-4 w-4 mr-2" />
                            Cancel
                        </>
                    ) : (
                        <>
                            <Plus className="h-4 w-4 mr-2" />
                            Create Community
                        </>
                    )}
                </Button>
            </div>

            {showCreateForm && (
                <Card className="mb-6">
                    <CardHeader>
                        <CardTitle>Create a New Community</CardTitle>
                        <CardDescription>
                            Create a space for people to share and discuss topics they're interested in.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleCreateCommunity} className="space-y-4">
                            <div>
                                <label className="text-sm font-medium">Community Name</label>
                                <Input
                                    value={newCommunity.name}
                                    onChange={(e) => setNewCommunity({ ...newCommunity, name: e.target.value })}
                                    placeholder="e.g., Technology, Sports, Art"
                                    required
                                    minLength={3}
                                    maxLength={50}
                                />
                            </div>
                            <div>
                                <label className="text-sm font-medium">Description</label>
                                <Textarea
                                    value={newCommunity.description}
                                    onChange={(e) => setNewCommunity({ ...newCommunity, description: e.target.value })}
                                    placeholder="What's this community about?"
                                    rows={3}
                                />
                            </div>
                            <Button type="submit">
                                Create Community
                            </Button>
                        </form>
                    </CardContent>
                </Card>
            )}

            {error && (
                <div className="text-center py-4 text-destructive mb-4">{error}</div>
            )}

            {isLoading ? (
                <div className="text-center py-12 text-muted-foreground">Loading...</div>
            ) : communities.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                    <p className="mb-4">No communities yet.</p>
                    <p>Be the first to create one!</p>
                </div>
            ) : (
                <div className="grid gap-4 md:grid-cols-2">
                    {communities.map((community) => (
                        <Card key={community.id}>
                            <CardHeader>
                                <div className="flex items-start justify-between">
                                    <div className="flex-1">
                                        <Link 
                                            to={`/communities/${community.id}`}
                                            className="hover:underline"
                                        >
                                            <CardTitle>{community.name}</CardTitle>
                                        </Link>
                                        <CardDescription className="mt-1 line-clamp-2">
                                            {community.description || 'No description'}
                                        </CardDescription>
                                    </div>
                                    {community.icon_url ? (
                                        <img 
                                            src={community.icon_url} 
                                            alt={community.name}
                                            className="h-12 w-12 rounded-full object-cover ml-4"
                                        />
                                    ) : (
                                        <div className="h-12 w-12 rounded-full bg-primary/10 flex items-center justify-center ml-4">
                                            <span className="text-lg font-bold text-primary">
                                                {community.name.charAt(0).toUpperCase()}
                                            </span>
                                        </div>
                                    )}
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-4 text-sm text-muted-foreground">
                                        <span className="flex items-center gap-1">
                                            <Users className="h-4 w-4" />
                                            {community.member_count}
                                        </span>
                                        <span className="flex items-center gap-1">
                                            <MessageSquare className="h-4 w-4" />
                                            {community.post_count}
                                        </span>
                                    </div>
                                    {community.is_member ? (
                                        <Button 
                                            variant="outline" 
                                            size="sm"
                                            onClick={() => handleLeaveCommunity(community.id)}
                                        >
                                            Leave
                                        </Button>
                                    ) : (
                                        <Button 
                                            size="sm"
                                            onClick={() => handleJoinCommunity(community.id)}
                                        >
                                            Join
                                        </Button>
                                    )}
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    );
}
