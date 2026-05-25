import { useState, useEffect } from 'react';
import { AdminUser } from '../types';
import { getSession, clearSession } from '../components/LoginPage';
import { apiService } from '../services/apiService';

/**
 * useAuth – thin session wrapper that reads from localStorage.
 *
 * Login / register are now handled directly inside LoginPage and SignUpPage
 * using apiService, so this hook mainly provides:
 *  - current user object (or null)
 *  - loading flag (resolves immediately on mount)
 *  - logout helper
 */
export const useAuth = () => {
    const [user, setUser] = useState<AdminUser | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        // Restore session from localStorage on mount
        const session = getSession();
        if (session) {
            const nameParts = (session.name || '').split(' ');
            setUser({
                uid: session.id || '',
                firstName: nameParts[0] || '',
                lastName: nameParts.slice(1).join(' ') || '',
                email: session.email || '',
                mobileNumber: session.phone || '',
                emailVerified: true,
                role: session.role || '',
            });

            // Fetch fresh user details from API
            apiService.getUser(session.id)
                .then((freshUser) => {
                    const freshNameParts = (freshUser.name || '').split(' ');
                    setUser({
                        uid: freshUser.id || session.id,
                        firstName: freshNameParts[0] || '',
                        lastName: freshNameParts.slice(1).join(' ') || '',
                        email: freshUser.email || '',
                        mobileNumber: freshUser.phone || '',
                        emailVerified: true,
                        role: freshUser.role || '',
                    });
                })
                .catch(err => {
                    console.error("Failed to fetch fresh user details", err);
                });
        }
        setLoading(false);
    }, []);

    const logout = async () => {
        clearSession();
        setUser(null);
    };

    return {
        user,
        loading,
        error,
        logout,
        setError,
    };
};

export default useAuth;