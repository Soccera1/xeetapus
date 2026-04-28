import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useEffect, useState } from 'react';
import { api } from '../api';
import { Button } from '@/components/ui/button';
import {
    Search, Bell, Users, MessageCircle, List, TrendingUp,
    FileText, Calendar, BarChart3, Settings, MoreHorizontal, X, Server, Home, Compass, User
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

    const primaryItems = [
        { icon: Home, label: 'Timeline', path: '/timeline' },
        { icon: Compass, label: 'Explore', path: '/explore' },
        { icon: Users, label: 'Communities', path: '/communities' },
    ];

    return (
        <nav className="sticky top-0 z-40 border-b bg-card/95 backdrop-blur supports-[backdrop-filter]:bg-card/80">
            <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
                <Link to="/timeline" className="flex items-center gap-3 rounded-md transition-opacity hover:opacity-80">
                    <img src="/logo-black.svg" alt="Xeetapus" className="h-9 w-auto" />
                </Link>
                <div className="flex min-w-0 items-center gap-1 sm:gap-2">
                    {primaryItems.map((item) => (
                        <Link
                            key={item.path}
                            to={item.path}
                            className="hidden items-center gap-2 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground md:flex"
                        >
                            <item.icon className="h-4 w-4" />
                            {item.label}
                        </Link>
                    ))}
                    <Link
                        to="/search"
                        className="rounded-md p-2 text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
                        aria-label="Search"
                    >
                        <Search className="h-5 w-5" />
                    </Link>
                    <Link 
                        to="/messages" 
                        className="relative rounded-md p-2 text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
                        aria-label="Messages"
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
                        className="relative rounded-md p-2 text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
                        aria-label="Notifications"
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
                        className="rounded-md p-2 text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground sm:px-3"
                        aria-label="Profile"
                    >
                        <span className="hidden sm:inline">Profile</span>
                        <User className="h-5 w-5 sm:hidden" />
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
                            <div className="absolute right-0 top-full z-50 mt-2 w-56 overflow-hidden rounded-lg border bg-popover shadow-lg">
                                <div className="py-1">
                                    {moreMenuItems.map((item) => (
                                        <button
                                            key={item.path}
                                            onClick={() => {
                                                navigate(item.path);
                                                setShowMoreMenu(false);
                                            }}
                                            className="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-popover-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
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
                        className="hidden text-muted-foreground hover:text-destructive sm:inline-flex"
                    >
                        Logout
                    </Button>
                </div>
            </div>
        </nav>
    );
}
