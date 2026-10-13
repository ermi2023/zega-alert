import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';

const Stars = ({ n }) => (
  <span style={{ color: '#f5a623', letterSpacing: 2 }}>
    {'★'.repeat(n)}{'☆'.repeat(5 - n)}
  </span>
);

export default function Feedback() {
  const { t } = useTranslation();
  const [items, setItems] = useState([]);
  const [summary, setSummary] = useState(null);
  const [msg, setMsg] = useState({ type: '', text: '' });

  const load = () => {
    api.get('/feedback/all').then(setItems).catch((e) => setMsg({ type: 'err', text: e.message }));
    api.get('/feedback/summary').then(setSummary).catch(() => {});
  };
  useEffect(() => { load(); }, []);

  const fmt = (iso) => {
    if (!iso) return '—';
    return new Date(iso).toLocaleString();
  };

  return (
    <div>
      <div className="page-head"><div><h1>{t('feedback.title')}</h1><p>{t('feedback.subtitle')}</p></div></div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      {summary && (
        <div className="panel">
          <h2>{t('feedback.overallSatisfaction')}</h2>
          <div style={{ display: 'flex', gap: 32, flexWrap: 'wrap' }}>
            <div>
              <div style={{ fontSize: 40, fontWeight: 700 }}>{Number(summary.avg_rating).toFixed(1)} / 5</div>
              <div style={{ color: '#888' }}>{summary.count} {t('feedback.ratings')}</div>
            </div>
            <div>
              {[5, 4, 3, 2, 1].map((s) => (
                <div key={s} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <span style={{ width: 24 }}>{s}★</span>
                  <div style={{ width: 140, height: 8, background: '#eee', borderRadius: 4, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: summary.count ? `${(summary[s] / summary.count) * 100}%` : '0%', background: '#f5a623' }} />
                  </div>
                  <small>{summary[s] || 0}</small>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <div className="panel">
        <h2>{t('feedback.recentFeedback')}</h2>
        <table>
          <thead>
            <tr><th>{t('feedback.rating')}</th><th>{t('feedback.report')}</th><th>{t('feedback.citizen')}</th><th>{t('feedback.comment')}</th><th>{t('feedback.date')}</th></tr>
          </thead>
          <tbody>
            {items.length === 0 && <tr><td colSpan="5" style={{ textAlign: 'center', color: '#888' }}>{t('feedback.noFeedback')}</td></tr>}
            {items.map((f) => (
              <tr key={f.id}>
                <td><Stars n={f.rating} /></td>
                <td>{f.report_title || f.report_id?.slice(0, 8) || '—'}</td>
                <td>{f.user_name || '—'}</td>
                <td>{f.comment || '—'}</td>
                <td>{fmt(f.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
