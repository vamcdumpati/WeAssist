import React from 'react';
import { useAuth } from '../hooks/useAuth';

const Profile: React.FC = () => {
    const { user, loading, error } = useAuth();

    if (loading) {
        return <div>Loading...</div>;
    }

    if (error) {
        return <div>Error loading profile: {error.message}</div>;
    }

    return (
        <div className="profile-container">
            <h1>User Profile</h1>
            {user ? (
                <div>
                    <p>Name: {user.name}</p>
                    <p>Email: {user.email}</p>
                    <p>Mobile Number: {user.mobileNumber}</p>
                    {/* Additional user information can be displayed here */}
                </div>
            ) : (
                <p>No user information available. Please log in.</p>
            )}
        </div>
    );
};

export default Profile;