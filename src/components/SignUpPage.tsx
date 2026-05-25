import React, { useState } from 'react';
import { useHistory, Link } from 'react-router-dom';
import { apiService, RegisterPayload } from '../services/apiService';
import InputField from './common/InputField';

const SignUpPage: React.FC = () => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [role, setRole] = useState('admin');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [error, setError] = useState<string | null>(null);

  const history = useHistory();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // Client-side validation
    if (!name.trim()) {
      setError('Full name is required.');
      return;
    }
    if (!email.trim()) {
      setError('Email address is required.');
      return;
    }
    if (!phone.trim()) {
      setError('Phone number is required.');
      return;
    }
    if (phone.trim().length < 10) {
      setError('Please enter a valid phone number (at least 10 digits).');
      return;
    }
    if (!password) {
      setError('Password is required.');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    const payload: RegisterPayload = {
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      password,
      role,
    };

    setLoading(true);
    apiService
      .register(payload)
      .then((response) => {
        setSuccessMsg(response.message || 'Registration successful! You can now log in.');
        setSuccess(true);
      })
      .catch((err) => {
        setError((err && err.message) || 'Registration failed. Please try again.');
      })
      .finally(() => {
        setLoading(false);
      });
  };

  /* ---- Success state ---- */
  if (success) {
    return (
      <div className="main-content">
        <div className="glass-card" style={{ maxWidth: '480px', textAlign: 'center' }}>
          <div
            style={{
              width: '72px',
              height: '72px',
              borderRadius: '50%',
              background: 'rgba(16, 185, 129, 0.12)',
              border: '2px solid var(--success)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '2rem',
              margin: '0 auto 1.5rem',
            }}
          >
            ✓
          </div>
          <h2 style={{ color: 'var(--success)', marginBottom: '0.75rem' }}>
            Account Created!
          </h2>
          <p style={{ color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: '2rem' }}>
            {successMsg}
          </p>
          <button
            id="go-to-login-btn"
            type="button"
            className="btn-primary"
            onClick={() => history.push('/')}
          >
            → Go to Login
          </button>
        </div>
      </div>
    );
  }

  /* ---- Registration form ---- */
  return (
    <div className="main-content" style={{ padding: '2rem 1.5rem' }}>
      <div className="glass-card" style={{ maxWidth: '560px' }}>
        {/* Logo */}
        <div className="logo-container" style={{ justifyContent: 'center', marginBottom: '1.5rem' }}>
          <div className="logo-icon">WA</div>
          <div className="logo-text">WeAssist Admin</div>
        </div>

        <h2 style={{ textAlign: 'center', marginBottom: '0.4rem' }}>Create an Account</h2>
        <p className="subtitle" style={{ textAlign: 'center', marginBottom: '2rem' }}>
          Register as a WeAssist admin user
        </p>

        <form onSubmit={handleSubmit} noValidate>
          {/* Full Name */}
          <InputField
            label="Full Name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Rahul Sharma"
            required
          />

          {/* Email */}
          <InputField
            label="Email Address"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            required
          />

          {/* Phone */}
          <InputField
            label="Phone Number"
            type="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="e.g. 9876543210"
            required
          />

          {/* Role */}
          <div className="form-group">
            <label>Role</label>
            <select
              id="register-role-select"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              required
            >
              <option value="admin">Admin</option>
              <option value="super admin">Super Admin</option>
              <option value="care taker">Care Taker</option>
            </select>
          </div>

          {/* Password */}
          <div className="form-group">
            <label>Password</label>
            <div className="input-wrapper">
              <input
                id="register-password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="Minimum 6 characters"
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

          {/* Confirm Password */}
          <div className="form-group">
            <label>Confirm Password</label>
            <div className="input-wrapper">
              <input
                id="register-confirm-password"
                type={showPassword ? 'text' : 'password'}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                placeholder="Re-enter password"
              />
            </div>
          </div>

          {/* Password strength indicator */}
          {password.length > 0 && (
            <div style={{ marginBottom: '1.25rem' }}>
              <div style={{ display: 'flex', gap: '4px', marginBottom: '4px' }}>
                {[1, 2, 3, 4].map((i) => (
                  <div
                    key={i}
                    style={{
                      flex: 1,
                      height: '4px',
                      borderRadius: '2px',
                      background:
                        password.length >= i * 3
                          ? i <= 1
                            ? 'var(--error)'
                            : i === 2
                            ? 'var(--warning)'
                            : 'var(--success)'
                          : 'var(--glass-border)',
                      transition: 'background 0.3s ease',
                    }}
                  />
                ))}
              </div>
              <p style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                {password.length < 4
                  ? 'Weak password'
                  : password.length < 8
                  ? 'Moderate – try making it longer'
                  : 'Strong password ✓'}
              </p>
            </div>
          )}

          {/* Error */}
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
            id="register-submit-btn"
            type="submit"
            className="btn-primary"
            style={{ marginTop: '0.5rem' }}
            disabled={loading}
          >
            {loading ? (
              <>
                <span style={{ display: 'inline-block', animation: 'spin 1s linear infinite' }}>⟳</span>
                &nbsp;Creating account…
              </>
            ) : (
              '📝  Create Account'
            )}
          </button>
        </form>

        {/* Divider */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
            margin: '1.5rem 0',
            color: 'var(--text-muted)',
            fontSize: '0.85rem',
          }}
        >
          <div style={{ flex: 1, height: '1px', background: 'var(--glass-border)' }} />
          Already have an account?
          <div style={{ flex: 1, height: '1px', background: 'var(--glass-border)' }} />
        </div>

        <Link to="/" style={{ textDecoration: 'none' }}>
          <button id="go-to-login-link-btn" type="button" className="btn-secondary">
            ← Back to Login
          </button>
        </Link>
      </div>
    </div>
  );
};

export default SignUpPage;