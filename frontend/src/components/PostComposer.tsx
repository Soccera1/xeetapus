import { useState, useEffect } from 'react';
import { api } from '../api';
import type { Post } from '../types';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import { 
    Image, 
    BarChart3, 
    X, 
    Plus, 
    Clock, 
    Trash2
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

interface PostComposerProps {
    onPostCreated: () => void;
    replyToId?: number;
    replyToPost?: Post;
    quotePost?: Post;
}

export function PostComposer({ onPostCreated, replyToId, replyToPost, quotePost }: PostComposerProps) {
    const { user } = useAuth();
    const [content, setContent] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [showPoll, setShowPoll] = useState(false);
    const [pollOptions, setPollOptions] = useState(['', '']);
    const [pollDuration, setPollDuration] = useState(1440); // 24 hours in minutes
    const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
    const [mediaPreview, setMediaPreview] = useState<string[]>([]);

    // Clear quote post after submitting
    const [localQuotePost, setLocalQuotePost] = useState<Post | undefined>(quotePost);

    useEffect(() => {
        if (quotePost) {
            setLocalQuotePost(quotePost);
        }
    }, [quotePost]);

    useEffect(() => {
        if (replyToPost) {
            setContent(`@${replyToPost.username} `);
        }
    }, [replyToPost]);

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const files = Array.from(e.target.files || []);
        if (files.length + selectedFiles.length > 4) {
            alert('You can only upload up to 4 images/videos');
            return;
        }

        setSelectedFiles(prev => [...prev, ...files]);

        // Create previews
        files.forEach(file => {
            const reader = new FileReader();
            reader.onloadend = () => {
                setMediaPreview(prev => [...prev, reader.result as string]);
            };
            reader.readAsDataURL(file);
        });
    };

    const removeMedia = (index: number) => {
        setSelectedFiles(prev => prev.filter((_, i) => i !== index));
        setMediaPreview(prev => prev.filter((_, i) => i !== index));
    };

    const addPollOption = () => {
        if (pollOptions.length < 4) {
            setPollOptions([...pollOptions, '']);
        }
    };

    const removePollOption = (index: number) => {
        if (pollOptions.length > 2) {
            setPollOptions(pollOptions.filter((_, i) => i !== index));
        }
    };

    const updatePollOption = (index: number, value: string) => {
        const newOptions = [...pollOptions];
        newOptions[index] = value;
        setPollOptions(newOptions);
    };

    const clearQuotePost = () => {
        setLocalQuotePost(undefined);
    };

    const handleSubmit = async () => {
        if (!content.trim() && selectedFiles.length === 0) return;

        // Validate poll
        if (showPoll) {
            const validOptions = pollOptions.filter(opt => opt.trim());
            if (validOptions.length < 2) {
                alert('Please provide at least 2 poll options');
                return;
            }
        }

        setIsSubmitting(true);
        try {
            // Upload media first if there are files
            let mediaUrls: string | undefined;
            if (selectedFiles.length > 0) {
                // For now, we'll simulate media URLs. In a real app, you'd upload to a CDN
                mediaUrls = selectedFiles.map(() => `https://placeholder.com/media/${Date.now()}`).join(',');
            }

            const request: Parameters<typeof api.createPost>[0] = {
                content: content.trim(),
                media_urls: mediaUrls,
                reply_to_id: replyToId,
                quote_to_id: localQuotePost?.id,
            };

            // Add poll if enabled
            if (showPoll) {
                request.poll = {
                    question: content.trim() || 'Poll',
                    options: pollOptions.filter(opt => opt.trim()),
                    duration_minutes: pollDuration,
                };
            }

            await api.createPost(request);
            setContent('');
            setSelectedFiles([]);
            setMediaPreview([]);
            setShowPoll(false);
            setPollOptions(['', '']);
            setLocalQuotePost(undefined);
            onPostCreated();
        } catch (error) {
            alert(error instanceof Error ? error.message : 'Failed to create post');
        } finally {
            setIsSubmitting(false);
        }
    };

    const charCount = content.length;
    const isValid = (charCount > 0 || selectedFiles.length > 0) && charCount <= 280;

    const displayName = user?.display_name || user?.username || '';
    const initials = displayName.slice(0, 2).toUpperCase();

    return (
        <Card className="mb-4">
            <CardContent className="pt-6">
                {replyToPost && (
                    <div className="flex items-center gap-2 text-muted-foreground text-sm mb-3">
                        <span>Replying to</span>
                        <span className="text-blue-500">@{replyToPost.username}</span>
                    </div>
                )}

                {localQuotePost && (
                    <div className="mb-4">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-sm text-muted-foreground">Quoting</span>
                            <Button variant="ghost" size="sm" onClick={clearQuotePost}>
                                <X className="h-4 w-4" />
                            </Button>
                        </div>
                        <div className="border rounded-lg p-3 bg-muted/50">
                            <div className="flex items-center gap-2 mb-2">
                                <Avatar className="h-5 w-5">
                                    <AvatarImage src={localQuotePost.avatar_url || undefined} />
                                    <AvatarFallback className="text-xs">
                                        {(localQuotePost.display_name || localQuotePost.username).slice(0, 2).toUpperCase()}
                                    </AvatarFallback>
                                </Avatar>
                                <span className="font-medium text-sm">{localQuotePost.display_name || localQuotePost.username}</span>
                                <span className="text-muted-foreground text-sm">@{localQuotePost.username}</span>
                            </div>
                            <p className="text-sm text-muted-foreground line-clamp-2">
                                {localQuotePost.content}
                            </p>
                        </div>
                    </div>
                )}

                <div className="flex gap-3">
                    <Avatar className="h-10 w-10 flex-shrink-0">
                        <AvatarImage src={user?.avatar_url || undefined} />
                        <AvatarFallback>{initials}</AvatarFallback>
                    </Avatar>
                    <div className="flex-1">
                        <Textarea
                            value={content}
                            onChange={(e) => setContent(e.target.value)}
                            placeholder={replyToPost ? "Post your reply" : "What's happening?"}
                            maxLength={280}
                            rows={3}
                            className="resize-none border-none focus-visible:ring-0 p-0 text-lg"
                        />

                        {/* Media Preview */}
                        {mediaPreview.length > 0 && (
                            <div className={`grid gap-2 mb-4 ${mediaPreview.length > 1 ? 'grid-cols-2' : 'grid-cols-1'}`}>
                                {mediaPreview.map((preview, idx) => (
                                    <div key={idx} className="relative rounded-lg overflow-hidden">
                                        <img src={preview} alt={`Preview ${idx + 1}`} className="w-full h-32 object-cover" />
                                        <Button
                                            variant="destructive"
                                            size="sm"
                                            className="absolute top-2 right-2 h-6 w-6 p-0"
                                            onClick={() => removeMedia(idx)}
                                        >
                                            <X className="h-3 w-3" />
                                        </Button>
                                    </div>
                                ))}
                            </div>
                        )}

                        {/* Poll Creator */}
                        {showPoll && (
                            <div className="space-y-3 mb-4 p-3 border rounded-lg bg-muted/30">
                                <div className="flex items-center justify-between">
                                    <span className="font-medium">Create a poll</span>
                                    <Button variant="ghost" size="sm" onClick={() => setShowPoll(false)}>
                                        <X className="h-4 w-4" />
                                    </Button>
                                </div>
                                {pollOptions.map((option, idx) => (
                                    <div key={idx} className="flex gap-2">
                                        <Input
                                            placeholder={`Option ${idx + 1}`}
                                            value={option}
                                            onChange={(e) => updatePollOption(idx, e.target.value)}
                                            className="flex-1"
                                        />
                                        {pollOptions.length > 2 && (
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={() => removePollOption(idx)}
                                            >
                                                <Trash2 className="h-4 w-4" />
                                            </Button>
                                        )}
                                    </div>
                                ))}
                                {pollOptions.length < 4 && (
                                    <Button variant="outline" size="sm" onClick={addPollOption} className="w-full">
                                        <Plus className="h-4 w-4 mr-2" />
                                        Add option
                                    </Button>
                                )}
                                <div className="flex items-center gap-2">
                                    <Clock className="h-4 w-4 text-muted-foreground" />
                                    <select
                                        value={pollDuration}
                                        onChange={(e) => setPollDuration(Number(e.target.value))}
                                        className="bg-background border rounded px-2 py-1 text-sm"
                                    >
                                        <option value={5}>5 minutes</option>
                                        <option value={30}>30 minutes</option>
                                        <option value={60}>1 hour</option>
                                        <option value={360}>6 hours</option>
                                        <option value={1440}>1 day</option>
                                        <option value={10080}>7 days</option>
                                    </select>
                                </div>
                            </div>
                        )}

                        <Separator className="my-4" />

                        <div className="flex justify-between items-center">
                            <div className="flex items-center gap-2">
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-blue-500 hover:text-blue-600"
                                    onClick={() => document.getElementById('media-upload')?.click()}
                                >
                                    <Image className="h-5 w-5" />
                                </Button>
                                <input
                                    id="media-upload"
                                    type="file"
                                    accept="image/*,video/*"
                                    multiple
                                    className="hidden"
                                    onChange={handleFileSelect}
                                />
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className={`${showPoll ? 'text-blue-500' : 'text-blue-500 hover:text-blue-600'}`}
                                    onClick={() => setShowPoll(!showPoll)}
                                    disabled={!!localQuotePost}
                                >
                                    <BarChart3 className="h-5 w-5" />
                                </Button>
                            </div>
                            <div className="flex items-center gap-4">
                                <span className={`text-sm ${charCount > 260 ? 'text-yellow-500' : 'text-muted-foreground'}`}>
                                    {charCount}/280
                                </span>
                                <Button
                                    onClick={handleSubmit}
                                    disabled={!isValid || isSubmitting}
                                >
                                    {isSubmitting ? 'Posting...' : replyToPost ? 'Reply' : 'Post'}
                                </Button>
                            </div>
                        </div>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
}
