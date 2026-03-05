import { useState, useEffect } from 'react';
import { api } from '../api';
import type { Conversation, Message } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Send, MessageCircle } from 'lucide-react';

export function MessagesPage() {
    const [conversations, setConversations] = useState<Conversation[]>([]);
    const [selectedConversation, setSelectedConversation] = useState<number | null>(null);
    const [messages, setMessages] = useState<Message[]>([]);
    const [newMessage, setNewMessage] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

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

    const sendMessage = async () => {
        if (!selectedConversation || !newMessage.trim()) return;
        
        try {
            await api.sendMessage(selectedConversation, newMessage);
            setNewMessage('');
            loadMessages(selectedConversation);
            loadConversations();
        } catch (err) {
            setError('Failed to send message');
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
                                        messages.map((msg) => (
                                            <div
                                                key={msg.id}
                                                className={`p-3 rounded-lg ${
                                                    msg.sender_id === 1
                                                        ? 'bg-primary text-primary-foreground ml-auto'
                                                        : 'bg-muted'
                                                } max-w-[80%]`}
                                            >
                                                <p className="text-sm font-medium mb-1">
                                                    {msg.sender_display_name || msg.sender_username}
                                                </p>
                                                <p>{msg.content}</p>
                                                <p className="text-xs opacity-70 mt-1">
                                                    {new Date(msg.created_at).toLocaleString()}
                                                </p>
                                            </div>
                                        ))
                                    )}
                                </div>
                                
                                <div className="flex gap-2">
                                    <Input
                                        value={newMessage}
                                        onChange={(e) => setNewMessage(e.target.value)}
                                        placeholder="Type a message..."
                                        onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                                    />
                                    <Button onClick={sendMessage} size="icon">
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
