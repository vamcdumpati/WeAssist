import { useState, useEffect } from 'react';
import { auth } from '../firebase/firebaseConfig';
import firebase from 'firebase/app';

const useAuth = () => {
    const [user, setUser] = useState<firebase.User | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const unsubscribe = auth.onAuthStateChanged((user) => {
            setUser(user);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    const signup = async (mobile: string, name: string, email: string) => {
        try {
            const userCredential = await auth.createUserWithEmailAndPassword(email, mobile);
            // Additional logic to save user details in Firestore can be added here
            await userCredential.user?.sendEmailVerification();
        } catch (err) {
            setError(err.message);
        }
    };

    const login = async (mobile: string) => {
        try {
            const userCredential = await auth.signInWithEmailAndPassword(mobile, mobile);
            if (userCredential.user && !userCredential.user.emailVerified) {
                throw new Error('Please complete email verification first.');
            }
        } catch (err) {
            setError(err.message);
        }
    };

    const logout = async () => {
        try {
            await auth.signOut();
        } catch (err) {
            setError(err.message);
        }
    };

    return {
        user,
        loading,
        error,
        signup,
        login,
        logout,
    };
};

export default useAuth;