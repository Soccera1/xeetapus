import { useEffect, useState } from 'react';
import { api } from '../api';
import type { Notification } from '../types';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Heart, Repeat2, MessageCircle, UserPlus, Check } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export function NotificationsPage() {
    const [notifications, setNotifications] = useState<Notification[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState('');
    const navigate = useNavigate();

    const loadNotifications = async () => {
        try {
            setIsLoading(true);
            const data = await api.getNotifications();
            setNotifications(data);
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to load notifications');
        } finally {
            setIsLoading(false);
        }
    };

    useEffect(() => {
        loadNotifications();
    }, []);

    const handleMarkAllAsRead = async () => {
        try {
            await api.markAllNotificationsAsRead();
            setNotifications(notifications.map(n => ({ ...n, read: true })));
        } catch (err) {
            alert(err instanceof Error ? err.message : 'Failed to mark as read');
        }
    };

    const handleNotificationClick = (notification: Notification) => {
        if (!notification.read) {
            api.markNotificationAsRead(notification.id);
        }
        
        if (notification.type === 'follow') {
            navigate(`/${notification.actor_username}`);
        } else if (notification.post_id) {
            navigate(`/post/${notification.post_id}`);
        }
    };

    const getNotificationIcon = (type: string) => {
        switch (type) {
            case 'like':
                return <Heart className="h-5 w-5 text-red-500" />;
            case 'repost':
                return <Repeat2 className="h-5 w-5 text-green-500" />;
            case 'comment':
                return <MessageCircle className="h-5 w-5 text-blue-500" />;
            case 'follow':
                return <UserPlus className="h-5 w-5 text-purple-500" />;
            default:
                return null;
        }
    };

    const getNotificationText = (notification: Notification) => {
        const name = notification.actor_display_name || notification.actor_username;
        switch (notification.type) {
            case 'like':
                return `${name} liked your post`;
            case 'repost':
                return `${name} reposted your post`;
            case 'comment':
                return `${name} commented on your post`;
            case 'follow':
                return `${name} started following you`;
            default:
                return '';
        }
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

    const unreadCount = notifications.filter(n => !n.read).length;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold">Notifications</h1>
                {unreadCount > 0 && (
                    <Button variant="outline" size="sm" onClick={handleMarkAllAsRead}>
                        <Check className="h-4 w-4 mr-2" />
                        Mark all as read
                    </Button>
                )}
            </div>
            
            {isLoading ? (
                <div className="text-center py-12 text-muted-foreground">Loading...</div>
            ) : error ? (
                <div className="text-center py-12 text-destructive">{error}</div>
            ) : notifications.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                    No notifications yet.
                </div>
            ) : (
                <div className="space-y-2">
                    {notifications.map(notification => (
                        <Card 
                            key={notification.id} 
                            className={`cursor-pointer transition-colors ${!notification.read ? 'bg-muted/50' : ''}`}
                            onClick={() => handleNotificationClick(notification)}
                        >
                            <CardContent className="p-4">
                                <div className="flex items-start gap-3">
                                    <div className="mt-1">
                                        {getNotificationIcon(notification.type)}
                                    </div>
                                    <Avatar className="h-10 w-10">
                                        <AvatarImage src={undefined} alt={notification.actor_username} />
                                        <AvatarFallback>
                                            {(notification.actor_display_name || notification.actor_username).slice(0, 2).toUpperCase()}
                                        </AvatarFallback>
                                    </Avatar>
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm">
                                            {getNotificationText(notification)}
                                        </p>
                                        <span className="text-muted-foreground text-xs">
                                            {formatTime(notification.created_at)}
                                        </span>
                                    </div>
                                    {!notification.read && (
                                        <div className="w-2 h-2 bg-blue-500 rounded-full mt-2" />
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