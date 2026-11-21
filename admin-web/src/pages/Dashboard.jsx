import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { RegionalAdminDashboard, DispatcherDashboard, PoliceDashboard } from './RoleDashboards';

/**
 * Role dispatcher. System Admin is routed to the dedicated /admin/* dashboard
 * (spec §13) — see main.jsx. Regional Admin, Dispatcher and Police keep their
 * operational dashboards here. Implementation note: System Admin and Regional
 * Admin dashboards are fully separated (no shared routes or components).
 */
export default function Dashboard() {
  const { user } = useAuth();

  switch (user?.role) {
    case 'system_admin':
      // System Admin lives at /admin (the 12-section dashboard).
      return <Navigate to="/admin" replace />;
    case 'regional_admin':
      return <RegionalAdminDashboard />;
    case 'dispatcher':
      return <DispatcherDashboard />;
    case 'police':
      return <PoliceDashboard />;
    default:
      return <Navigate to="/reports" replace />;
  }
}
