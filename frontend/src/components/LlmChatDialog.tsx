import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Bot, Loader2, MessageSquarePlus, Send } from 'lucide-react';
import type { ButtonProps } from '@/components/ui/button';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from '@/components/ui/dialog';
import { api } from '@/api';
import type { LlmChatMessage, LlmConfigSummary, LlmProvider, LlmProviderId, Post } from '@/types';

interface LlmChatDialogProps {
    post?: Post;
    triggerLabel?: string;
    triggerIcon?: ReactNode;
    triggerVariant?: ButtonProps['variant'];
    triggerSize?: ButtonProps['size'];
    triggerClassName?: string;
}

export function LlmChatDialog({
    post,
    triggerLabel = 'Ask AI',
    triggerIcon,
    triggerVariant = 'ghost',
    triggerSize = 'sm',
    triggerClassName,
}: LlmChatDialogProps) {
    const [open, setOpen] = useState(false);
    const [providers, setProviders] = useState<LlmProvider[]>([]);
    const [configs, setConfigs] = useState<LlmConfigSummary[]>([]);
    const [selectedProvider, setSelectedProvider] = useState<LlmProviderId | ''>('');
    const [messages, setMessages] = useState<LlmChatMessage[]>([]);
    const [input, setInput] = useState('');
    const [loading, setLoading] = useState(false);
    const [sending, setSending] = useState(false);
    const [error, setError] = useState('');

    useEffect(() => {
        if (!open) return;

        const loadConfig = async () => {
            try {
                setLoading(true);
                const [providerData, configData] = await Promise.all([
                    api.getLlmProviders(),
                    api.getLlmConfigs(),
                ]);
                setProviders(providerData.providers);
                setConfigs(configData.configs);
                setError('');
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to load AI settings');
            } finally {
                setLoading(false);
            }
        };

        loadConfig();
    }, [open]);

    const configuredProviders = useMemo(
        () =>
            providers.filter((provider) =>
                configs.some((config) => config.provider === provider.id)
            ),
        [configs, providers]
    );

    useEffect(() => {
        if (!open || configuredProviders.length === 0) {
            setSelectedProvider('');
            return;
        }

        if (
            selectedProvider &&
            configuredProviders.some((provider) => provider.id === selectedProvider)
        ) {
            return;
        }

        const defaultConfig = configs.find((config) => config.is_default);
        setSelectedProvider(defaultConfig?.provider ?? configuredProviders[0].id);
    }, [configs, configuredProviders, open, selectedProvider]);

    const selectedConfig = configs.find((config) => config.provider === selectedProvider);

    const handleSend = async () => {
        const content = input.trim();
        if (!content || !selectedProvider || sending) return;

        const nextMessages = [...messages, { role: 'user' as const, content }];
        setMessages(nextMessages);
        setInput('');
        setSending(true);
        setError('');

        try {
            const response = await api.chatWithLlm({
                provider: selectedProvider,
                post_id: post?.id,
                messages: nextMessages,
            });
            setMessages([...nextMessages, { role: 'assistant', content: response.reply }]);
        } catch (err) {
            setMessages(nextMessages);
            setError(err instanceof Error ? err.message : 'Failed to send message');
        } finally {
            setSending(false);
        }
    };

    return (
        <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
                <Button
                    variant={triggerVariant}
                    size={triggerSize}
                    className={triggerClassName}
                >
                    {triggerIcon ?? <Bot className="h-4 w-4" />}
                    <span>{triggerLabel}</span>
                </Button>
            </DialogTrigger>
            <DialogContent className="max-w-2xl">
                <DialogHeader>
                    <DialogTitle>AI Chat</DialogTitle>
                    <DialogDescription>
                        {post
                            ? 'Chat about this post or ask a broader question with the post as context.'
                            : 'Ask general questions using one of your configured providers.'}
                    </DialogDescription>
                </DialogHeader>

                {post && (
                    <div className="rounded-lg border bg-muted/40 p-3 text-sm">
                        <div className="mb-1 font-medium">
                            {(post.display_name || post.username)} @{post.username}
                        </div>
                        <p className="whitespace-pre-wrap text-muted-foreground">
                            {post.content}
                        </p>
                    </div>
                )}

                {loading ? (
                    <div className="flex items-center justify-center py-10 text-muted-foreground">
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Loading AI settings...
                    </div>
                ) : configuredProviders.length === 0 ? (
                    <div className="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">
                        Add a provider and API key in Settings before starting an AI chat.
                    </div>
                ) : (
                    <>
                        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                            <label className="text-sm font-medium" htmlFor="llm-provider-select">
                                Provider
                            </label>
                            <select
                                id="llm-provider-select"
                                className="rounded-md border bg-background px-3 py-2 text-sm"
                                value={selectedProvider}
                                onChange={(event) =>
                                    setSelectedProvider(event.target.value as LlmProviderId)
                                }
                            >
                                {configuredProviders.map((provider) => (
                                    <option key={provider.id} value={provider.id}>
                                        {provider.label}
                                    </option>
                                ))}
                            </select>
                        </div>

                        {selectedConfig && (
                            <div className="text-xs text-muted-foreground">
                                Using model <span className="font-medium text-foreground">{selectedConfig.model}</span>
                                {selectedConfig.is_default && ' · default'}
                            </div>
                        )}

                        <div className="max-h-[360px] space-y-3 overflow-y-auto rounded-lg border bg-muted/20 p-3">
                            {messages.length === 0 ? (
                                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                                    <MessageSquarePlus className="h-4 w-4" />
                                    Start the conversation.
                                </div>
                            ) : (
                                messages.map((message, index) => (
                                    <div
                                        key={`${message.role}-${index}`}
                                        className={`rounded-lg px-3 py-2 text-sm ${
                                            message.role === 'user'
                                                ? 'ml-8 bg-primary text-primary-foreground'
                                                : 'mr-8 border bg-background'
                                        }`}
                                    >
                                        <div className="mb-1 text-[11px] uppercase tracking-wide opacity-70">
                                            {message.role}
                                        </div>
                                        <p className="whitespace-pre-wrap">{message.content}</p>
                                    </div>
                                ))
                            )}
                        </div>

                        <div className="space-y-2">
                            <Textarea
                                placeholder={
                                    post
                                        ? 'Ask about this post or anything related...'
                                        : 'Ask anything...'
                                }
                                value={input}
                                onChange={(event) => setInput(event.target.value)}
                                onKeyDown={(event) => {
                                    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
                                        event.preventDefault();
                                        handleSend();
                                    }
                                }}
                                className="min-h-[110px]"
                            />
                            <div className="flex items-center justify-between gap-3">
                                <p className="text-xs text-muted-foreground">
                                    Press Ctrl/Cmd+Enter to send.
                                </p>
                                <Button onClick={handleSend} disabled={!input.trim() || sending || !selectedProvider}>
                                    {sending ? (
                                        <Loader2 className="h-4 w-4 animate-spin" />
                                    ) : (
                                        <Send className="h-4 w-4" />
                                    )}
                                    Send
                                </Button>
                            </div>
                        </div>
                    </>
                )}

                {error && (
                    <div className="rounded-lg bg-red-100 p-3 text-sm text-red-800">
                        {error}
                    </div>
                )}
            </DialogContent>
        </Dialog>
    );
}
