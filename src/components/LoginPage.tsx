import React, { useState } from 'react';
import { useHistory, Link } from 'react-router-dom';
import { apiService } from '../services/apiService';
import InputField from './common/InputField';

/* ------------------------------------------------------------------
   LOCAL STORAGE HELPERS
   We store a minimal user session so the app survives page refresh.
------------------------------------------------------------------ */
const SESSION_KEY = 'weassist_session';

export const saveSession = (userData: {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: string;
}) => {
  localStorage.setItem(SESSION_KEY, JSON.stringify(userData));
};

export const getSession = () => {
  const raw = localStorage.getItem(SESSION_KEY);
  return raw ? JSON.parse(raw) : null;
};

export const clearSession = () => {
  localStorage.removeItem(SESSION_KEY);
};

/* ------------------------------------------------------------------ */

const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const history = useHistory();

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!email.trim()) {
      setError('Email is required.');
      return;
    }
    if (!password) {
      setError('Password is required.');
      return;
    }

    setLoading(true);
    apiService
      .login({ email: email.trim(), password })
      .then((response) => {
        const userId: string =
          (response.data && (response.data.user_id || response.data.id)) || '';

        let sessionData = {
          id: userId,
          name: (response.data && response.data.name) || '',
          email: (response.data && response.data.email) || email,
          phone: (response.data && response.data.phone) || '',
          role: (response.data && response.data.role) || '',
        };

        if (userId) {
          return apiService
            .getUser(userId)
            .then((profile) => {
              sessionData = {
                id: profile.id,
                name: profile.name,
                email: profile.email,
                phone: profile.phone,
                role: profile.role,
              };
              return sessionData;
            })
            .catch(() => sessionData);
        }

        return Promise.resolve(sessionData);
      })
      .then((sessionData) => {
        saveSession(sessionData);
        history.push('/home');
      })
      .catch((err) => {
        setError((err && err.message) || 'Login failed. Please check your credentials.');
      })
      .finally(() => {
        setLoading(false);
      });
  };

  return (
    <div className="main-content">
      <div className="glass-card" style={{ maxWidth: '460px' }}>
        {/* Logo */}
        <div className="logo-container" style={{ justifyContent: 'center', marginBottom: '2rem' }}>
          <div className="logo-icon">WA</div>
          <div className="logo-text">WeAssist Admin</div>
        </div>

        <h2 style={{ textAlign: 'center', marginBottom: '0.5rem' }}>Welcome back</h2>
        <p className="subtitle" style={{ textAlign: 'center', marginBottom: '2rem' }}>
          Sign in to your WeAssist Admin account
        </p>

        <form onSubmit={handleLogin} noValidate>
          <InputField
            label="Email Address"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            required
          />

          {/* Password field with show/hide toggle */}
          <div className="form-group" style={{ marginBottom: '1.25rem' }}>
            <label>Password</label>
            <div className="input-wrapper">
              <input
                id="login-password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="Enter your password"
                style={{ paddingRight: '3rem' }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{
                  position: 'absolute',
                  right: '1rem',
                  width: 'auto',
                  background: 'none',
                  border: 'none',
                  color: 'var(--text-secondary)',
                  cursor: 'pointer',
                  padding: '0',
                  fontSize: '1.1rem',
                }}
                tabIndex={-1}
              >
                {showPassword ? '🙈' : '👁️'}
              </button>
            </div>
          </div>

          {/* Error message */}
          {error && (
            <div
              className="message-bubble"
              style={{
                borderLeftColor: 'var(--error)',
                color: 'var(--error)',
                marginBottom: '1rem',
                background: 'rgba(239, 68, 68, 0.05)',
              }}
            >
              ⚠️ {error}
            </div>
          )}

          <button
            id="login-submit-btn"
            type="submit"
            className="btn-primary"
            style={{ marginTop: '0.5rem' }}
            disabled={loading}
          >
            {loading ? (
              <>
                <span style={{ display: 'inline-block', animation: 'spin 1s linear infinite' }}>⟳</span>
                &nbsp;Signing in…
              </>
            ) : (
              '→  Sign In'
            )}
          </button>
        </form>

        {/* Divider */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
            margin: '1.75rem 0',
            color: 'var(--text-muted)',
            fontSize: '0.85rem',
          }}
        >
          <div style={{ flex: 1, height: '1px', background: 'var(--glass-border)' }} />
          OR
          <div style={{ flex: 1, height: '1px', background: 'var(--glass-border)' }} />
        </div>

        {/* Register CTA */}
        <Link to="/signup" style={{ textDecoration: 'none' }}>
          <button
            id="go-to-register-btn"
            type="button"
            className="btn-secondary"
            style={{ marginBottom: '1rem' }}
          >
            📝 &nbsp;Create a new account
          </button>
        </Link>

        <p style={{ textAlign: 'center', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
          Don't have an account?&nbsp;
          <Link to="/signup" style={{ color: 'var(--primary)', fontWeight: 600 }}>
            Register here
          </Link>
        </p>
      </div>
    </div>
  );
};

export default LoginPage;