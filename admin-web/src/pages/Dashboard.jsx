import { useAuth } from '../context/AuthContext';
import { SystemAdminDashboard, RegionalAdminDashboard, DispatcherDashboard, PoliceDashboard } from './RoleDashboards';

export default function Dashboard() {
  const { user } = useAuth();

  switch (user?.role) {
    case 'system_admin':
      return <SystemAdminDashboard />;
    case 'regional_admin':
      return <RegionalAdminDashboard />;
    case 'dispatcher':
      return <DispatcherDashboard />;
    case 'police':
      return <PoliceDashboard />;
    default:
      return <SystemAdminDashboard />;
  }
}
