import React from 'react';
import { useAuth } from '../hooks/useAuth';
import { useHistory } from 'react-router-dom';

const Profile: React.FC = () => {
    const { user, loading, error } = useAuth();
    const history = useHistory();

    if (loading) {
        return (
            <div className="main-content">
                <div className="glass-card" style={{ textAlign: 'center' }}>
                    <div className="pulse-location-icon" style={{ width: '40px', height: '40px', fontSize: '1.2rem' }}>⏳</div>
                    <p>Loading profile details...</p>
                </div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="main-content">
                <div className="glass-card" style={{ textAlign: 'center' }}>
                    <h3 style={{ color: 'var(--error)' }}>Error Loading Profile</h3>
                    <p style={{ color: 'var(--text-secondary)', margin: '1rem 0' }}>{error}</p>
                    <button type="button" className="btn-primary" onClick={() => history.push('/home')}>
                        Back to Dashboard
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="app-container">
            <header className="app-header">
                <div className="logo-container">
                    <div className="logo-icon" onClick={() => history.push('/home')} style={{ cursor: 'pointer' }}>WA</div>
                    <div className="logo-text" onClick={() => history.push('/home')} style={{ cursor: 'pointer' }}>WeAssist App</div>
                </div>
                <div className="user-badge">
                    <span className="logout-link" onClick={() => history.push('/home')}>Dashboard</span>
                </div>
            </header>

            <main className="main-content">
                <div className="glass-card">
                    <h2>Admin Profile</h2>
                    <p className="subtitle">Your registered WeAssist credentials</p>

                    {user ? (
                        <div className="details-info-box" style={{ background: 'rgba(255,255,255,0.02)', textAlign: 'left' }}>
                            <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                                <label>First Name</label>
                                <div style={{ fontSize: '1.1rem', color: '#ffffff', fontWeight: '500' }}>
                                    {user.firstName}
                                </div>
                            </div>
                            <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                                <label>Last Name</label>
                                <div style={{ fontSize: '1.1rem', color: '#ffffff', fontWeight: '500' }}>
                                    {user.lastName}
                                </div>
                            </div>
                            <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                                <label>Email Address</label>
                                <div style={{ fontSize: '1.1rem', color: '#ffffff', fontWeight: '500' }}>
                                    {user.email}
                                </div>
                            </div>
                            <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                                <label>Registered Mobile</label>
                                <div style={{ fontSize: '1.1rem', color: '#ffffff', fontWeight: '500' }}>
                                    {user.mobileNumber}
                                </div>
                            </div>
                            <div className="badgeverified" style={{ 
                                display: 'inline-flex', 
                                alignItems: 'center', 
                                gap: '0.5rem', 
                                background: 'rgba(16, 185, 129, 0.1)', 
                                color: 'var(--success)', 
                                padding: '0.4rem 1rem', 
                                borderRadius: 'var(--radius-full)', 
                                border: '1px solid rgba(16, 185, 129, 0.2)',
                                fontSize: '0.85rem',
                                fontWeight: '600'
                            }}>
                                🛡️ Verified Administrator
                            </div>
                        </div>
                    ) : (
                        <div style={{ textAlign: 'center' }}>
                            <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
                                No user profile active. Please sign in.
                            </p>
                            <button type="button" className="btn-primary" onClick={() => history.push('/')}>
                                Go to Login
                            </button>
                        </div>
                    )}

                    <button 
                        type="button" 
                        className="btn-secondary" 
                        style={{ marginTop: '2rem' }}
                        onClick={() => history.push('/home')}
                    >
                        Back to Dashboard
                    </button>
                </div>
            </main>
        </div>
    );
};

export default Profile;