import { useState, useEffect } from 'react';
import { api } from '../api';
import { useAuth } from '../context/AuthContext';
import type { Conversation, Message } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Send, MessageCircle, Image, X } from 'lucide-react';

export function MessagesPage() {
    const { user } = useAuth();
    const [conversations, setConversations] = useState<Conversation[]>([]);
    const [selectedConversation, setSelectedConversation] = useState<number | null>(null);
    const [messages, setMessages] = useState<Message[]>([]);
    const [newMessage, setNewMessage] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
    const [mediaPreview, setMediaPreview] = useState<string[]>([]);
    const [isSending, setIsSending] = useState(false);

    useEffect(() => {
        loadConversations();
    }, []);

    useEffect(() => {
        if (selectedConversation) {
            loadMessages(selectedConversation);
        }
    }, [selectedConversation]);

    const loadConversations = async () => {
        try {
            const data = await api.getConversations();
            setConversations(data.conversations);
        } catch (err) {
            setError('Failed to load conversations');
        } finally {
            setLoading(false);
        }
    };

    const loadMessages = async (conversationId: number) => {
        try {
            const data = await api.getMessages(conversationId);
            setMessages(data.messages);
        } catch (err) {
            setError('Failed to load messages');
        }
    };

    const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
        const files = Array.from(e.target.files || []);
        e.target.value = '';

        if (files.length + selectedFiles.length > 4) {
            setError('You can only upload up to 4 images/videos');
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

    const sendMessage = async () => {
        if (!selectedConversation || (!newMessage.trim() && selectedFiles.length === 0)) return;
        
        setIsSending(true);
        try {
            // Upload media first if there are files
            let mediaUrls: string | undefined;
            if (selectedFiles.length > 0) {
                const uploadResults = await Promise.all(
                    selectedFiles.map(file => api.uploadMedia(file, false))
                );
                mediaUrls = uploadResults.map(result => result.url).join(',');
            }

            await api.sendMessage(selectedConversation, newMessage, mediaUrls);
            setNewMessage('');
            setSelectedFiles([]);
            setMediaPreview([]);
            loadMessages(selectedConversation);
            loadConversations();
        } catch (err) {
            setError('Failed to send message');
        } finally {
            setIsSending(false);
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-4xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Messages</h1>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {/* Conversations List */}
                <Card className="md:col-span-1">
                    <CardHeader>
                        <CardTitle>Conversations</CardTitle>
                    </CardHeader>
                    <CardContent>
                        {conversations.length === 0 ? (
                            <p className="text-muted-foreground">No conversations yet</p>
                        ) : (
                            <div className="space-y-2">
                                {conversations.map((conv) => (
                                    <button
                                        key={conv.id}
                                        onClick={() => setSelectedConversation(conv.id)}
                                        className={`w-full text-left p-3 rounded-lg transition-colors ${
                                            selectedConversation === conv.id
                                                ? 'bg-primary text-primary-foreground'
                                                : 'hover:bg-muted'
                                        }`}
                                    >
                                        <div className="flex items-center justify-between">
                                            <span className="font-medium">{conv.participants}</span>
                                            {conv.unread_count > 0 && (
                                                <span className="bg-red-500 text-white text-xs px-2 py-1 rounded-full">
                                                    {conv.unread_count}
                                                </span>
                                            )}
                                        </div>
                                        {conv.last_message && (
                                            <p className="text-sm truncate mt-1 opacity-80">
                                                {conv.last_message}
                                            </p>
                                        )}
                                    </button>
                                ))}
                            </div>
                        )}
                    </CardContent>
                </Card>

                {/* Messages */}
                <Card className="md:col-span-2">
                    <CardHeader>
                        <CardTitle>
                            {selectedConversation
                                ? 'Conversation'
                                : 'Select a conversation'}
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {!selectedConversation ? (
                            <div className="text-center py-12 text-muted-foreground">
                                <MessageCircle className="w-12 h-12 mx-auto mb-4" />
                                <p>Select a conversation to view messages</p>
                            </div>
                        ) : (
                            <>
                                <div className="space-y-4 mb-4 max-h-96 overflow-y-auto">
                                    {messages.length === 0 ? (
                                        <p className="text-muted-foreground text-center">
                                            No messages yet
                                        </p>
                                    ) : (
                                        messages.map((msg) => {
                                            const mediaUrls = msg.media_urls ? msg.media_urls.split(',').filter(url => url.trim()) : [];
                                            return (
                                                <div
                                                    key={msg.id}
                                                    className={`p-3 rounded-lg ${
                                                        user && msg.sender_id === user.id
                                                            ? 'bg-primary text-primary-foreground ml-auto'
                                                            : 'bg-muted'
                                                    } max-w-[80%]`}
                                                >
                                                    <p className="text-sm font-medium mb-1">
                                                        {msg.sender_display_name || msg.sender_username}
                                                    </p>
                                                    <p>{msg.content}</p>
                                                    {mediaUrls.length > 0 && (
                                                        <div className={`grid gap-2 mt-2 ${mediaUrls.length > 1 ? 'grid-cols-2' : 'grid-cols-1'}`}>
                                                            {mediaUrls.map((url, idx) => (
                                                                <div key={idx} className="relative rounded-lg overflow-hidden bg-muted">
                                                                    {url.match(/\.(jpg|jpeg|png|gif|webp)$/i) ? (
                                                                        <img
                                                                            src={url}
                                                                            alt={`Media ${idx + 1}`}
                                                                            className="w-full h-auto max-h-48 object-cover"
                                                                            loading="lazy"
                                                                        />
                                                                    ) : url.match(/\.(mp4|webm|mov)$/i) ? (
                                                                        <video
                                                                            src={url}
                                                                            controls
                                                                            className="w-full h-auto max-h-48"
                                                                        />
                                                                    ) : (
                                                                        <div className="flex items-center gap-2 p-2">
                                                                            <Image className="h-4 w-4" />
                                                                            <a href={url} target="_blank" rel="noopener noreferrer" className="text-blue-500 hover:underline text-sm">
                                                                                View media
                                                                            </a>
                                                                        </div>
                                                                    )}
                                                                </div>
                                                            ))}
                                                        </div>
                                                    )}
                                                    <p className="text-xs opacity-70 mt-1">
                                                        {new Date(msg.created_at).toLocaleString()}
                                                    </p>
                                                </div>
                                            );
                                        })
                                    )}
                                </div>
                                
                                {mediaPreview.length > 0 && (
                                    <div className="grid grid-cols-4 gap-2 mb-3">
                                        {mediaPreview.map((preview, idx) => (
                                            <div key={idx} className="relative">
                                                <img
                                                    src={preview}
                                                    alt={`Preview ${idx + 1}`}
                                                    className="w-full h-20 object-cover rounded-lg"
                                                />
                                                <button
                                                    type="button"
                                                    onClick={() => removeMedia(idx)}
                                                    className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 hover:bg-red-600"
                                                >
                                                    <X className="w-3 h-3" />
                                                </button>
                                            </div>
                                        ))}
                                    </div>
                                )}
                                <div className="flex gap-2">
                                    <input
                                        type="file"
                                        accept="image/*,video/*"
                                        multiple
                                        onChange={handleFileSelect}
                                        className="hidden"
                                        id="message-media-input"
                                    />
                                    <Button
                                        type="button"
                                        variant="outline"
                                        size="icon"
                                        onClick={() => document.getElementById('message-media-input')?.click()}
                                        disabled={isSending}
                                    >
                                        <Image className="w-4 h-4" />
                                    </Button>
                                    <Input
                                        value={newMessage}
                                        onChange={(e) => setNewMessage(e.target.value)}
                                        placeholder="Type a message..."
                                        onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                                        disabled={isSending}
                                    />
                                    <Button type="button" onClick={sendMessage} size="icon" disabled={isSending || (!newMessage.trim() && selectedFiles.length === 0)}>
                                        <Send className="w-4 h-4" />
                                    </Button>
                                </div>
                            </>
                        )}
                    </CardContent>
                </Card>
            </div>

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
