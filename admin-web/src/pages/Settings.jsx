/**
 * Consolidated Settings page (spec: one "Settings" entry on the sidebar that
 * groups everything a user can configure about their account / the system).
 *
 * Tabs shown depend on role:
 *  - everyone:           General (theme + language), My Profile
 *  - system_admin only:  + System Config, Roles & Permissions, Carrier,
 *                        System Activity
 *
 * The admin tabs embed the existing /pages/SystemAdmin/* components directly
 * (lazy-loaded so non-admins never download them), so this page replaces the
 * scattered /admin/* sidebar entries with a single hub.
 *
 * Language switching uses the Google Translate backend (see
 * /api/i18n/bundle/:lang) for any language beyond the four bundled ones
 * (en/am/om/ti) — the picker lists ~14 languages.
 */
import { Suspense, lazy, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';
import { api } from '../api/client';
import Icon from '../components/Icon';

// Lazy-load admin sub-pages so they're only in the bundle for users who open them.
const ConfigPage = lazy(() => import('./SystemAdmin/Config'));
const RolesPage = lazy(() => import('./SystemAdmin/Roles'));
const CarrierPage = lazy(() => import('./SystemAdmin/Carrier'));
const ActivityPage = lazy(() => import('./SystemAdmin/Activity'));

const DEFAULT_LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'am', label: 'አማርኛ (Amharic)' },
  { code: 'om', label: 'Afaan Oromoo' },
  { code: 'ti', label: 'ትግርኛ (Tigrinya)' },
];

