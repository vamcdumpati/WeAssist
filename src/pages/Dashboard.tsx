import React, { useState } from 'react';
import useAuth from '../hooks/useAuth';
import PatientRegistration from '../components/PatientRegistration';
import ExistingPatients from '../components/ExistingPatients';

const Dashboard: React.FC = () => {
    const { user, logout } = useAuth();
    const [view, setView] = useState<'menu' | 'new-patient' | 'existing-patients'>('menu');

    const handleLogout = async () => {
        if (window.confirm("Are you sure you want to sign out?")) {
            await logout();
        }
    };

    return (
        <div className="app-container">
            {/* Top Navigation Header */}
            <header className="app-header">
                <div className="logo-container">
                    <div className="logo-icon">WA</div>
                    <div className="logo-text">WeAssist App</div>
                </div>
                
                {user && (
                    <div className="user-badge">
                        <span>👋 Welcome, <strong>{user.firstName} {user.lastName}</strong></span>
                        <span style={{ color: 'var(--text-muted)' }}>|</span>
                        <span className="logout-link" onClick={handleLogout}>Sign Out</span>
                    </div>
                )}
            </header>

            {/* Main Page Area */}
            <main style={{ flex: 1, padding: '2.5rem 1.5rem', display: 'block' }}>
                <div className="dashboard-layout">
                    {view === 'menu' && (
                        <div>
                            <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
                                <h1>Admin Dashboard</h1>
                                <p className="subtitle" style={{ maxWidth: '600px', margin: '0 auto' }}>
                                    Manage patient intakes, record physical measurements, capture safety identity proofs, and orchestrate hospital transit trips.
                                </p>
                            </div>

                            {/* Options cards */}
                            <div className="dashboard-grid">
                                <div className="option-card existing" onClick={() => setView('existing-patients')}>
                                    <div className="option-icon">👥</div>
                                    <h3>Existing Patients Directory</h3>
                                    <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', lineHeight: '1.5' }}>
                                        Search and filter previously registered patients, review history, and schedule new transit visits.
                                    </p>
                                </div>

                                <div className="option-card new" onClick={() => setView('new-patient')}>
                                    <div className="option-icon">➕</div>
                                    <h3>New Patient Registration</h3>
                                    <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', lineHeight: '1.5' }}>
                                        Onboard a new patient with measurements, upload and capture ID documents, take a live photo, and schedule transit.
                                    </p>
                                </div>
                            </div>


                        </div>
                    )}

                    {view === 'new-patient' && (
                        <div>
                            <div className="back-link" onClick={() => setView('menu')}>
                                <span>←</span> Back to Dashboard
                            </div>
                            <PatientRegistration onComplete={() => setView('existing-patients')} />
                        </div>
                    )}

                    {view === 'existing-patients' && (
                        <div>
                            <div className="back-link" onClick={() => setView('menu')}>
                                <span>←</span> Back to Dashboard
                            </div>
                            <ExistingPatients />
                        </div>
                    )}
                </div>
            </main>
        </div>
    );
};

export default Dashboard;
