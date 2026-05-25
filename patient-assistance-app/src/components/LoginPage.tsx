import React, { useState } from 'react';
import { useHistory } from 'react-router-dom';
import { auth } from '../firebase/firebaseConfig';
import InputField from './common/InputField';
import VerificationToast from './VerificationToast';

const LoginPage: React.FC = () => {
    const [mobileNumber, setMobileNumber] = useState('');
    const [email, setEmail] = useState('');
    const [error, setError] = useState('');
    const history = useHistory();

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!mobileNumber || !email) {
            setError('Mobile number and email are required.');
            return;
        }

        try {
            const userCredential = await auth.signInWithPhoneNumber(mobileNumber);
            const user = userCredential.user;

            if (user && !user.emailVerified) {
                setError('Please complete email verification first.');
                return;
            }

            history.push('/home');
        } catch (error) {
            setError('Login failed. Please check your credentials.');
        }
    };

    return (
        <div className="login-page">
            <h2>Login</h2>
            <form onSubmit={handleLogin}>
                <InputField
                    label="Mobile Number"
                    value={mobileNumber}
                    onChange={(e) => setMobileNumber(e.target.value)}
                    type="tel"
                    required
                />
                <InputField
                    label="Email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    type="email"
                    required
                />
                <button type="submit">Login</button>
            </form>
            {error && <VerificationToast message={error} />}
            <p>
                Don't have an account? <a href="/signup">Sign Up</a>
            </p>
        </div>
    );
};

export default LoginPage;