export default function Settings() {
  const { t, i18n } = useTranslation();
  const { user, logout, updateUser } = useAuth();
  const isAdmin = user?.role === 'system_admin';

  const [tab, setTab] = useState('general');
  const [darkMode, setDarkMode] = useState(() => localStorage.getItem('zega_theme') !== 'light');
  const [languages, setLanguages] = useState(DEFAULT_LANGUAGES);
  const [langLoading, setLangLoading] = useState(false);
  const [langMsg, setLangMsg] = useState({ type: '', text: '' });

  // Profile form state
  const [profileForm, setProfileForm] = useState({ full_name: '', phone: '', email: '' });
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileMsg, setProfileMsg] = useState({ type: '', text: '' });

  // Build the tab list for the current role.
  const tabs = [
    { id: 'general',  label: t('settings.tabs.general',  { defaultValue: 'General' }) },
    { id: 'profile',  label: t('settings.tabs.profile',  { defaultValue: 'My Profile' }) },
    ...(isAdmin ? [
      { id: 'config',   label: t('settings.tabs.config',   { defaultValue: 'System Config' }) },
      { id: 'roles',    label: t('settings.tabs.roles',    { defaultValue: 'Roles & Permissions' }) },
      { id: 'carrier',  label: t('settings.tabs.carrier',  { defaultValue: 'Carrier' }) },
      { id: 'activity', label: t('settings.tabs.activity', { defaultValue: 'System Activity' }) },
    ] : []),
  ];

  // Persist theme on toggle.
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', darkMode ? 'dark' : 'light');
    localStorage.setItem('zega_theme', darkMode ? 'dark' : 'light');
  }, [darkMode]);

  // Fetch the full language list from the backend (includes Google Translate
  // languages beyond the static four). Falls back to the static list on error.
  useEffect(() => {
    let cancelled = false;
    api.get('/i18n/languages').then((data) => {
      if (cancelled) return;
      const list = data?.languages;
      if (Array.isArray(list) && list.length) setLanguages(list);
    }).catch(() => { /* keep DEFAULT_LANGUAGES */ });
    return () => { cancelled = true; };
  }, []);

  // Pre-fill the profile form when the user loads.
  useEffect(() => {
    setProfileForm({
      full_name: user?.full_name || '',
      phone: user?.phone || '',
      email: user?.email || '',
    });
  }, [user]);

  const changeLang = async (lang) => {
    setLangLoading(true);
    setLangMsg({ type: '', text: '' });
    try {
      // i18n.changeLanguage is wrapped in i18n/index.js to fetch remote bundles
      // for non-bundled languages; it resolves once the bundle is registered.
      await i18n.changeLanguage(lang);
      localStorage.setItem('zega_lang', lang);
      setLangMsg({ type: 'ok', text: t('settings.language.applied', { defaultValue: 'Language updated.' }) });
    } catch (e) {
      setLangMsg({ type: 'err', text: e.message });
    } finally {
      setLangLoading(false);
    }
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
      setProfileMsg({ type: 'ok', text: t('settings.profile.saved', { defaultValue: 'Profile updated.' }) });
    } catch (err) {
      setProfileMsg({ type: 'err', text: err.message });
    } finally {
      setProfileSaving(false);
    }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Icon name="settings" size={24} /> {t('settings.title', { defaultValue: 'Settings' })}
          </h1>
          <p>{t('settings.subtitle', { defaultValue: 'Manage your account, appearance, and platform configuration' })}</p>
        </div>
      </div>

      <div className="tabs" style={{ marginBottom: 20, flexWrap: 'wrap' }}>
        {tabs.map((tb) => (
          <button
            key={tb.id}
            className={`tab${tab === tb.id ? ' active' : ''}`}
            onClick={() => setTab(tb.id)}
          >
            {tb.label}
          </button>
        ))}
      </div>

      {/* ---- GENERAL ---- */}
      {tab === 'general' && (
        <div className="panel" style={{ maxWidth: 560 }}>
          <h2 style={{ marginTop: 0 }}>{t('settings.appearance.title', { defaultValue: 'Appearance' })}</h2>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid var(--line)' }}>
            <div>
              <b>{t('settings.appearance.theme', { defaultValue: 'Theme' })}</b>
              <div style={{ color: 'var(--muted)', fontSize: 12 }}>
                {darkMode ? t('settings.appearance.dark', { defaultValue: 'Dark mode' }) : t('settings.appearance.light', { defaultValue: 'Light mode' })}
              </div>
            </div>
            <button className="btn ghost" onClick={() => setDarkMode(d => !d)}>
              {darkMode ? '☀️ Light' : '🌙 Dark'}
            </button>
          </div>

          <h2>{t('settings.language.title', { defaultValue: 'Language' })}</h2>
          <p style={{ color: 'var(--muted)', fontSize: 13, marginTop: 0 }}>
            {t('settings.language.help', { defaultValue: 'The four official languages are built-in. Other languages are translated live by Google Translate and cached after first use.' })}
          </p>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6, fontSize: 13, maxWidth: 360 }}>
            {t('settings.language.select', { defaultValue: 'Interface language' })}
            <select
              value={i18n.language?.split('-')[0] || 'en'}
              onChange={(e) => changeLang(e.target.value)}
              disabled={langLoading}
              style={{ padding: '8px 10px' }}
            >
              {languages.map((l) => (
                <option key={l.code} value={l.code}>
                  {l.label}{l.bundled ? '' : ` · ${t('settings.language.translated', { defaultValue: 'auto-translated' })}`}
                </option>
              ))}
            </select>
          </label>
          {langLoading && <p style={{ color: 'var(--muted)', fontSize: 12, marginTop: 8 }}>
            {t('settings.language.loading', { defaultValue: 'Loading translation…' })}
          </p>}
          {langMsg.text && <div className={`msg ${langMsg.type}`} style={{ marginTop: 8 }}>{langMsg.text}</div>}
        </div>
      )}

      {/* ---- MY PROFILE ---- */}
      {tab === 'profile' && (
        <div className="panel" style={{ maxWidth: 560 }}>
          <h2 style={{ marginTop: 0 }}>{t('settings.profile.title', { defaultValue: 'My Profile' })}</h2>
          <form onSubmit={saveProfile} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
              {t('settings.profile.fullName', { defaultValue: 'Full name' })}
              <input value={profileForm.full_name} onChange={(e) => setProfileForm(f => ({ ...f, full_name: e.target.value }))} required />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
              {t('settings.profile.phone', { defaultValue: 'Phone number' })}
              <input value={profileForm.phone} onChange={(e) => setProfileForm(f => ({ ...f, phone: e.target.value }))} placeholder="0911234567" inputMode="tel" required />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 13 }}>
              {t('settings.profile.email', { defaultValue: 'Email' })}
              <input type="email" value={profileForm.email} onChange={(e) => setProfileForm(f => ({ ...f, email: e.target.value }))} />
            </label>
            {profileMsg.text && <div className={`msg ${profileMsg.type}`}>{profileMsg.text}</div>}
            <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
              <button className="btn" disabled={profileSaving}>{profileSaving ? t('settings.profile.saving', { defaultValue: 'Saving…' }) : t('settings.profile.save', { defaultValue: 'Save changes' })}</button>
            </div>
          </form>
          <hr style={{ border: 'none', borderTop: '1px solid var(--line)', margin: '24px 0' }} />
          <button className="btn ghost danger" onClick={logout} style={{ width: '100%' }}>
            {t('logout', { defaultValue: 'Logout' })}
          </button>
        </div>
      )}

      {/* ---- ADMIN TABS (system_admin only) ---- */}
      {tab === 'config' && (
        <Suspense fallback={<p style={{ color: 'var(--muted)' }}>Loading…</p>}>
          <ConfigPage />
        </Suspense>
      )}
      {tab === 'roles' && (
        <Suspense fallback={<p style={{ color: 'var(--muted)' }}>Loading…</p>}>
          <RolesPage />
        </Suspense>
      )}
      {tab === 'carrier' && (
        <Suspense fallback={<p style={{ color: 'var(--muted)' }}>Loading…</p>}>
          <CarrierPage />
        </Suspense>
      )}
      {tab === 'activity' && (
        <Suspense fallback={<p style={{ color: 'var(--muted)' }}>Loading…</p>}>
          <ActivityPage />
        </Suspense>
      )}
    </div>
  );
}
