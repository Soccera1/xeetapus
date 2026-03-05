import type { User, Post, Profile, Comment, Notification, LoginRequest, RegisterRequest, CreatePostRequest, CommentRequest, Community, CreateCommunityRequest, Conversation, Message, UserList, ListMember, Hashtag, PollOption, Draft, ScheduledPost, UserAnalytics, BlockedUser, MutedUser } from './types';

const API_BASE_URL = import.meta.env.VITE_API_URL || '/api';

export class ApiClient {
    private token: string | null = null;
    private csrfToken: string | null = null;

    constructor() {
        // Token is now stored in httpOnly cookie, so we don't load from localStorage
        // But we keep this for backward compatibility during migration
        this.token = localStorage.getItem('token');
        this.csrfToken = localStorage.getItem('csrf_token');
        
        // If there's a token in localStorage, migrate it by clearing it
        if (this.token) {
            localStorage.removeItem('token');
            this.token = null;
        }
    }

    setToken(token: string): void {
        this.token = token;
        // Don't store token in localStorage anymore - it's in httpOnly cookie
    }

    clearToken(): void {
        this.token = null;
        localStorage.removeItem('token');
        localStorage.removeItem('csrf_token');
    }

    isAuthenticated(): boolean {
        // Check cookie-based auth - we'll rely on the server to tell us
        return true; // Optimistic - actual check happens on API calls
    }

    getToken(): string | null {
        return this.token;
    }

    setCsrfToken(token: string): void {
        this.csrfToken = token;
        localStorage.setItem('csrf_token', token);
    }

    private getCsrfToken(): string | null {
        return this.csrfToken;
    }

    private async fetch(endpoint: string, options: RequestInit = {}): Promise<any> {
        const url = `${API_BASE_URL}${endpoint}`;
        const headers: Record<string, string> = {
            'Content-Type': 'application/json',
            ...options.headers as Record<string, string>
        };

        // Add CSRF token for state-changing operations
        const method = options.method || 'GET';
        if (method !== 'GET' && method !== 'HEAD' && this.csrfToken) {
            headers['X-CSRF-Token'] = this.csrfToken;
        }

        // Include credentials to send cookies
        const response = await fetch(url, {
            ...options,
            headers,
            credentials: 'include', // Important: send cookies with requests
        });

        if (!response.ok) {
            if (response.status === 401) {
                // Clear auth state on 401
                this.clearToken();
                // Optionally redirect to login
                window.dispatchEvent(new CustomEvent('auth:unauthorized'));
            }
            
            if (response.status === 429) {
                const retryAfter = response.headers.get('Retry-After');
                const error: any = new Error('Rate limit exceeded. Please try again later.');
                error.retryAfter = retryAfter;
                error.status = 429;
                throw error;
            }
            
            const error = await response.json().catch(() => ({ error: 'Unknown error' }));
            throw new Error(error.error || `HTTP ${response.status}`);
        }

        if (response.status === 204) {
            return null;
        }

        return response.json();
    }

    async register(data: RegisterRequest): Promise<User> {
        const response = await this.fetch('/auth/register', {
            method: 'POST',
            body: JSON.stringify(data)
        });
        if (response.token) {
            this.setToken(response.token);
        }
        if (response.csrf_token) {
            this.setCsrfToken(response.csrf_token);
        }
        return response;
    }

    async login(data: LoginRequest): Promise<User> {
        const response = await this.fetch('/auth/login', {
            method: 'POST',
            body: JSON.stringify(data)
        });
        if (response.token) {
            this.setToken(response.token);
        }
        if (response.csrf_token) {
            this.setCsrfToken(response.csrf_token);
        }
        return response;
    }

    async logout(): Promise<void> {
        await this.fetch('/auth/logout', {
            method: 'POST'
        });
        this.clearToken();
    }

    async me(): Promise<User> {
        return this.fetch('/auth/me');
    }

