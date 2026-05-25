import React from 'react';
import { BrowserRouter as Router, Route, Switch, Redirect } from 'react-router-dom';
import LoginPage from './components/LoginPage';
import SignUpPage from './components/SignUpPage';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';
import { useAuth } from './hooks/useAuth';

const App: React.FC = () => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div 
        style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center', 
          minHeight: '100vh',
          background: 'var(--bg-primary)',
          color: '#ffffff',
          fontFamily: 'sans-serif'
        }}
      >
        <div style={{ textAlign: 'center' }}>
          <div className="pulse-location-icon" style={{ animationDuration: '1s', width: '50px', height: '50px', fontSize: '1.5rem' }}>⏳</div>
          <p style={{ marginTop: '1rem', color: 'var(--text-secondary)' }}>Loading WeAssist Admin Portal...</p>
        </div>
      </div>
    );
  }

  return (
    <Router>
      <Switch>
        {user ? (
          // Logged In Routes
          <Switch>
            <Route path="/home" exact component={Dashboard} />
            <Route path="/profile" exact component={Profile} />
            <Redirect from="/signup" to="/home" />
            <Redirect from="/" to="/home" />
            {/* Fallback to home */}
            <Route path="*">
              <Redirect to="/home" />
            </Route>
          </Switch>
        ) : (
          // Logged Out Routes
          <Switch>
            <Route path="/" exact component={LoginPage} />
            <Route path="/signup" exact component={SignUpPage} />
            {/* Fallback to login */}
            <Route path="*">
              <Redirect to="/" />
            </Route>
          </Switch>
        )}
      </Switch>
    </Router>
  );
};

export default App;