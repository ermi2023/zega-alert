import { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';
import Icon from './Icon';
import { api, API_BASE } from '../api/client';
import { io } from 'socket.io-client';

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'am', label: 'አማርኛ' },
  { code: 'om', label: 'Afaan Oromoo' },
  { code: 'ti', label: 'ትግርኛ' },
];

export default function Layout({ children }) {
  const { t, i18n } = useTranslation();
  const { user } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [chatUnread, setChatUnread] = useState(0);
  // Read-only theme flag: the Settings page owns the toggle and writes
  // localStorage; we just read it once here so the correct palette applies
  // on every route, not only when /settings is open.
  const [darkMode] = useState(() => localStorage.getItem('zega_theme') !== 'light');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', darkMode ? 'dark' : 'light');
    localStorage.setItem('zega_theme', darkMode ? 'dark' : 'light');
  }, [darkMode]);

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') setMenuOpen(false); };
    const mq = window.matchMedia('(min-width: 769px)');
    const onResize = (e) => { if (e.matches) setMenuOpen(false); };
    window.addEventListener('keydown', onKey);
    mq.addEventListener('change', onResize);
    document.body.style.overflow = menuOpen ? 'hidden' : '';
    return () => {
      window.removeEventListener('keydown', onKey);
      mq.removeEventListener('change', onResize);
      document.body.style.overflow = '';
    };
  }, [menuOpen]);

  useEffect(() => {
    api.get('/notifications?limit=50').then((data) => {
      const list = Array.isArray(data) ? data : (data?.notifications || []);
      setUnreadCount(list.filter((n) => n.is_read === false).length);
    }).catch(() => {});

    const socket = io(API_BASE || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('sos:new', () => setUnreadCount((c) => c + 1));
    socket.on('notification:new', () => setUnreadCount((c) => c + 1));
    return () => socket.close();
  }, []);

  useEffect(() => {
    api.get('/chat/unread-count').then((data) => {
      setChatUnread(typeof data?.count === 'number' ? data.count : 0);
    }).catch(() => {});
  }, []);

  // Operational nav — used by Regional Admin, Dispatcher, Police and Citizen
  // for case-work (reports, SOS, persons, etc.). System Admin does NOT use
  // this nav — they get the dedicated admin nav below (spec §13 +
  // implementation note: "Do not mix the System Admin and Regional Admin
  // dashboards"). Every role gets the Settings entry at the bottom.
  const operationalNav = [
    { to: '/', label: t('nav.dashboard'), icon: 'dashboard' },
    { to: '/sos', label: t('nav.sos'), icon: 'sos' },
    { to: '/reports', label: t('nav.reports'), icon: 'reports' },
    { to: '/persons', label: t('nav.persons'), icon: 'persons' },
    { to: '/callbacks', label: t('nav.callbacks'), icon: 'callbacks' },
    { to: '/pod', label: t('nav.pod'), icon: 'pod' },
    { to: '/feedback', label: t('nav.feedback'), icon: 'feedback' },
    { to: '/announcements', label: t('nav.announcements'), icon: 'announcements' },
    { to: '/chat', label: t('nav.chat'), icon: 'chat' },
    { to: '/legal', label: t('nav.legal'), icon: 'legal' },
    { to: '/geofences', label: t('nav.geofences'), icon: 'geofences' },
    { to: '/notifications', label: t('nav.notifications'), icon: 'bell' },
    { to: '/settings', label: t('nav.settings', { defaultValue: 'Settings' }), icon: 'settings' },
  ];

  // System Admin nav (spec §13). The configuration pages that used to live here
  // (Profile, Config, Carrier, Roles, Activity) now live under the consolidated
  // /settings hub so every role has one place to manage account + system config.
  const systemAdminNav = [
    { to: '/admin',                label: t('systemAdmin.nav.dashboard',     { defaultValue: 'Dashboard' }),                icon: 'dashboard' },
    { to: '/admin/users',          label: t('systemAdmin.nav.users',          { defaultValue: 'User Management' }),           icon: 'users' },
    { to: '/admin/security',       label: t('systemAdmin.nav.security',       { defaultValue: 'Security Policies' }),        icon: 'security' },
    { to: '/admin/audit',          label: t('systemAdmin.nav.audit',         { defaultValue: 'Audit Logs' }),                icon: 'audit' },
    { to: '/admin/legal',          label: t('systemAdmin.nav.legal',          { defaultValue: 'Legal Content' }),             icon: 'legal' },
    { to: '/admin/notifications',  label: t('systemAdmin.nav.notifications',  { defaultValue: 'Notifications' }),              icon: 'bell' },
    { to: '/settings',             label: t('nav.settings', { defaultValue: 'Settings' }), icon: 'settings' },
  ];

  const ROLE_NAV = {
    // System Admin sees ONLY the admin nav — fully separated from operational roles.
    system_admin: systemAdminNav,
    // Regional Admin: operational nav, minus user-management & audit (which are System Admin only).
    regional_admin: operationalNav.filter((n) => !['/users', '/audit'].includes(n.to)),
    dispatcher: operationalNav.filter((n) => ['/', '/sos', '/reports', '/persons', '/callbacks', '/pod', '/chat', '/notifications'].includes(n.to)),
    police: operationalNav.filter((n) => ['/', '/reports', '/persons', '/callbacks', '/pod', '/announcements', '/chat', '/notifications'].includes(n.to)),
    citizen: operationalNav.filter((n) => ['/', '/reports', '/persons', '/announcements', '/chat', '/notifications'].includes(n.to)),
  };

  const visibleNav = ROLE_NAV[user?.role] || operationalNav;

  const changeLang = (e) => {
    const lang = e.target.value;
    i18n.changeLanguage(lang);
    localStorage.setItem('zega_lang', lang);
  };

  return (
    <div className="layout">
      <div style={{ height: 3, width: '100%', background: 'linear-gradient(90deg, #078930 33.3%, #fcdd09 33.3% 66.6%, #da121a 66.6%)', position: 'fixed', top: 0, left: 0, zIndex: 1000 }} />
      <header className="topbar">
        <button
          className="hamburger"
          onClick={() => setMenuOpen(true)}
          aria-label="Open menu"
          aria-expanded={menuOpen}
        >
          <span /><span /><span />
        </button>
        <div className="topbar-brand">
          <img className="brand-flag" src="/brand/logo.png" alt="ZEGA-ALERT logo" />
          <span style={{ color: '#f59e0b', display: 'flex', alignItems: 'center' }} title="Official Police CAD">
            <Icon name="shield" />
          </span>
          <strong>ZEGA-ALERT</strong>
        </div>
        <div className="topbar-cad" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#9bc1de', background: 'rgba(24, 60, 89, 0.35)', padding: '4px 12px', borderRadius: 20, border: '1px solid rgba(24, 60, 89, 0.6)' }}>
          <span className="dot blue pulse" />
          <span style={{ fontWeight: 600, letterSpacing: '0.5px' }}>POLICE CAD · DISPATCH ACTIVE</span>
        </div>
        <select
          value={i18n.language}
          onChange={changeLang}
          className="lang-select topbar-lang"
          aria-label="Language"
          title="Language"
        >
          {LANGUAGES.map((l) => (
            <option key={l.code} value={l.code}>{l.label}</option>
          ))}
        </select>
        <NavLink to="/notifications" style={{ position: 'relative', display: 'flex', alignItems: 'center', marginLeft: 8 }}>
          <span style={{ fontSize: 20 }}>🔔</span>
          {unreadCount > 0 && <span style={{ position: 'absolute', top: -6, right: -6, background: '#ef4444', color: '#fff', borderRadius: 99, fontSize: 10, fontWeight: 700, padding: '1px 5px', minWidth: 16, textAlign: 'center' }}>{unreadCount > 99 ? '99+' : unreadCount}</span>}
        </NavLink>
      </header>

      {menuOpen && <div className="drawer-backdrop" onClick={() => setMenuOpen(false)} />}

      <aside className={`sidebar${menuOpen ? ' open' : ''}`}>
        <div className="brand">
          <div className="brand-row">
            <img className="brand-flag" src="/brand/logo.png" alt="ZEGA-ALERT logo" />
            <span style={{ color: '#f59e0b', display: 'flex', alignItems: 'center' }} title="Official Police CAD">
              <Icon name="shield" />
            </span>
            <strong>ZEGA-ALERT</strong>
            <button className="drawer-close" onClick={() => setMenuOpen(false)} aria-label="Close menu">✕</button>
          </div>
          <span>{t(`roles.${user?.role}`) || user?.role}</span>
        </div>
        <nav>
          {visibleNav.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              // /admin and / should only show "active" on an exact match, not on every sub-route.
              end={(n.to === '/admin' || n.to === '/')}
              className={({ isActive }) => (isActive ? 'active' : '')}
              onClick={() => setMenuOpen(false)}
            >
              <span className="icon"><Icon name={n.icon} /></span> {n.label}
              {n.to === '/chat' && chatUnread > 0 && <span style={{marginLeft:'auto',background:'#ef4444',color:'#fff',borderRadius:'50%',width:18,height:18,fontSize:10,fontWeight:800,display:'inline-flex',alignItems:'center',justifyContent:'center'}}>{chatUnread > 99 ? '99+' : chatUnread}</span>}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="main">
        {children}
      </main>
    </div>
  );
}
