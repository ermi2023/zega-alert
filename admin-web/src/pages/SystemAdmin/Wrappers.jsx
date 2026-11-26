/**
 * Thin wrappers that mount the existing Users / Audit / Legal / SecurityPolicy
 * / Notifications pages under the /admin/* System Admin namespace. The
 * underlying pages already call the same /admin/users, /admin/audit, /legal,
 * /policy, /notifications endpoints — no logic is duplicated.
 *
 * Each wrapper prepends a small "System Admin" context strip so it's visually
 * clear which section the user is in.
 */
import UsersPage from '../Users';
import AuditPage from '../Audit';
import LegalPage from '../Legal';
import SecurityPolicyPage from '../SecurityPolicy';
import NotificationsPage from '../Notifications';
import FanRecords from './FanRecords';

const Banner = ({ title, subtitle }) => (
  <div className="panel" style={{ marginBottom: 16, padding: '12px 16px', borderLeft: '3px solid #183C59' }}>
    <strong style={{ color: '#9bc1de', textTransform: 'uppercase', fontSize: 11, letterSpacing: 1 }}>System Admin</strong>
    <h1 style={{ margin: '4px 0 0', fontSize: 20 }}>{title}</h1>
    <p style={{ margin: '2px 0 0', color: 'var(--muted)', fontSize: 13 }}>{subtitle}</p>
  </div>
);

export function AdminUsersPage() {
  return (
    <>
      <Banner title="User Management" subtitle="Create, edit, suspend and delete user accounts across the platform" />
      <UsersPage />
    </>
  );
}

export function AdminFanRecordsPage() {
  return (
    <>
      <Banner
        title="FAN Identity Verification"
        subtitle="Manage the mock ID records used to verify citizen FAN numbers"
      />
      <FanRecords />
    </>
  );
}

export function AdminAuditPage() {
  return (
    <>
      <Banner title="Audit Logs" subtitle="Centralized record of every important administrative action" />
      <AuditPage />
    </>
  );
}

export function AdminLegalPage() {
  return (
    <>
      <Banner title="Legal Content Management" subtitle="Create, review, translate and publish legal information for citizens" />
      <LegalPage />
    </>
  );
}

export function AdminSecurityPage() {
  return (
    <>
      <Banner title="Security Policies" subtitle="Password policy, session settings, data encryption, rate limiting" />
      <SecurityPolicyPage />
    </>
  );
}

export function AdminNotificationsPage() {
  return (
    <>
      <Banner title="Global Notifications" subtitle="System-level notifications and broadcast to staff and citizens" />
      <NotificationsPage />
    </>
  );
}
