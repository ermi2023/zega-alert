import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ToastProvider } from './components/Toast';
import ErrorBoundary from './components/ErrorBoundary';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Reports from './pages/Reports';
import Sos from './pages/Sos';
import MissingWanted from './pages/MissingWanted';
import Announcements from './pages/Announcements';
import Chat from './pages/Chat';
import Legal from './pages/Legal';
import Geofences from './pages/Geofences';
import Users from './pages/Users';
import Audit from './pages/Audit';
import Feedback from './pages/Feedback';
import Callbacks from './pages/Callbacks';
import PeopleOfDetermination from './pages/PeopleOfDetermination';
import SecurityPolicy from './pages/SecurityPolicy';
import Notifications from './pages/Notifications';
import './i18n';
import './styles.css';

const Protected = ({ children }) => {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  return <Layout>{children}</Layout>;
};

const App = () => (
  <AuthProvider>
    <ToastProvider>
      <BrowserRouter>
        <ErrorBoundary>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/" element={<Protected><Dashboard /></Protected>} />
            <Route path="/reports" element={<Protected><Reports /></Protected>} />
            <Route path="/sos" element={<Protected><Sos /></Protected>} />
            <Route path="/persons" element={<Protected><MissingWanted /></Protected>} />
            <Route path="/announcements" element={<Protected><Announcements /></Protected>} />
            <Route path="/chat" element={<Protected><Chat /></Protected>} />
            <Route path="/legal" element={<Protected><Legal /></Protected>} />
            <Route path="/geofences" element={<Protected><Geofences /></Protected>} />
            <Route path="/users" element={<Protected><Users /></Protected>} />
            <Route path="/audit" element={<Protected><Audit /></Protected>} />
            <Route path="/feedback" element={<Protected><Feedback /></Protected>} />
            <Route path="/callbacks" element={<Protected><Callbacks /></Protected>} />
            <Route path="/pod" element={<Protected><PeopleOfDetermination /></Protected>} />
            <Route path="/security" element={<Protected><SecurityPolicy /></Protected>} />
            <Route path="/notifications" element={<Protected><Notifications /></Protected>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </ErrorBoundary>
      </BrowserRouter>
    </ToastProvider>
  </AuthProvider>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
