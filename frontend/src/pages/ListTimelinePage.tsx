import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import type { UserList, ListMember, Post } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { ArrowLeft, Users, Trash2, UserPlus } from 'lucide-react';
import { PostCard } from '../components/PostCard';

export function ListTimelinePage() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const [list, setList] = useState<UserList | null>(null);
    const [members, setMembers] = useState<ListMember[]>([]);
    const [posts, setPosts] = useState<Post[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [newMemberUsername, setNewMemberUsername] = useState('');
    const [showAddMember, setShowAddMember] = useState(false);

    useEffect(() => {
        if (id) {
            loadList();
            loadPosts();
        }
    }, [id]);

    const loadList = async () => {
        try {
            const data = await api.getList(parseInt(id!));
            setList(data.list);
            setMembers(data.members);
        } catch (err) {
            setError('Failed to load list');
        }
    };

    const loadPosts = async () => {
        try {
            const data = await api.getListTimeline(parseInt(id!));
            setPosts(data.posts);
        } catch (err) {
            setError('Failed to load posts');
        } finally {
            setLoading(false);
        }
    };

    const addMember = async () => {
        if (!newMemberUsername.trim()) return;
        
        try {
            // First search for the user
            const users = await api.searchUsers(newMemberUsername);
            if (users.length === 0) {
                setError('User not found');
                return;
            }
            
            await api.addListMember(parseInt(id!), users[0].id);
            setNewMemberUsername('');
            setShowAddMember(false);
            loadList();
        } catch (err) {
            setError('Failed to add member');
        }
    };

    const removeMember = async (userId: number) => {
        if (!confirm('Remove this member from the list?')) return;
        
        try {
            await api.removeListMember(parseInt(id!), userId);
            loadList();
        } catch (err) {
            setError('Failed to remove member');
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;
    if (!list) return <div className="text-center py-12">List not found</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <Button 
                variant="ghost" 
                onClick={() => navigate('/lists')}
                className="mb-4"
            >
                <ArrowLeft className="w-4 h-4 mr-2" />
                Back to Lists
            </Button>

            <Card className="mb-6">
                <CardHeader>
                    <div className="flex items-start justify-between">
                        <div>
                            <CardTitle className="text-2xl">{list.name}</CardTitle>
                            {list.description && (
                                <p className="text-muted-foreground mt-2">{list.description}</p>
                            )}
                        </div>
                        <div className="flex items-center gap-2 text-muted-foreground">
                            <Users className="w-5 h-5" />
                            <span>{members.length} members</span>
                        </div>
                    </div>
                </CardHeader>
                <CardContent>
                    <div className="flex items-center justify-between mb-4">
                        <h3 className="font-semibold">Members</h3>
                        <Button 
                            variant="outline" 
                            size="sm"
                            onClick={() => setShowAddMember(!showAddMember)}
                        >
                            <UserPlus className="w-4 h-4 mr-2" />
                            Add Member
                        </Button>
                    </div>

                    {showAddMember && (
                        <div className="flex gap-2 mb-4">
                            <Input
                                value={newMemberUsername}
                                onChange={(e) => setNewMemberUsername(e.target.value)}
                                placeholder="Username"
                            />
                            <Button onClick={addMember}>Add</Button>
                        </div>
                    )}

                    <div className="flex flex-wrap gap-2">
                        {members.map((member) => (
                            <div 
                                key={member.id}
                                className="flex items-center gap-2 bg-muted px-3 py-1 rounded-full"
                            >
                                <span 
                                    className="cursor-pointer hover:underline"
                                    onClick={() => navigate(`/profile/${member.username}`)}
                                >
                                    @{member.username}
                                </span>
                                <button
                                    onClick={() => removeMember(member.id)}
                                    className="text-red-500 hover:text-red-700"
                                >
                                    <Trash2 className="w-3 h-3" />
                                </button>
                            </div>
                        ))}
                    </div>
                </CardContent>
            </Card>

            <h2 className="text-xl font-bold mb-4">List Timeline</h2>
            
            {posts.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <p>No posts yet</p>
                        <p className="text-sm">Posts from list members will appear here</p>
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
