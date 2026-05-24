import React, { useState } from 'react';
import { firebase } from '../firebase/firebaseConfig';
import InputField from './common/InputField';
import { toast } from 'react-toastify';

const SignUpPage = () => {
    const [mobile, setMobile] = useState('');
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSignUp = async (e) => {
        e.preventDefault();
        if (!mobile || !name || !email) {
            toast.error('All fields are mandatory.');
            return;
        }

        setLoading(true);
        try {
            const userCredential = await firebase.auth().createUserWithEmailAndPassword(email, mobile);
            // Store additional user info in Firestore or Realtime Database
            await firebase.firestore().collection('users').doc(userCredential.user.uid).set({
                mobile,
                name,
                email,
                emailVerified: false,
            });
            toast.success('Sign up successful! Please verify your email.');
        } catch (error) {
            toast.error(error.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="signup-container">
            <h2>Sign Up</h2>
            <form onSubmit={handleSignUp}>
                <InputField
                    label="Mobile Number"
                    type="text"
                    value={mobile}
                    onChange={(e) => setMobile(e.target.value)}
                    required
                />
                <InputField
                    label="Name"
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                />
                <InputField
                    label="Email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                />
                <button type="submit" disabled={loading}>
                    {loading ? 'Signing Up...' : 'Sign Up'}
                </button>
            </form>
        </div>
    );
};

export default SignUpPage;