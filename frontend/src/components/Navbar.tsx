import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useEffect, useState } from 'react';
import { api } from '../api';
import { Button } from '@/components/ui/button';
import {
    Search, Bell, Users, MessageCircle, List, TrendingUp, 
    FileText, Calendar, BarChart3, Settings, MoreHorizontal, X, Server
} from 'lucide-react';

export function Navbar() {
    const { logout } = useAuth();
    const navigate = useNavigate();
    const [unreadCount, setUnreadCount] = useState(0);
    const [messageUnreadCount, setMessageUnreadCount] = useState(0);
    const [showMoreMenu, setShowMoreMenu] = useState(false);

    useEffect(() => {
        const fetchUnreadCounts = async () => {
            try {
                const [notifData, msgData] = await Promise.all([
                    api.getUnreadCount(),
                    api.getMessageUnreadCount()
                ]);
                setUnreadCount(notifData.unread_count);
                setMessageUnreadCount(msgData.unread_count);
            } catch {
                // Silently fail
            }
        };
        
        fetchUnreadCounts();
        const interval = setInterval(fetchUnreadCounts, 30000); // Check every 30 seconds
        
        return () => clearInterval(interval);
    }, []);

    const handleLogout = () => {
        logout();
        navigate('/');
    };

    const moreMenuItems = [
        { icon: TrendingUp, label: 'Trending', path: '/trending' },
        { icon: List, label: 'Lists', path: '/lists' },
        { icon: FileText, label: 'Drafts', path: '/drafts' },
        { icon: Calendar, label: 'Scheduled', path: '/scheduled' },
        { icon: BarChart3, label: 'Analytics', path: '/analytics' },
        { icon: Server, label: 'Status', path: '/status' },
        { icon: Settings, label: 'Settings', path: '/settings' },
    ];

    return (
        <nav className="border-b bg-card">
            <div className="max-w-4xl mx-auto px-4 h-16 flex items-center justify-between">
                <Link to="/timeline" className="hover:opacity-80 transition-opacity">
                    <img src="/logo-black.svg" alt="Xeetapus" className="h-10 w-auto" />
                </Link>
                <div className="flex items-center gap-6">
                    <Link 
                        to="/search" 
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        <Search className="h-5 w-5" />
                    </Link>
                    <Link 
                        to="/timeline" 
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        Timeline
                    </Link>
                    <Link 
                        to="/explore" 
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        Explore
                    </Link>
                    <Link 
                        to="/communities" 
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        <Users className="h-5 w-5" />
                    </Link>
                    <Link 
                        to="/messages" 
                        className="text-muted-foreground hover:text-foreground transition-colors relative"
                    >
                        <MessageCircle className="h-5 w-5" />
                        {messageUnreadCount > 0 && (
                            <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                                {messageUnreadCount > 9 ? '9+' : messageUnreadCount}
                            </span>
                        )}
                    </Link>
                    <Link 
                        to="/notifications" 
                        className="text-muted-foreground hover:text-foreground transition-colors relative"
                    >
                        <Bell className="h-5 w-5" />
                        {unreadCount > 0 && (
                            <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                                {unreadCount > 9 ? '9+' : unreadCount}
                            </span>
                        )}
                    </Link>
                    <Link 
                        to="/profile" 
                        className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                        Profile
                    </Link>
                    
                    <div className="relative">
                        <Button 
                            variant="ghost" 
                            size="icon" 
                            className="text-muted-foreground"
                            onClick={() => setShowMoreMenu(!showMoreMenu)}
                        >
                            {showMoreMenu ? <X className="h-5 w-5" /> : <MoreHorizontal className="h-5 w-5" />}
                        </Button>
                        
                        {showMoreMenu && (
                            <div className="absolute right-0 top-full mt-2 w-56 bg-popover border rounded-md shadow-lg z-50">
                                <div className="py-1">
                                    {moreMenuItems.map((item) => (
                                        <button
                                            key={item.path}
                                            onClick={() => {
                                                navigate(item.path);
                                                setShowMoreMenu(false);
                                            }}
                                            className="w-full flex items-center gap-2 px-4 py-2 text-sm hover:bg-muted transition-colors text-left"
                                        >
                                            <item.icon className="h-4 w-4" />
                                            {item.label}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>

                    <Button 
                        variant="ghost" 
                        size="sm"
                        onClick={handleLogout}
                        className="text-muted-foreground hover:text-destructive"
                    >
                        Logout
                    </Button>
                </div>
            </div>
        </nav>
    );
}
