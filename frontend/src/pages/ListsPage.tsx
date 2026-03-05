import { useState, useEffect } from 'react';
import { api } from '../api';
import type { UserList } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Textarea } from '../components/ui/textarea';
import { Label } from '../components/ui/label';
import { List, Users, Trash2, Plus } from 'lucide-react';
import { Link } from 'react-router-dom';

export function ListsPage() {
    const [lists, setLists] = useState<UserList[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [showCreateForm, setShowCreateForm] = useState(false);
    const [newListName, setNewListName] = useState('');
    const [newListDescription, setNewListDescription] = useState('');
    const [newListPrivate, setNewListPrivate] = useState(false);

    useEffect(() => {
        loadLists();
    }, []);

    const loadLists = async () => {
        try {
            const data = await api.getLists();
            setLists(data.lists);
        } catch (err) {
            setError('Failed to load lists');
        } finally {
            setLoading(false);
        }
    };

    const createList = async () => {
        if (!newListName.trim()) return;
        
        try {
            await api.createList(newListName, newListDescription, newListPrivate);
            setNewListName('');
            setNewListDescription('');
            setNewListPrivate(false);
            setShowCreateForm(false);
            loadLists();
        } catch (err) {
            setError('Failed to create list');
        }
    };

    const deleteList = async (id: number) => {
        if (!confirm('Are you sure you want to delete this list?')) return;
        
        try {
            await api.deleteList(id);
            loadLists();
        } catch (err) {
            setError('Failed to delete list');
        }
    };

    if (loading) return <div className="text-center py-12">Loading...</div>;

    return (
        <div className="max-w-2xl mx-auto p-4">
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold">Lists</h1>
                <Button onClick={() => setShowCreateForm(!showCreateForm)}>
                    <Plus className="w-4 h-4 mr-2" />
                    Create List
                </Button>
            </div>

            {showCreateForm && (
                <Card className="mb-6">
                    <CardHeader>
                        <CardTitle>Create New List</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div>
                            <Label htmlFor="name">Name</Label>
                            <Input
                                id="name"
                                value={newListName}
                                onChange={(e) => setNewListName(e.target.value)}
                                placeholder="List name"
                            />
                        </div>
                        <div>
                            <Label htmlFor="description">Description</Label>
                            <Textarea
                                id="description"
                                value={newListDescription}
                                onChange={(e) => setNewListDescription(e.target.value)}
                                placeholder="Description (optional)"
                            />
                        </div>
                        <div className="flex items-center gap-2">
                            <input
                                type="checkbox"
                                id="private"
                                checked={newListPrivate}
                                onChange={(e) => setNewListPrivate(e.target.checked)}
                                className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                            />
                            <Label htmlFor="private">Private list</Label>
                        </div>
                        <Button onClick={createList} className="w-full">
                            Create List
                        </Button>
                    </CardContent>
                </Card>
            )}

            {lists.length === 0 ? (
                <Card>
                    <CardContent className="text-center py-12 text-muted-foreground">
                        <List className="w-12 h-12 mx-auto mb-4" />
                        <p>No lists yet</p>
                        <p className="text-sm">Create a list to organize users</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="space-y-4">
                    {lists.map((list) => (
                        <Card key={list.id}>
                            <CardContent className="p-4">
                                <div className="flex items-start justify-between">
                                    <div className="flex-1">
                                        <Link 
                                            to={`/lists/${list.id}`}
                                            className="font-semibold text-lg hover:underline"
                                        >
                                            {list.name}
                                        </Link>
                                        {list.description && (
                                            <p className="text-muted-foreground mt-1">
                                                {list.description}
                                            </p>
                                        )}
                                        <div className="flex items-center gap-4 mt-2 text-sm text-muted-foreground">
                                            <span className="flex items-center gap-1">
                                                <Users className="w-4 h-4" />
                                                {list.member_count} members
                                            </span>
                                            {list.is_private && (
                                                <span className="bg-muted px-2 py-1 rounded">
                                                    Private
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                    <Button
                                        variant="ghost"
                                        size="icon"
                                        onClick={() => deleteList(list.id)}
                                        className="text-red-500"
                                    >
                                        <Trash2 className="w-4 h-4" />
                                    </Button>
                                </div>
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
