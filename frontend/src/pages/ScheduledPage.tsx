import { useState, useEffect } from 'react';
import { api } from '../api';
import type { ScheduledPost } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Textarea } from '../components/ui/textarea';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Calendar, Trash2, Plus, Clock } from 'lucide-react';

export function ScheduledPage() {
    const [scheduledPosts, setScheduledPosts] = useState<ScheduledPost[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [showCreateForm, setShowCreateForm] = useState(false);
    const [newContent, setNewContent] = useState('');
    const [scheduledDate, setScheduledDate] = useState('');
    const [scheduledTime, setScheduledTime] = useState('');

    useEffect(() => {
        loadScheduledPosts();
    }, []);

    const loadScheduledPosts = async () => {
        try {
            const data = await api.getScheduledPosts();
            setScheduledPosts(data.scheduled_posts);
        } catch (err) {
            setError('Failed to load scheduled posts');
        } finally {
            setLoading(false);
        }
    };

    const createScheduledPost = async () => {
        if (!newContent.trim() || !scheduledDate || !scheduledTime) return;
        
        try {
            const scheduledAt = `${scheduledDate}T${scheduledTime}:00`;
            await api.createScheduledPost(newContent, scheduledAt);
            setNewContent('');
            setScheduledDate('');
            setScheduledTime('');
            setShowCreateForm(false);
            loadScheduledPosts();
        } catch (err) {
            setError('Failed to schedule post');
        }
    };

    const deleteScheduledPost = async (id: number) => {
        if (!confirm('Cancel this scheduled post?')) return;
        
        try {
            await api.deleteScheduledPost(id);
            loadScheduledPosts();
        } catch (err) {
            setError('Failed to cancel scheduled post');
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold flex items-center gap-2">
                    <Calendar className="w-6 h-6" />
                    Scheduled Posts
                </h1>
                <Button onClick={() => setShowCreateForm(!showCreateForm)}>
                    <Plus className="w-4 h-4 mr-2" />
                    Schedule Post
                </Button>
            </div>

            {showCreateForm && (
                <Card className="mb-6">
                    <CardHeader>
                        <CardTitle>Schedule New Post</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div>
                            <Label htmlFor="content">Content</Label>
                            <Textarea
                                id="content"
                                value={newContent}
                                onChange={(e) => setNewContent(e.target.value)}
                                placeholder="What's happening?"
                                maxLength={280}
                            />
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <Label htmlFor="date">Date</Label>
                                <Input
                                    id="date"
                                    type="date"
                                    value={scheduledDate}
                                    onChange={(e) => setScheduledDate(e.target.value)}
                                />
                            </div>
                            <div>
                                <Label htmlFor="time">Time</Label>
                                <Input
                                    id="time"
                                    type="time"
                                    value={scheduledTime}
                                    onChange={(e) => setScheduledTime(e.target.value)}
                                />
                            </div>
                        </div>
                        <Button onClick={createScheduledPost} className="w-full">
                            Schedule
                        </Button>
                    </CardContent>
                </Card>
            )}

            {scheduledPosts.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <Calendar className="w-12 h-12 mx-auto mb-4" />
                        <p>No scheduled posts</p>
                        <p className="text-sm">Schedule posts to be published later</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="space-y-4">
                    {scheduledPosts.map((post) => (
                        <Card key={post.id}>
                            <CardContent className="p-4">
                                <p className="whitespace-pre-wrap mb-3">{post.content}</p>
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                                        <Clock className="w-4 h-4" />
                                        <span>
                                            Scheduled for {new Date(post.scheduled_at).toLocaleString()}
                                        </span>
                                    </div>
                                    <Button 
                                        variant="ghost" 
                                        size="icon"
                                        onClick={() => deleteScheduledPost(post.id)}
                                        className="text-red-500"
                                    >
                                        <Trash2 className="w-4 h-4" />
                                    </Button>
                                </div>
                            </CardContent>
                        </Card>
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
