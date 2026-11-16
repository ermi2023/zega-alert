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
  const { user, logout, updateUser } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [chatUnread, setChatUnread] = useState(0);
  const [darkMode, setDarkMode] = useState(() => localStorage.getItem('zega_theme') !== 'light');
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileForm, setProfileForm] = useState({ full_name: '', phone: '', email: '' });
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileMsg, setProfileMsg] = useState({ type: '', text: '' });

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

  const openProfile = () => {
    setProfileForm({
      full_name: user?.full_name || '',
      phone: user?.phone || '',
      email: user?.email || '',
    });
    setProfileMsg({ type: '', text: '' });
    setProfileOpen(true);
  };

  const saveProfile = async (e) => {
    e.preventDefault();
    setProfileSaving(true);
    setProfileMsg({ type: '', text: '' });
    try {
      const data = await api.put('/auth/me', {
        full_name: profileForm.full_name.trim(),
        phone: profileForm.phone.trim(),
        email: profileForm.email.trim(),
      });
      updateUser(data);
      setProfileMsg({ type: 'ok', text: 'Profile updated.' });
    } catch (err) {
      setProfileMsg({ type: 'err', text: err.message });
    } finally {
      setProfileSaving(false);
    }
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
        <div className="topbar-cad" style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#93c5fd', background: 'rgba(37, 99, 235, 0.12)', padding: '4px 12px', borderRadius: 20, border: '1px solid rgba(37, 99, 235, 0.3)' }}>
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
          <button type="button" className="user-chip user-chip-btn" onClick={openProfile} title="Edit my profile">
            <span className="avatar">{user?.full_name?.[0]}</span>
            <div>
              <b>{user?.full_name}</b>
              <small>{user?.phone || 'Add phone number'} · Edit</small>
            </div>
          </button>
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

      {profileOpen && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 16 }} onClick={() => setProfileOpen(false)}>
          <form
            onSubmit={saveProfile}
            onClick={(e) => e.stopPropagation()}
            style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: 24, maxWidth: 440, width: '100%' }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ margin: 0 }}>My profile</h3>
              <button type="button" className="btn ghost small" onClick={() => setProfileOpen(false)}>&times;</button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
                Full name
                <input value={profileForm.full_name} onChange={(e) => setProfileForm((f) => ({ ...f, full_name: e.target.value }))} required />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
                Phone number
                <input
                  value={profileForm.phone}
                  onChange={(e) => setProfileForm((f) => ({ ...f, phone: e.target.value }))}
                  placeholder="0911234567"
                  inputMode="tel"
                  required
                />
                <small style={{ color: 'var(--muted)', fontWeight: 400 }}>Used to sign in and receive dispatch calls. Ethiopian format, e.g. 0911234567.</small>
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
                Email
                <input type="email" value={profileForm.email} onChange={(e) => setProfileForm((f) => ({ ...f, email: e.target.value }))} />
              </label>
              {profileMsg.text && <div className={`msg ${profileMsg.type}`}>{profileMsg.text}</div>}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 4 }}>
                <button type="button" className="btn ghost" onClick={() => setProfileOpen(false)}>Cancel</button>
                <button className="btn" disabled={profileSaving}>{profileSaving ? 'Saving...' : 'Save changes'}</button>
              </div>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
