import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';
import Icon from '../components/Icon';

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
        fill="none" stroke="rgba(255,255,255,.9)" strokeWidth="2.5" strokeLinejoin="round"
      />
    </svg>
  );
}

export default function Login() {
  const { t } = useTranslation();
  const { login } = useAuth();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
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
    <div className="auth">
      <section className="auth-hero">
        <div className="hero-glow" />
        <div className="hero-content">
          <div className="hero-brand">
            <ShieldFlag />
            <div className="hero-wordmark">
              <h1>ZEGA</h1>
              <span>ALERT</span>
            </div>
          </div>
          <p className="hero-tagline">Emergency &amp; crime reporting for every Ethiopian</p>

          <ul className="hero-features">
            <li><span className="fi"><Icon name="sos" size={16} /></span> Real-time SOS dispatch to police &amp; ambulances</li>
            <li><span className="fi"><Icon name="persons" size={16} /></span> Missing &amp; wanted persons with national ID match</li>
            <li><span className="fi"><Icon name="geofences" size={16} /></span> Safety zones, live map &amp; verified sightings</li>
          </ul>

          <div className="hero-langs">
            <span>አማርኛ</span><span>Afaan Oromoo</span><span>ትግርኛ</span><span>English</span>
          </div>

          <div className="hero-flag-band"><span /><span /><span /></div>
        </div>
        <div className="hero-pattern" />
      </section>

      <section className="auth-panel">
        <form className="auth-form" onSubmit={submit}>
          <div className="auth-form-head">
            <span className="auth-dot" />
            <h2>{t('login.signIn')}</h2>
            <p>{t('login.subtitle')}</p>
          </div>

          {err && <div className="msg err">{err}</div>}

          <label>{t('login.phone')}
            <div className="field"><Icon name="phone" size={16} />
              <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="09..." />
            </div>
          </label>

          <label>{t('login.password')}
            <div className="field"><Icon name="lock" size={16} />
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
          </label>

          <button className="btn btn-gradient" disabled={loading}>
            {loading ? t('login.signingIn') : t('login.signIn')}
            {!loading && <Icon name="arrow" size={16} />}
          </button>

          <div className="auth-foot">
            <span className="pill secure"><Icon name="shield" size={13} /> Secured login</span>
          </div>
        </form>
      </section>
    </div>
  );
}
