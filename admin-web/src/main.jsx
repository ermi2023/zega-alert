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
// System Admin 12-section dashboard (spec §13)
import SystemAdminDashboard from './pages/SystemAdmin/Dashboard';
import RolesPage from './pages/SystemAdmin/Roles';
import ConfigPage from './pages/SystemAdmin/Config';
import CarrierPage from './pages/SystemAdmin/Carrier';
import ActivityPage from './pages/SystemAdmin/Activity';
import ProfilePage from './pages/SystemAdmin/Profile';
import { AdminUsersPage, AdminAuditPage, AdminLegalPage, AdminSecurityPage, AdminNotificationsPage } from './pages/SystemAdmin/Wrappers';
import './i18n';
import './styles.css';

// Auth gate: must be logged in.
const Protected = ({ children }) => {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  return <Layout>{children}</Layout>;
};

// Role gate: must be logged in AND hold one of the allowed roles. Spec §14.7
// ("Unauthorized users must not access administrative functions") — this is
// enforced client-side AND in the backend via requireRole() middleware on
// every /admin/* endpoint. The client guard just keeps the UI clean.
const RequireRole = (...roles) => ({ children }) => {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  if (!roles.includes(user.role)) {
    // Send the user back to their own dashboard if they try a route that
    // doesn't belong to their role.
    return <Navigate to="/" replace />;
  }
  return <Layout>{children}</Layout>;
};

const RequireSystemAdmin = RequireRole('system_admin');

const App = () => (
  <AuthProvider>
    <ToastProvider>
      <BrowserRouter>
        <ErrorBoundary>
          <Routes>
            <Route path="/login" element={<Login />} />

            {/* Operational routes — shared by Regional Admin, Dispatcher, Police, Citizen. */}
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

            {/* System Admin 12-section dashboard (spec §13). All routes are
                role-guarded — only system_admin can reach them. The old
                /users /audit /security /legal /notifications routes above are
                kept for Regional Admin / Dispatcher / Police / Citizen use;
                System Admin sees the same backend endpoints through these
                dedicated /admin/* wrappers. */}
            <Route path="/admin"               element={<RequireSystemAdmin><SystemAdminDashboard /></RequireSystemAdmin>} />
            <Route path="/admin/users"         element={<RequireSystemAdmin><AdminUsersPage /></RequireSystemAdmin>} />
            <Route path="/admin/roles"         element={<RequireSystemAdmin><RolesPage /></RequireSystemAdmin>} />
            <Route path="/admin/config"        element={<RequireSystemAdmin><ConfigPage /></RequireSystemAdmin>} />
            <Route path="/admin/carrier"       element={<RequireSystemAdmin><CarrierPage /></RequireSystemAdmin>} />
            <Route path="/admin/security"      element={<RequireSystemAdmin><AdminSecurityPage /></RequireSystemAdmin>} />
            <Route path="/admin/audit"         element={<RequireSystemAdmin><AdminAuditPage /></RequireSystemAdmin>} />
            <Route path="/admin/legal"         element={<RequireSystemAdmin><AdminLegalPage /></RequireSystemAdmin>} />
            <Route path="/admin/activity"      element={<RequireSystemAdmin><ActivityPage /></RequireSystemAdmin>} />
            <Route path="/admin/notifications" element={<RequireSystemAdmin><AdminNotificationsPage /></RequireSystemAdmin>} />
            <Route path="/admin/profile"       element={<RequireSystemAdmin><ProfilePage /></RequireSystemAdmin>} />

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </ErrorBoundary>
      </BrowserRouter>
    </ToastProvider>
  </AuthProvider>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
