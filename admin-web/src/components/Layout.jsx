import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'am', label: 'አማርኛ' },
  { code: 'om', label: 'Afaan Oromoo' },
  { code: 'ti', label: 'ትግርኛ' },
];

export default function Layout({ children }) {
  const { t, i18n } = useTranslation();
  const { user, logout } = useAuth();

  const nav = [
    { to: '/', label: t('nav.dashboard'), icon: '▦' },
    { to: '/sos', label: t('nav.sos'), icon: 'SOS' },
    { to: '/reports', label: t('nav.reports'), icon: '⚑' },
    { to: '/persons', label: t('nav.persons'), icon: '◉' },
    { to: '/callbacks', label: t('nav.callbacks'), icon: '✆' },
    { to: '/pod', label: t('nav.pod'), icon: '♿' },
    { to: '/feedback', label: t('nav.feedback'), icon: '★' },
    { to: '/announcements', label: t('nav.announcements'), icon: '📢' },
    { to: '/chat', label: t('nav.chat'), icon: '💬' },
    { to: '/legal', label: t('nav.legal'), icon: '⚖' },
    { to: '/geofences', label: t('nav.geofences'), icon: '◎' },
    { to: '/users', label: t('nav.users'), icon: '👤' },
    { to: '/audit', label: t('nav.audit'), icon: '🔎' },
    { to: '/security', label: t('nav.security'), icon: '🔐' },
  ];

  const ROLE_NAV = {
    system_admin: nav,
    regional_admin: nav.filter((n) => !['/users', '/audit'].includes(n.to)),
    dispatcher: nav.filter((n) => ['/', '/sos', '/reports', '/persons', '/callbacks', '/pod', '/chat'].includes(n.to)),
    police: nav.filter((n) => ['/', '/reports', '/persons', '/callbacks', '/pod', '/announcements', '/chat'].includes(n.to)),
  };

  const visibleNav = ROLE_NAV[user?.role] || [];

  const changeLang = (e) => {
    const lang = e.target.value;
    i18n.changeLanguage(lang);
    localStorage.setItem('zega_lang', lang);
  };

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-row">
            <img className="brand-flag" src="/brand/ethiopia-flag.png" alt="Ethiopia" />
            <strong>ZEGA-ALERT</strong>
          </div>
          <span>{t(`roles.${user?.role}`) || user?.role}</span>
        </div>
        <nav>
          {visibleNav.map((n) => (
            <NavLink key={n.to} to={n.to} className={({ isActive }) => (isActive ? 'active' : '')}>
              <span className="icon">{n.icon}</span> {n.label}
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
