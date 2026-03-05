import { useState, useEffect } from 'react';
import { api } from '../api';
import type { BlockedUser, MutedUser } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Ban, VolumeX, UserX, Plus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export function SettingsPage() {
    const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
    const [mutedUsers, setMutedUsers] = useState<MutedUser[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [blockUsername, setBlockUsername] = useState('');
    const [muteUsername, setMuteUsername] = useState('');
    const navigate = useNavigate();

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            const [blocked, muted] = await Promise.all([
                api.getBlockedUsers(),
                api.getMutedUsers()
            ]);
            setBlockedUsers(blocked.blocked_users);
            setMutedUsers(muted.muted_users);
        } catch (err) {
            setError('Failed to load settings');
        } finally {
            setLoading(false);
        }
    };

    const blockUser = async () => {
        if (!blockUsername.trim()) return;
        
        try {
            await api.blockUser(blockUsername);
            setBlockUsername('');
            loadData();
        } catch (err) {
            setError('Failed to block user');
        }
    };

    const unblockUser = async (username: string) => {
        try {
            await api.unblockUser(username);
            loadData();
        } catch (err) {
            setError('Failed to unblock user');
        }
    };

    const muteUser = async () => {
        if (!muteUsername.trim()) return;
        
        try {
            await api.muteUser(muteUsername);
            setMuteUsername('');
            loadData();
        } catch (err) {
            setError('Failed to mute user');
        }
    };

    const unmuteUser = async (username: string) => {
        try {
            await api.unmuteUser(username);
            loadData();
        } catch (err) {
            setError('Failed to unmute user');
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Settings</h1>

            {/* Blocked Users */}
            <Card className="mb-6">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Ban className="w-5 h-5" />
                        Blocked Users
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex gap-2 mb-4">
                        <Input
                            value={blockUsername}
                            onChange={(e) => setBlockUsername(e.target.value)}
                            placeholder="Username to block"
                        />
                        <Button onClick={blockUser}>
                            <Plus className="w-4 h-4" />
                        </Button>
                    </div>

                    {blockedUsers.length === 0 ? (
                        <p className="text-muted-foreground text-sm">
                            No blocked users
                        </p>
                    ) : (
                        <div className="space-y-2">
                            {blockedUsers.map((user) => (
                                <div 
                                    key={user.id}
                                    className="flex items-center justify-between p-2 bg-muted rounded"
                                >
                                    <div 
                                        className="cursor-pointer hover:underline"
                                        onClick={() => navigate(`/profile/${user.username}`)}
                                    >
                                        <span className="font-medium">@{user.username}</span>
                                        {user.display_name && (
                                            <span className="text-muted-foreground ml-2">
                                                {user.display_name}
                                            </span>
                                        )}
                                    </div>
                                    <Button 
                                        variant="ghost" 
                                        size="sm"
                                        onClick={() => unblockUser(user.username)}
                                    >
                                        <UserX className="w-4 h-4 mr-2" />
                                        Unblock
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Muted Users */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <VolumeX className="w-5 h-5" />
                        Muted Users
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex gap-2 mb-4">
                        <Input
                            value={muteUsername}
                            onChange={(e) => setMuteUsername(e.target.value)}
                            placeholder="Username to mute"
                        />
                        <Button onClick={muteUser}>
                            <Plus className="w-4 h-4" />
                        </Button>
                    </div>

                    {mutedUsers.length === 0 ? (
                        <p className="text-muted-foreground text-sm">
                            No muted users
                        </p>
                    ) : (
                        <div className="space-y-2">
                            {mutedUsers.map((user) => (
                                <div 
                                    key={user.id}
                                    className="flex items-center justify-between p-2 bg-muted rounded"
                                >
                                    <div 
                                        className="cursor-pointer hover:underline"
                                        onClick={() => navigate(`/profile/${user.username}`)}
                                    >
                                        <span className="font-medium">@{user.username}</span>
                                        {user.display_name && (
                                            <span className="text-muted-foreground ml-2">
                                                {user.display_name}
                                            </span>
                                        )}
                                    </div>
                                    <Button 
                                        variant="ghost" 
                                        size="sm"
                                        onClick={() => unmuteUser(user.username)}
                                    >
                                        Unmute
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
