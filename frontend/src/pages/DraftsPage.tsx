import { useState, useEffect } from 'react';
import { api } from '../api';
import type { Draft } from '../types';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Textarea } from '../components/ui/textarea';
import { FileText, Trash2, Edit2, Save } from 'lucide-react';

export function DraftsPage() {
    const [drafts, setDrafts] = useState<Draft[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [editingId, setEditingId] = useState<number | null>(null);
    const [editContent, setEditContent] = useState('');

    useEffect(() => {
        loadDrafts();
    }, []);

    const loadDrafts = async () => {
        try {
            const data = await api.getDrafts();
            setDrafts(data.drafts);
        } catch (err) {
            setError('Failed to load drafts');
        } finally {
            setLoading(false);
        }
    };

    const deleteDraft = async (id: number) => {
        if (!confirm('Delete this draft?')) return;
        
        try {
            await api.deleteDraft(id);
            loadDrafts();
        } catch (err) {
            setError('Failed to delete draft');
        }
    };

    const startEditing = (draft: Draft) => {
        setEditingId(draft.id);
        setEditContent(draft.content);
    };

    const saveEdit = async () => {
        if (!editingId || !editContent.trim()) return;
        
        try {
            await api.updateDraft(editingId, editContent);
            setEditingId(null);
            setEditContent('');
            loadDrafts();
        } catch (err) {
            setError('Failed to update draft');
        }
    };

    const postDraft = async (draft: Draft) => {
        try {
            await api.createPost({ content: draft.content, media_urls: draft.media_urls || undefined });
            await api.deleteDraft(draft.id);
            loadDrafts();
        } catch (err) {
            setError('Failed to post draft');
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <FileText className="w-6 h-6" />
                Drafts
            </h1>

            {drafts.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <FileText className="w-12 h-12 mx-auto mb-4" />
                        <p>No drafts yet</p>
                        <p className="text-sm">Save a draft while composing a post</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="space-y-4">
                    {drafts.map((draft) => (
                        <Card key={draft.id}>
                            <CardContent className="p-4">
                                {editingId === draft.id ? (
                                    <div className="space-y-3">
                                        <Textarea
                                            value={editContent}
                                            onChange={(e) => setEditContent(e.target.value)}
                                            rows={4}
                                        />
                                        <div className="flex gap-2">
                                            <Button onClick={saveEdit} size="sm">
                                                <Save className="w-4 h-4 mr-2" />
                                                Save
                                            </Button>
                                            <Button 
                                                variant="outline" 
                                                size="sm"
                                                onClick={() => setEditingId(null)}
                                            >
                                                Cancel
                                            </Button>
                                        </div>
                                    </div>
                                ) : (
                                    <>
                                        <p className="whitespace-pre-wrap mb-3">{draft.content}</p>
                                        <div className="flex items-center justify-between text-sm text-muted-foreground">
                                            <span>
                                                Updated {new Date(draft.updated_at).toLocaleDateString()}
                                            </span>
                                            <div className="flex gap-2">
                                                <Button 
                                                    variant="outline" 
                                                    size="sm"
                                                    onClick={() => postDraft(draft)}
                                                >
                                                    Post
                                                </Button>
                                                <Button 
                                                    variant="ghost" 
                                                    size="icon"
                                                    onClick={() => startEditing(draft)}
                                                >
                                                    <Edit2 className="w-4 h-4" />
                                                </Button>
                                                <Button 
                                                    variant="ghost" 
                                                    size="icon"
                                                    onClick={() => deleteDraft(draft.id)}
                                                    className="text-red-500"
                                                >
                                                    <Trash2 className="w-4 h-4" />
                                                </Button>
                                            </div>
                                        </div>
                                    </>
                                )}
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}

            {error && (
                <div className="mt-4 p-4 bg-red-100 text-red-800 rounded-lg">
                    {error}
                </div>
            )}
        </div>
    );
}
