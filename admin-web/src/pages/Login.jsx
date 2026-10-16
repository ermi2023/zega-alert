import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';

function ShieldFlag() {
  return (
    <svg className="shield" viewBox="0 0 48 56" aria-hidden="true">
      <defs>
        <clipPath id="shieldClip">
          <path d="M24 2 L44 10 V28 C44 42 34 50 24 54 C14 50 4 42 4 28 V10 Z" />
        </clipPath>
      </defs>
      <image
        href="/brand/ethiopia-flag.png"
        x="0" y="0" width="48" height="56"
        preserveAspectRatio="xMidYMid slice"
        clipPath="url(#shieldClip)"
      />
      <path
        d="M24 2 L44 10 V28 C44 42 34 50 24 54 C14 50 4 42 4 28 V10 Z"
        fill="none" stroke="#22c55e" strokeWidth="2.5" strokeLinejoin="round"
      />
    </svg>
  );
}

export default function Login() {
  const { t } = useTranslation();
  const { login } = useAuth();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('0911000001');
  const [password, setPassword] = useState('password123');
  const [err, setErr] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setErr('');
    setLoading(true);
    try {
      const user = await login(phone, password);
      navigate(user.role === 'citizen' ? '/reports' : '/');
    } catch (ex) {
      setErr(ex.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-wrap">
      <div className="login-bg" />
      <div className="login-overlay" />
      <form className="login-card" onSubmit={submit}>
        <div className="login-brand">
          <ShieldFlag />
          <div>
            <h1>{t('brand')}</h1>
            <span className="tagline">Emergency &amp; crime reporting for every Ethiopian</span>
          </div>
        </div>
        <p className="login-subtitle">{t('login.subtitle')}</p>
        {err && <div className="msg err">{err}</div>}
        <label>{t('login.phone')}
          <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="09..." />
        </label>
        <label>{t('login.password')}
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <button className="btn" disabled={loading}>{loading ? t('login.signingIn') : t('login.signIn')}</button>
        <div className="flag-strip" aria-hidden="true">
          <span /><span /><span />
        </div>
      </form>
    </div>
  );
}
