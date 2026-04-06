export interface User {
    id: number;
    username: string;
    email: string;
    display_name?: string;
    bio?: string;
    avatar_url?: string | null;
    created_at: string;
    token?: string;
    password_migration_status?: 'pending' | 'completed';
}

export interface LoginResponse extends User {
    password_migrated?: boolean;
    migration_message?: string;
}

export interface Post {
    id: number;
    user_id: number;
    username: string;
    display_name: string;
    avatar_url: string | null;
    content: string;
    media_urls?: string;
    reply_to_id?: number;
    quote_to_id?: number;
    quote_to_post?: Post;
    poll_id?: number;
    poll?: PollWithOptions;
    view_count?: number;
    is_liked: boolean;
    is_reposted: boolean;
    is_bookmarked: boolean;
    is_pinned?: boolean;
    created_at: string;
    likes_count: number;
    comments_count: number;
    reposts_count: number;
}

export interface PollWithOptions extends Poll {
    options: PollOption[];
    has_voted?: boolean;
    selected_option?: number;
}

export interface Profile {
    id: number;
    username: string;
    display_name?: string;
    bio?: string;
    avatar_url?: string;
    created_at: string;
    followers_count: number;
    following_count: number;
    posts_count: number;
    is_following: boolean;
}

export interface Comment {
    id: number;
    user_id: number;
    username: string;
    display_name: string;
    avatar_url: string;
    content: string;
    created_at: string;
}

export interface LoginRequest {
    username: string;
    password: string;
}

export interface RegisterRequest {
    username: string;
    email: string;
    password: string;
}

export interface CreatePostRequest {
    content: string;
    media_urls?: string;
    reply_to_id?: number;
    quote_to_id?: number;
    poll?: CreatePollRequest;
}

export interface CreatePollRequest {
    question: string;
    options: string[];
    duration_minutes: number;
}

export interface CommentRequest {
    content: string;
}

export interface Notification {
    id: number;
    actor_id: number;
    actor_username: string;
    actor_display_name: string;
    type: 'like' | 'repost' | 'comment' | 'follow';
    post_id?: number;
    read: boolean;
    created_at: string;
}

export interface Community {
    id: number;
    name: string;
    description?: string;
    icon_url?: string;
    banner_url?: string;
    created_by: number;
    created_at: string;
    member_count: number;
    post_count: number;
    is_member: boolean;
}

export interface CreateCommunityRequest {
    name: string;
    description?: string;
    icon_url?: string;
    banner_url?: string;
}

// Direct Messages
export interface Conversation {
    id: number;
    created_at: string;
    updated_at: string;
    participants: string;
    last_message?: string;
    unread_count: number;
}

export interface Message {
    id: number;
    conversation_id: number;
    sender_id: number;
    sender_username: string;
    sender_display_name?: string;
    content: string;
    media_urls?: string;
    read: boolean;
    created_at: string;
}

// Lists
export interface UserList {
    id: number;
    owner_id: number;
    name: string;
    description?: string;
    is_private: boolean;
    member_count: number;
    created_at: string;
}

export interface ListMember {
    id: number;
    username: string;
    display_name?: string;
    avatar_url?: string;
    added_at: string;
}

// Hashtags
export interface Hashtag {
    id: number;
    tag: string;
    use_count: number;
}

// Polls
export interface Poll {
    id: number;
    post_id: number;
    question: string;
    duration_minutes: number;
    created_at: string;
    ends_at?: string;
}

export interface PollOption {
    id: number;
    poll_id: number;
    option_text: string;
    position: number;
    vote_count: number;
}

// Drafts
export interface Draft {
    id: number;
    user_id: number;
    content: string;
    media_urls?: string;
    created_at: string;
    updated_at: string;
}

// Scheduled Posts
export interface ScheduledPost {
    id: number;
    user_id: number;
    content: string;
    media_urls?: string;
    scheduled_at: string;
    created_at: string;
    is_posted: boolean;
}

// Analytics
export interface UserAnalytics {
    total_views: number;
    total_posts: number;
    total_likes_received: number;
    total_reposts_received: number;
}

// Blocked/Muted Users
export interface BlockedUser {
    id: number;
    username: string;
    display_name?: string;
    avatar_url?: string;
    blocked_at: string;
}

export interface MutedUser {
    id: number;
    username: string;
    display_name?: string;
    avatar_url?: string;
    muted_at: string;
}

export type LlmProviderId =
    | 'openai'
    | 'anthropic'
    | 'openrouter'
    | 'groq'
    | 'google'
    | 'together';

export interface LlmProvider {
    id: LlmProviderId;
    label: string;
    description: string;
    default_model: string;
    supports_custom_base_url: boolean;
}

export interface LlmConfigSummary {
    provider: LlmProviderId;
    configured: boolean;
    masked_api_key: string;
    model: string;
    base_url?: string;
    is_default: boolean;
    updated_at: string;
}

export interface LlmChatMessage {
    role: 'user' | 'assistant';
    content: string;
}

export interface LlmChatResponse {
    provider: LlmProviderId;
    model: string;
    reply: string;
}

export type FeePriority = 'slow' | 'normal' | 'fast' | 'fastest';

export interface FeeEstimate {
    fee_per_byte: number;
    estimated_tx_fee_xmr: number;
    estimated_tx_fee_usd: number | null;
    estimated_minutes: number;
}

export interface ExchangeRate {
    xmr_usd: number | null;
    last_updated: number;
    cache_ttl_seconds: number;
    fees: {
        slow: FeeEstimate;
        normal: FeeEstimate;
        fast: FeeEstimate;
        fastest: FeeEstimate;
    };
}

export interface CreateInvoiceRequest {
    amount?: number;
    currency?: string;
    xmr_amount?: number;
    priority?: FeePriority;
    memo?: string;
}

export interface Invoice {
    id: number;
    address: string;
    xmr_amount: number;
    network_fee: number;
    total_xmr: number;
    fiat_amount?: number;
    fiat_currency?: string;
    network_fee_usd?: number;
    xmr_price_usd?: number;
    priority: string;
    estimated_minutes: number;
    status: 'pending' | 'paid' | 'expired';
}

export interface InvoiceStatus {
    id: number;
    amount: number;
    status: string;
    created_at: string;
    paid_at?: string;
}

export interface PaymentBalance {
    balance: number;
}
