import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../context/AuthContext';

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
      <form className="login-card" onSubmit={submit}>
        <h1>{t('brand')}</h1>
        <p>{t('login.subtitle')}</p>
        {err && <div className="msg err">{err}</div>}
        <label>{t('login.phone')}
          <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="09..." />
        </label>
        <label>{t('login.password')}
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <button className="btn" disabled={loading}>{loading ? t('login.signingIn') : t('login.signIn')}</button>
      </form>
    </div>
  );
}
