/**
 * Roles & Permission Management — read-only view of the 5 ZEGA-ALERT roles
 * and their platform-level permissions (spec §4). The role definitions live
 * in the backend (role_type enum + roles table + requireRole middleware);
 * this page documents them so the System Admin can verify RBAC boundaries.
 *
 * Spec §14.6: "User permissions must be controlled through Role-Based Access
 * Control." This page is intentionally read-only — role definitions are code,
 * not data; changing them requires a deployment.
 */
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../../api/client';

const ROLES = [
  {
    key: 'system_admin',
    name: 'System Admin',
    level: 5,
    purpose: 'Platform-level administration: users, roles, configuration, security policy, audit logs, legal content.',
    can: ['Manage all user accounts','Assign any role','Configure system settings','Edit security policy','View full audit log','Publish legal content','Access all regional data'],
    cannot: ['—'],
  },
  {
    key: 'regional_admin',
    name: 'Regional Admin',
    level: 4,
    purpose: 'Regional operations: crime reports, officer assignments, regional announcements.',
    can: ['Manage regional reports','Assign police officers','Publish announcements','Create missing/wanted persons','Manage geofences','View regional feedback'],
    cannot: ['Manage global users','Edit security policy','Configure carrier','Delete System Admin'],
  },
  {
    key: 'dispatcher',
    name: 'Emergency Dispatcher',
    level: 3,
    purpose: 'Emergency response: live SOS dispatch console and officer coordination.',
    can: ['View live SOS alerts','Acknowledge & dispatch SOS','View officer positions','Chat with citizens','Handle callbacks'],
    cannot: ['Manage users','Edit announcements','Configure system','Publish legal'],
  },
  {
    key: 'police',
    name: 'Regional Police',
    level: 2,
    purpose: 'Field investigation: assigned crime reports, missing-person sightings.',
    can: ['View assigned reports','Update report status','Submit sightings','Handle callbacks','Chat with citizens'],
    cannot: ['Assign officers','Publish announcements','Manage users','Configure system'],
  },
  {
    key: 'citizen',
    name: 'Citizen',
    level: 1,
    purpose: 'Public-facing mobile app: report crimes, request SOS, view announcements.',
    can: ['Submit reports','Trigger SOS','Submit missing-person sightings','Chat with staff','Verify Fayda ID'],
    cannot: ['Access admin portal','View other users','Manage any data'],
  },
];

export default function RolesPage() {
  const { t } = useTranslation();
  const [counts, setCounts] = useState({});

  useEffect(() => {
    api.get('/admin/stats').then(d => {
      const byRole = (d.users && d.users.byRole) || {};
      setCounts(Object.fromEntries(Object.entries(byRole).map(([k, v]) => [k, v.total || 0])));
    }).catch(() => {});
  }, []);

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('systemAdmin.roles.title', { defaultValue: 'Roles & Permissions' })}</h1>
          <p>{t('systemAdmin.roles.subtitle', { defaultValue: 'Role-Based Access Control (RBAC) — five defined user roles' })}</p>
        </div>
      </div>

      <div className="panel" style={{ marginBottom: 16 }}>
        <p style={{ margin: 0, color: 'var(--muted)', fontSize: 13 }}>
          {t('systemAdmin.roles.note', {
            defaultValue: 'Role definitions are enforced in the backend via the role_type enum and requireRole() middleware on every protected endpoint. The five roles below are hierarchical — a higher level can manage lower levels but never escalate privileges. Changes to role definitions require a deployment; this page is for verification and auditing.'
          })}
        </p>
      </div>

      <div className="grid-2">
        {ROLES.map(role => (
          <div className="panel" key={role.key}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <h2 style={{ margin: 0 }}>{role.name}</h2>
              <span className="badge blue">Level {role.level}</span>
            </div>
            <p style={{ color: 'var(--muted)', marginTop: 8, fontSize: 13 }}>{role.purpose}</p>
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 11, color: 'var(--success)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>
                {t('systemAdmin.roles.canDo', { defaultValue: 'Can do' })}
              </div>
              <ul style={{ margin: 0, paddingLeft: 20, fontSize: 13 }}>
                {role.can.map((c, i) => <li key={i}>{c}</li>)}
              </ul>
            </div>
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 11, color: 'var(--danger)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>
                {t('systemAdmin.roles.cannotDo', { defaultValue: 'Cannot do' })}
              </div>
              <ul style={{ margin: 0, paddingLeft: 20, fontSize: 13 }}>
                {role.cannot.map((c, i) => <li key={i}>{c}</li>)}
              </ul>
            </div>
            <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px solid var(--line)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 12, color: 'var(--muted)' }}>{t('systemAdmin.roles.currentUsers', { defaultValue: 'Current users in this role' })}</span>
              <b style={{ fontSize: 18, color: '#183C59' }}>{counts[role.key] ?? '—'}</b>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
