import React from 'react';

interface VerificationToastProps {
  isOpen: boolean;
  toggle: () => void;
  message?: string;
}

const VerificationToast: React.FC<VerificationToastProps> = ({ isOpen, toggle, message }) => {
  if (!isOpen) return null;

  return (
    <div 
      className="message-bubble" 
      style={{ 
        position: 'fixed',
        bottom: '20px',
        right: '20px',
        maxWidth: '350px',
        zIndex: 9999,
        background: 'var(--bg-secondary)',
        border: '1px solid var(--glass-border)',
        borderLeft: '4px solid var(--warning)',
        boxShadow: 'var(--shadow-lg)',
        padding: '1.25rem',
        borderRadius: 'var(--radius-md)',
        display: 'flex',
        flexDirection: 'column',
        gap: '0.5rem',
        animation: 'slide-in 0.3s ease-out'
      }}
    >
      <div className="flex-between" style={{ fontWeight: '600', color: '#ffffff' }}>
        <span>⚠️ Email Verification</span>
        <button 
          onClick={toggle} 
          style={{ 
            width: 'auto', 
            background: 'none', 
            border: 'none', 
            color: 'var(--text-muted)', 
            cursor: 'pointer',
            padding: 0,
            fontSize: '1rem' 
          }}
        >
          ✕
        </button>
      </div>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
        {message || 'Please complete your email verification to proceed with login.'}
      </p>
    </div>
  );
};

export default VerificationToast;