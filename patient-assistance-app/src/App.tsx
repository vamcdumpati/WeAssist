import React from 'react';
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';
import LoginPage from './components/LoginPage';
import SignUpPage from './components/SignUpPage';
import Home from './pages/Home';
import Profile from './pages/Profile';
import { useAuth } from './hooks/useAuth';

const App: React.FC = () => {
  const { user } = useAuth();

  return (
    <Router>
      <Switch>
        {user ? (
          <>
            <Route path="/home" component={Home} />
            <Route path="/profile" component={Profile} />
          </>
        ) : (
          <>
            <Route path="/" exact component={LoginPage} />
            <Route path="/signup" component={SignUpPage} />
          </>
        )}
      </Switch>
    </Router>
  );
};

export default App;