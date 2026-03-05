import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Navbar } from './components/Navbar';
import { AuthPage } from './pages/AuthPage';
import { TimelinePage } from './pages/TimelinePage';
import { ProfilePage } from './pages/ProfilePage';
import { ExplorePage } from './pages/ExplorePage';
import { NotificationsPage } from './pages/NotificationsPage';
import { SearchPage } from './pages/SearchPage';
import { CommunitiesPage } from './pages/CommunitiesPage';
import { CommunityPage } from './pages/CommunityPage';
import { MessagesPage } from './pages/MessagesPage';
import { ListsPage } from './pages/ListsPage';
import { ListTimelinePage } from './pages/ListTimelinePage';
import { TrendingPage } from './pages/TrendingPage';
import { DraftsPage } from './pages/DraftsPage';
import { ScheduledPage } from './pages/ScheduledPage';
import { AnalyticsPage } from './pages/AnalyticsPage';
import { SettingsPage } from './pages/SettingsPage';
import { HashtagPage } from './pages/HashtagPage';
import { PostDetailPage } from './pages/PostDetailPage';
import './index.css';

function PrivateRoute({ children }: { children: React.ReactNode }) {
    const { isAuthenticated, isLoading } = useAuth();

    if (isLoading) return <div className="text-center py-12 text-muted-foreground">Loading...</div>;
    return isAuthenticated ? <>{children}</> : <Navigate to="/" replace />;
}

function PublicRoute({ children }: { children: React.ReactNode }) {
    const { isAuthenticated, isLoading } = useAuth();

    if (isLoading) return <div className="text-center py-12 text-muted-foreground">Loading...</div>;
    return !isAuthenticated ? <>{children}</> : <Navigate to="/timeline" replace />;
}

function AppContent() {
    const { isAuthenticated } = useAuth();

    return (
        <div className="app">
            {isAuthenticated && <Navbar />}
            <main>
                <Routes>
                    <Route 
                        path="/" 
                        element={
                            <PublicRoute>
                                <AuthPage />
                            </PublicRoute>
                        } 
                    />
                    <Route 
                        path="/timeline" 
                        element={
                            <PrivateRoute>
                                <TimelinePage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/explore" 
                        element={
                            <PrivateRoute>
                                <ExplorePage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/profile" 
                        element={
                            <PrivateRoute>
                                <ProfilePage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/profile/:username" 
                        element={
                            <PrivateRoute>
                                <ProfilePage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/notifications" 
                        element={
                            <PrivateRoute>
                                <NotificationsPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/search" 
                        element={
                            <PrivateRoute>
                                <SearchPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/communities" 
                        element={
                            <PrivateRoute>
                                <CommunitiesPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/communities/:id" 
                        element={
                            <PrivateRoute>
                                <CommunityPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/messages" 
                        element={
                            <PrivateRoute>
                                <MessagesPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/lists" 
                        element={
                            <PrivateRoute>
                                <ListsPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/lists/:id" 
                        element={
                            <PrivateRoute>
                                <ListTimelinePage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/trending" 
                        element={
                            <PrivateRoute>
                                <TrendingPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/drafts" 
                        element={
                            <PrivateRoute>
                                <DraftsPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/scheduled" 
                        element={
                            <PrivateRoute>
                                <ScheduledPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/analytics" 
                        element={
                            <PrivateRoute>
                                <AnalyticsPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/settings" 
                        element={
                            <PrivateRoute>
                                <SettingsPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/hashtag/:tag" 
                        element={
                            <PrivateRoute>
                                <HashtagPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route 
                        path="/post/:id" 
                        element={
                            <PrivateRoute>
                                <PostDetailPage />
                            </PrivateRoute>
                        } 
                    />
                    <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
            </main>
        </div>
    );
}

function App() {
    return (
        <BrowserRouter>
            <AuthProvider>
                <AppContent />
            </AuthProvider>
        </BrowserRouter>
    );
}

export default App;