    async createPost(data: CreatePostRequest): Promise<{ id: number; content: string; created: boolean }> {
        return this.fetch('/posts', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async getPosts(): Promise<Post[]> {
        return this.fetch('/posts');
    }

    async getPost(id: number): Promise<Post> {
        return this.fetch(`/posts/${id}`);
    }

    async deletePost(id: number): Promise<{ deleted: boolean }> {
        return this.fetch(`/posts/${id}`, {
            method: 'DELETE'
        });
    }

    async likePost(id: number): Promise<{ liked: boolean }> {
        return this.fetch(`/posts/${id}/like`, {
            method: 'POST'
        });
    }

    async unlikePost(id: number): Promise<{ unliked: boolean }> {
        return this.fetch(`/posts/${id}/like`, {
            method: 'DELETE'
        });
    }

    async commentOnPost(id: number, data: CommentRequest): Promise<{ id: number; created: boolean }> {
        return this.fetch(`/posts/${id}/comment`, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async getComments(id: number): Promise<Comment[]> {
        return this.fetch(`/posts/${id}/comments`);
    }

    async getProfile(username: string): Promise<Profile> {
        return this.fetch(`/users/${username}`);
    }

    async getUserPosts(username: string): Promise<Post[]> {
        return this.fetch(`/users/${username}/posts`);
    }

    async followUser(username: string): Promise<{ following: boolean }> {
        return this.fetch(`/users/${username}/follow`, {
            method: 'POST'
        });
    }

    async unfollowUser(username: string): Promise<{ unfollowed: boolean }> {
        return this.fetch(`/users/${username}/follow`, {
            method: 'DELETE'
        });
    }

    async getFollowers(username: string): Promise<User[]> {
        return this.fetch(`/users/${username}/followers`);
    }

    async getFollowing(username: string): Promise<User[]> {
        return this.fetch(`/users/${username}/following`);
    }

    async getTimeline(): Promise<Post[]> {
        return this.fetch('/timeline');
    }

    async getExplore(): Promise<Post[]> {
        return this.fetch('/timeline/explore');
    }

    async repostPost(id: number): Promise<{ reposted: boolean }> {
        return this.fetch(`/posts/${id}/repost`, {
            method: 'POST'
        });
    }

    async unrepostPost(id: number): Promise<{ unreposted: boolean }> {
        return this.fetch(`/posts/${id}/repost`, {
            method: 'DELETE'
        });
    }

    async bookmarkPost(id: number): Promise<{ bookmarked: boolean }> {
        return this.fetch(`/posts/${id}/bookmark`, {
            method: 'POST'
        });
    }

    async unbookmarkPost(id: number): Promise<{ unbookmarked: boolean }> {
        return this.fetch(`/posts/${id}/bookmark`, {
            method: 'DELETE'
        });
    }

    async getNotifications(): Promise<Notification[]> {
        return this.fetch('/notifications');
    }

    async markNotificationAsRead(id: number): Promise<{ read: boolean }> {
        return this.fetch(`/notifications/${id}/read`, {
            method: 'POST'
        });
    }

    async markAllNotificationsAsRead(): Promise<{ read: boolean }> {
        return this.fetch('/notifications/read-all', {
            method: 'POST'
        });
    }

    async getUnreadCount(): Promise<{ unread_count: number }> {
        return this.fetch('/notifications/unread-count');
    }

    async searchUsers(query: string): Promise<User[]> {
        return this.fetch(`/search/users?q=${encodeURIComponent(query)}`);
    }

    async searchPosts(query: string): Promise<Post[]> {
        return this.fetch(`/search/posts?q=${encodeURIComponent(query)}`);
    }

    // Community methods
    async getCommunities(): Promise<Community[]> {
        return this.fetch('/communities');
    }

    async getCommunity(id: number): Promise<Community> {
        return this.fetch(`/communities/${id}`);
    }

    async createCommunity(data: CreateCommunityRequest): Promise<{ id: number; name: string; created: boolean }> {
        return this.fetch('/communities', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async joinCommunity(id: number): Promise<{ joined: boolean }> {
        return this.fetch(`/communities/${id}/join`, {
            method: 'POST'
        });
    }

    async leaveCommunity(id: number): Promise<{ left: boolean }> {
        return this.fetch(`/communities/${id}/join`, {
            method: 'DELETE'
        });
    }

    async getCommunityPosts(id: number): Promise<Post[]> {
        return this.fetch(`/communities/${id}/posts`);
    }

    async createCommunityPost(id: number, data: CreatePostRequest): Promise<{ id: number; content: string; created: boolean }> {
        return this.fetch(`/communities/${id}/posts`, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async getCommunityMembers(id: number): Promise<User[]> {
        return this.fetch(`/communities/${id}/members`);
    }

    // Direct Messages
    async getConversations(): Promise<{ conversations: Conversation[] }> {
        return this.fetch('/messages/conversations');
    }

    async createConversation(participantIds: number[]): Promise<{ id: number; message: string }> {
        return this.fetch('/messages/conversations', {
            method: 'POST',
            body: JSON.stringify({ participant_ids: participantIds })
        });
    }

    async getMessages(conversationId: number): Promise<{ messages: Message[] }> {
        return this.fetch(`/messages/conversations/${conversationId}`);
    }

    async sendMessage(conversationId: number, content: string, mediaUrls?: string): Promise<{ id: number; message: string }> {
        return this.fetch(`/messages/conversations/${conversationId}`, {
            method: 'POST',
            body: JSON.stringify({ content, media_urls: mediaUrls })
        });
    }

    async getMessageUnreadCount(): Promise<{ unread_count: number }> {
        return this.fetch('/messages/unread-count');
    }

    // Lists
    async getLists(): Promise<{ lists: UserList[] }> {
        return this.fetch('/lists');
    }

    async createList(name: string, description?: string, isPrivate?: boolean): Promise<{ id: number; message: string }> {
        return this.fetch('/lists', {
            method: 'POST',
            body: JSON.stringify({ name, description, is_private: isPrivate })
        });
    }

    async getList(id: number): Promise<{ list: UserList; members: ListMember[] }> {
        return this.fetch(`/lists/${id}`);
    }

    async deleteList(id: number): Promise<{ message: string }> {
        return this.fetch(`/lists/${id}`, {
            method: 'DELETE'
        });
    }

    async addListMember(listId: number, userId: number): Promise<{ message: string }> {
        return this.fetch(`/lists/${listId}/members`, {
            method: 'POST',
            body: JSON.stringify({ user_id: userId })
        });
    }

    async removeListMember(listId: number, userId: number): Promise<{ message: string }> {
        return this.fetch(`/lists/${listId}/members/${userId}`, {
            method: 'DELETE'
        });
    }

    async getListTimeline(listId: number): Promise<{ posts: Post[] }> {
        return this.fetch(`/lists/${listId}/timeline`);
    }

    // Hashtags
    async getTrendingHashtags(): Promise<{ trending: Hashtag[] }> {
        return this.fetch('/hashtags/trending');
    }

    async getPostsByHashtag(tag: string): Promise<{ posts: Post[]; hashtag: string }> {
        return this.fetch(`/hashtags/${tag}/posts`);
    }

    // Polls
    async voteOnPoll(pollId: number, optionId: number): Promise<{ message: string }> {
        return this.fetch(`/polls/${pollId}/vote`, {
            method: 'POST',
            body: JSON.stringify({ option_id: optionId })
        });
    }

    async getPollResults(pollId: number): Promise<{ options: PollOption[]; total_votes: number }> {
        return this.fetch(`/polls/${pollId}/results`);
    }

    // Blocks & Mutes
    async blockUser(username: string): Promise<{ message: string }> {
        return this.fetch(`/users/${username}/block`, {
            method: 'POST'
        });
    }

    async unblockUser(username: string): Promise<{ message: string }> {
        return this.fetch(`/users/${username}/block`, {
            method: 'DELETE'
        });
    }

    async getBlockedUsers(): Promise<{ blocked_users: BlockedUser[] }> {
        return this.fetch('/blocks');
    }

    async muteUser(username: string): Promise<{ message: string }> {
        return this.fetch(`/users/${username}/mute`, {
            method: 'POST'
        });
    }

    async unmuteUser(username: string): Promise<{ message: string }> {
        return this.fetch(`/users/${username}/mute`, {
            method: 'DELETE'
        });
    }

    async getMutedUsers(): Promise<{ muted_users: MutedUser[] }> {
        return this.fetch('/mutes');
    }

    // Drafts
    async getDrafts(): Promise<{ drafts: Draft[] }> {
        return this.fetch('/drafts');
    }

    async createDraft(content: string, mediaUrls?: string): Promise<{ id: number; message: string }> {
        return this.fetch('/drafts', {
            method: 'POST',
            body: JSON.stringify({ content, media_urls: mediaUrls })
        });
    }

    async updateDraft(id: number, content: string, mediaUrls?: string): Promise<{ message: string }> {
        return this.fetch(`/drafts/${id}`, {
            method: 'PUT',
            body: JSON.stringify({ content, media_urls: mediaUrls })
        });
    }

    async deleteDraft(id: number): Promise<{ message: string }> {
        return this.fetch(`/drafts/${id}`, {
            method: 'DELETE'
        });
    }

    // Scheduled Posts
    async getScheduledPosts(): Promise<{ scheduled_posts: ScheduledPost[] }> {
        return this.fetch('/scheduled');
    }

    async createScheduledPost(content: string, scheduledAt: string, mediaUrls?: string): Promise<{ id: number; message: string }> {
        return this.fetch('/scheduled', {
            method: 'POST',
            body: JSON.stringify({ content, scheduled_at: scheduledAt, media_urls: mediaUrls })
        });
    }

    async deleteScheduledPost(id: number): Promise<{ message: string }> {
        return this.fetch(`/scheduled/${id}`, {
            method: 'DELETE'
        });
    }

    // Pinned Posts
    async pinPost(id: number): Promise<{ pinned: boolean }> {
        return this.fetch(`/posts/${id}/pin`, {
            method: 'POST'
        });
    }

    async unpinPost(id: number): Promise<{ unpinned: boolean }> {
        return this.fetch(`/posts/${id}/pin`, {
            method: 'DELETE'
        });
    }

    // Analytics
    async recordPostView(id: number): Promise<{ recorded: boolean }> {
        return this.fetch(`/posts/${id}/view`, {
            method: 'POST'
        });
    }

    async getPostViews(id: number): Promise<{ view_count: number }> {
        return this.fetch(`/analytics/posts/${id}/views`);
    }

    async getUserAnalytics(): Promise<UserAnalytics> {
        return this.fetch('/analytics/me');
    }
}

export const api = new ApiClient();
