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
  const { user, logout } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [chatUnread, setChatUnread] = useState(0);
  const [darkMode, setDarkMode] = useState(() => localStorage.getItem('zega_theme') !== 'light');

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

  const nav = [
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
    { to: '/users', label: t('nav.users'), icon: 'users' },
    { to: '/audit', label: t('nav.audit'), icon: 'audit' },
    { to: '/security', label: t('nav.security'), icon: 'security' },
    { to: '/notifications', label: t('nav.notifications'), icon: 'bell' },
  ];

  const ROLE_NAV = {
    system_admin: nav,
    regional_admin: nav.filter((n) => !['/users', '/audit'].includes(n.to)),
    dispatcher: nav.filter((n) => ['/', '/sos', '/reports', '/persons', '/callbacks', '/pod', '/chat', '/notifications'].includes(n.to)),
    police: nav.filter((n) => ['/', '/reports', '/persons', '/callbacks', '/pod', '/announcements', '/chat', '/notifications'].includes(n.to)),
  };

  const visibleNav = ROLE_NAV[user?.role] || [];

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
          <img className="brand-flag" src="/brand/ethiopia-flag.png" alt="Ethiopia" />
          <span style={{ color: '#f59e0b', display: 'flex', alignItems: 'center' }} title="Official Police CAD">
            <Icon name="shield" />
          </span>
          <strong>ZEGA-ALERT</strong>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#93c5fd', background: 'rgba(37, 99, 235, 0.12)', padding: '4px 12px', borderRadius: 20, border: '1px solid rgba(37, 99, 235, 0.3)' }}>
          <span className="dot blue pulse" />
          <span style={{ fontWeight: 600, letterSpacing: '0.5px' }}>POLICE CAD · DISPATCH ACTIVE</span>
        </div>
        <NavLink to="/notifications" style={{ position: 'relative', display: 'flex', alignItems: 'center', marginLeft: 8 }}>
          <span style={{ fontSize: 20 }}>🔔</span>
          {unreadCount > 0 && <span style={{ position: 'absolute', top: -6, right: -6, background: '#ef4444', color: '#fff', borderRadius: 99, fontSize: 10, fontWeight: 700, padding: '1px 5px', minWidth: 16, textAlign: 'center' }}>{unreadCount > 99 ? '99+' : unreadCount}</span>}
        </NavLink>
      </header>

      {menuOpen && <div className="drawer-backdrop" onClick={() => setMenuOpen(false)} />}

      <aside className={`sidebar${menuOpen ? ' open' : ''}`}>
        <div className="brand">
          <div className="brand-row">
            <img className="brand-flag" src="/brand/ethiopia-flag.png" alt="Ethiopia" />
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
              className={({ isActive }) => (isActive ? 'active' : '')}
              onClick={() => setMenuOpen(false)}
            >
              <span className="icon"><Icon name={n.icon} /></span> {n.label}
              {n.to === '/chat' && chatUnread > 0 && <span style={{marginLeft:'auto',background:'#ef4444',color:'#fff',borderRadius:'50%',width:18,height:18,fontSize:10,fontWeight:800,display:'inline-flex',alignItems:'center',justifyContent:'center'}}>{chatUnread > 99 ? '99+' : chatUnread}</span>}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="user-chip">
            <span className="avatar">{user?.full_name?.[0]}</span>
            <div>
              <b>{user?.full_name}</b>
              <small>{user?.phone}</small>
            </div>
          </div>
          <button
            className="btn ghost"
            onClick={() => setDarkMode(d => !d)}
            style={{ width: '100%', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'center' }}
            aria-label="Toggle theme"
          >
            {darkMode ? '☀️ Light Mode' : '🌙 Dark Mode'}
          </button>
          <select value={i18n.language} onChange={changeLang} className="lang-select">
            {LANGUAGES.map((l) => (
              <option key={l.code} value={l.code}>{l.label}</option>
            ))}
          </select>
          <button className="btn ghost" onClick={logout}>{t('logout')}</button>
        </div>
      </aside>
      <main className="main">
        {children}
      </main>
    </div>
  );
}
