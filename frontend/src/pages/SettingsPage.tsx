import { useState, useEffect } from 'react';
import { api } from '../api';
import type { BlockedUser, LlmConfigSummary, LlmProvider, LlmProviderId, MutedUser } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Ban, Bot, Eye, EyeOff, KeyRound, Loader2, Plus, Trash2, UserX, VolumeX } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { LlmChatDialog } from '../components/LlmChatDialog';

export function SettingsPage() {
    const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
    const [mutedUsers, setMutedUsers] = useState<MutedUser[]>([]);
    const [providers, setProviders] = useState<LlmProvider[]>([]);
    const [configs, setConfigs] = useState<LlmConfigSummary[]>([]);
    const [selectedProvider, setSelectedProvider] = useState<LlmProviderId | ''>('');
    const [apiKeyInput, setApiKeyInput] = useState('');
    const [revealedApiKey, setRevealedApiKey] = useState('');
    const [showRevealedKey, setShowRevealedKey] = useState(false);
    const [modelInput, setModelInput] = useState('');
    const [baseUrlInput, setBaseUrlInput] = useState('');
    const [saveAsDefault, setSaveAsDefault] = useState(false);
    const [isSavingConfig, setIsSavingConfig] = useState(false);
    const [isRevealingKey, setIsRevealingKey] = useState(false);
    const [isDeletingConfig, setIsDeletingConfig] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [blockUsername, setBlockUsername] = useState('');
    const [muteUsername, setMuteUsername] = useState('');
    const navigate = useNavigate();

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            const [blocked, muted, providerData, configData] = await Promise.all([
                api.getBlockedUsers(),
                api.getMutedUsers(),
                api.getLlmProviders(),
                api.getLlmConfigs(),
            ]);
            setBlockedUsers(blocked.blocked_users);
            setMutedUsers(muted.muted_users);
            setProviders(providerData.providers);
            setConfigs(configData.configs);
            setSelectedProvider((current) => {
                if (current && providerData.providers.some((provider) => provider.id === current)) {
                    return current;
                }
                return configData.configs.find((config) => config.is_default)?.provider
                    ?? providerData.providers[0]?.id
                    ?? '';
            });
        } catch (err) {
            setError('Failed to load settings');
        } finally {
            setLoading(false);
        }
    };

    const blockUser = async () => {
        if (!blockUsername.trim()) return;
        
        try {
            await api.blockUser(blockUsername);
            setBlockUsername('');
            loadData();
        } catch (err) {
            setError('Failed to block user');
        }
    };

    const unblockUser = async (username: string) => {
        try {
            await api.unblockUser(username);
            loadData();
        } catch (err) {
            setError('Failed to unblock user');
        }
    };

    const muteUser = async () => {
        if (!muteUsername.trim()) return;
        
        try {
            await api.muteUser(muteUsername);
            setMuteUsername('');
            loadData();
        } catch (err) {
            setError('Failed to mute user');
        }
    };

    const unmuteUser = async (username: string) => {
        try {
            await api.unmuteUser(username);
            loadData();
        } catch (err) {
            setError('Failed to unmute user');
        }
    };

    const selectedProviderMeta = providers.find((provider) => provider.id === selectedProvider);
    const selectedConfig = configs.find((config) => config.provider === selectedProvider);

    useEffect(() => {
        if (!selectedProviderMeta) return;
        setModelInput(selectedConfig?.model ?? selectedProviderMeta.default_model);
        setBaseUrlInput(selectedConfig?.base_url ?? '');
        setSaveAsDefault(Boolean(selectedConfig?.is_default));
        setApiKeyInput('');
        setRevealedApiKey('');
        setShowRevealedKey(false);
    }, [selectedConfig, selectedProviderMeta]);

    const handleSaveProviderConfig = async () => {
        if (!selectedProvider) return;

        try {
            setIsSavingConfig(true);
            await api.updateLlmConfig(selectedProvider, {
                api_key: apiKeyInput.trim() || undefined,
                model: modelInput.trim() || selectedProviderMeta?.default_model,
                base_url: selectedProviderMeta?.supports_custom_base_url
                    ? baseUrlInput.trim() || undefined
                    : undefined,
                is_default: saveAsDefault,
            });
            await loadData();
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to save AI settings');
        } finally {
            setIsSavingConfig(false);
        }
    };

    const handleRevealKey = async () => {
        if (!selectedProvider) return;

        if (showRevealedKey) {
            setShowRevealedKey(false);
            setRevealedApiKey('');
            return;
        }

        try {
            setIsRevealingKey(true);
            const response = await api.revealLlmConfig(selectedProvider);
            setRevealedApiKey(response.api_key);
            setShowRevealedKey(true);
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to reveal API key');
        } finally {
            setIsRevealingKey(false);
        }
    };

    const handleDeleteConfig = async () => {
        if (!selectedProvider || !selectedConfig) return;
        if (!confirm(`Remove the saved ${selectedProviderMeta?.label ?? selectedProvider} configuration?`)) {
            return;
        }

        try {
            setIsDeletingConfig(true);
            await api.deleteLlmConfig(selectedProvider);
            await loadData();
            setError('');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to delete AI settings');
        } finally {
            setIsDeletingConfig(false);
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Settings</h1>

            <Card className="mb-6">
                <CardHeader>
                    <CardTitle className="flex items-center justify-between gap-3">
                        <span className="flex items-center gap-2">
                            <Bot className="w-5 h-5" />
                            AI Providers
                        </span>
                        <LlmChatDialog
                            triggerLabel="Open AI chat"
                            triggerVariant="outline"
                            triggerSize="sm"
                        />
                    </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                    <p className="text-sm text-muted-foreground">
                        Bring your own key. Saved keys stay masked unless you explicitly reveal them.
                    </p>

                    <div className="grid gap-2 sm:grid-cols-2">
                        {providers.map((provider) => {
                            const config = configs.find((item) => item.provider === provider.id);
                            const isSelected = provider.id === selectedProvider;

                            return (
                                <button
                                    key={provider.id}
                                    type="button"
                                    onClick={() => setSelectedProvider(provider.id)}
                                    className={`rounded-lg border p-3 text-left transition-colors ${
                                        isSelected
                                            ? 'border-primary bg-primary/10'
                                            : 'hover:bg-muted/60'
                                    }`}
                                >
                                    <div className="flex items-center justify-between gap-2">
                                        <span className="font-medium">{provider.label}</span>
                                        {config?.is_default && (
                                            <span className="rounded-full bg-primary/15 px-2 py-0.5 text-xs text-primary">
                                                Default
                                            </span>
                                        )}
                                    </div>
                                    <p className="mt-1 text-xs text-muted-foreground">
                                        {provider.description}
                                    </p>
                                    <p className="mt-2 text-xs">
                                        {config ? (
                                            <span className="text-foreground">Configured</span>
                                        ) : (
                                            <span className="text-muted-foreground">Not configured</span>
                                        )}
                                    </p>
                                </button>
                            );
                        })}
                    </div>

                    {selectedProviderMeta && (
                        <div className="space-y-4 rounded-lg border p-4">
                            <div>
                                <h2 className="font-semibold">{selectedProviderMeta.label}</h2>
                                <p className="text-sm text-muted-foreground">
                                    Default model: {selectedProviderMeta.default_model}
                                </p>
                            </div>

                            {selectedConfig && (
                                <div className="space-y-2 rounded-lg bg-muted/40 p-3">
                                    <div className="flex items-center gap-2 text-sm font-medium">
                                        <KeyRound className="h-4 w-4" />
                                        Saved key
                                    </div>
                                    <div className="flex gap-2">
                                        <Input
                                            type={showRevealedKey ? 'text' : 'password'}
                                            value={showRevealedKey ? revealedApiKey : selectedConfig.masked_api_key}
                                            readOnly
                                        />
                                        <Button
                                            variant="outline"
                                            onClick={handleRevealKey}
                                            disabled={isRevealingKey}
                                        >
                                            {isRevealingKey ? (
                                                <Loader2 className="h-4 w-4 animate-spin" />
                                            ) : showRevealedKey ? (
                                                <EyeOff className="h-4 w-4" />
                                            ) : (
                                                <Eye className="h-4 w-4" />
                                            )}
                                            {showRevealedKey ? 'Hide' : 'Reveal'}
                                        </Button>
                                    </div>
                                </div>
                            )}

                            <div className="space-y-2">
                                <label className="text-sm font-medium" htmlFor="llm-model">
                                    Model
                                </label>
                                <Input
                                    id="llm-model"
                                    value={modelInput}
                                    onChange={(event) => setModelInput(event.target.value)}
                                    placeholder={selectedProviderMeta.default_model}
                                />
                            </div>

                            {selectedProviderMeta.supports_custom_base_url && (
                                <div className="space-y-2">
                                    <label className="text-sm font-medium" htmlFor="llm-base-url">
                                        Custom base URL
                                    </label>
                                    <Input
                                        id="llm-base-url"
                                        value={baseUrlInput}
                                        onChange={(event) => setBaseUrlInput(event.target.value)}
                                        placeholder="Optional custom endpoint"
                                    />
                                </div>
                            )}

                            <div className="space-y-2">
                                <label className="text-sm font-medium" htmlFor="llm-api-key">
                                    {selectedConfig ? 'Replace API key' : 'API key'}
                                </label>
                                <Input
                                    id="llm-api-key"
                                    type="password"
                                    value={apiKeyInput}
                                    onChange={(event) => setApiKeyInput(event.target.value)}
                                    placeholder={selectedConfig ? 'Leave blank to keep current key' : 'Paste API key'}
                                />
                            </div>

                            <label className="flex items-center gap-2 text-sm">
                                <input
                                    type="checkbox"
                                    checked={saveAsDefault}
                                    onChange={(event) => setSaveAsDefault(event.target.checked)}
                                />
                                Use this provider by default for AI chat
                            </label>

                            <div className="flex flex-wrap gap-2">
                                <Button onClick={handleSaveProviderConfig} disabled={isSavingConfig}>
                                    {isSavingConfig && <Loader2 className="h-4 w-4 animate-spin" />}
                                    Save provider
                                </Button>
                                {selectedConfig && (
                                    <Button
                                        variant="outline"
                                        onClick={handleDeleteConfig}
                                        disabled={isDeletingConfig}
                                    >
                                        {isDeletingConfig ? (
                                            <Loader2 className="h-4 w-4 animate-spin" />
                                        ) : (
                                            <Trash2 className="h-4 w-4" />
                                        )}
                                        Remove saved config
                                    </Button>
                                )}
                            </div>
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Blocked Users */}
            <Card className="mb-6">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Ban className="w-5 h-5" />
                        Blocked Users
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex gap-2 mb-4">
                        <Input
                            value={blockUsername}
                            onChange={(e) => setBlockUsername(e.target.value)}
                            placeholder="Username to block"
                        />
                        <Button onClick={blockUser}>
                            <Plus className="w-4 h-4" />
                        </Button>
                    </div>

                    {blockedUsers.length === 0 ? (
                        <p className="text-muted-foreground text-sm">
                            No blocked users
                        </p>
                    ) : (
                        <div className="space-y-2">
                            {blockedUsers.map((user) => (
                                <div 
                                    key={user.id}
                                    className="flex items-center justify-between p-2 bg-muted rounded"
                                >
                                    <div 
                                        className="cursor-pointer hover:underline"
                                        onClick={() => navigate(`/profile/${user.username}`)}
                                    >
                                        <span className="font-medium">@{user.username}</span>
                                        {user.display_name && (
                                            <span className="text-muted-foreground ml-2">
                                                {user.display_name}
                                            </span>
                                        )}
                                    </div>
                                    <Button 
                                        variant="ghost" 
                                        size="sm"
                                        onClick={() => unblockUser(user.username)}
                                    >
                                        <UserX className="w-4 h-4 mr-2" />
                                        Unblock
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Muted Users */}
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <VolumeX className="w-5 h-5" />
                        Muted Users
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="flex gap-2 mb-4">
                        <Input
                            value={muteUsername}
                            onChange={(e) => setMuteUsername(e.target.value)}
                            placeholder="Username to mute"
                        />
                        <Button onClick={muteUser}>
                            <Plus className="w-4 h-4" />
                        </Button>
                    </div>

                    {mutedUsers.length === 0 ? (
                        <p className="text-muted-foreground text-sm">
                            No muted users
                        </p>
                    ) : (
                        <div className="space-y-2">
                            {mutedUsers.map((user) => (
                                <div 
                                    key={user.id}
                                    className="flex items-center justify-between p-2 bg-muted rounded"
                                >
                                    <div 
                                        className="cursor-pointer hover:underline"
                                        onClick={() => navigate(`/profile/${user.username}`)}
                                    >
                                        <span className="font-medium">@{user.username}</span>
                                        {user.display_name && (
                                            <span className="text-muted-foreground ml-2">
                                                {user.display_name}
                                            </span>
                                        )}
                                    </div>
                                    <Button 
                                        variant="ghost" 
                                        size="sm"
                                        onClick={() => unmuteUser(user.username)}
                                    >
                                        Unmute
                                    </Button>
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
