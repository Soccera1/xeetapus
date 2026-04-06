import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { api } from '../api';
import type { User } from '../types';

interface AuthContextType {
    user: User | null;
    isAuthenticated: boolean;
    login: (username: string, password: string) => Promise<{ migrated?: boolean; message?: string }>;
    register: (username: string, email: string, password: string) => Promise<void>;
    logout: () => void;
    isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        if (api.isAuthenticated()) {
            api.me()
                .then(setUser)
                .catch(() => {
                    api.logout();
                })
                .finally(() => setIsLoading(false));
        } else {
            setIsLoading(false);
        }
    }, []);

    const login = async (username: string, password: string): Promise<{ migrated?: boolean; message?: string }> => {
        const userData = await api.login({ username, password });
        setUser(userData);
        if (userData.password_migrated && userData.migration_message) {
            return { migrated: true, message: userData.migration_message };
        }
        return {};
    };

    const register = async (username: string, email: string, password: string) => {
        const userData = await api.register({ username, email, password });
        setUser(userData);
    };

    const logout = () => {
        api.logout();
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{
            user,
            isAuthenticated: !!user,
            login,
            register,
            logout,
            isLoading
        }}>
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
}