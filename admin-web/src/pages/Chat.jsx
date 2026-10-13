import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, API_BASE, TOKEN_KEY } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { io } from 'socket.io-client';

export default function Chat() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [conversations, setConversations] = useState([]);
  const [active, setActive] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [wait, setWait] = useState(null);
  const [rating, setRating] = useState(0);
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef(null);

  const loadWait = () => api.get('/chat/wait-time').then(setWait).catch(() => {});

  useEffect(() => {
    api.get('/chat/conversations').then(setConversations);
    loadWait();
    const timer = setInterval(loadWait, 30000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!active) return;
    api.get(`/chat/conversations/${active}/messages`).then(setMessages);
    setRating(0);
  }, [active]);

  useEffect(() => {
    const socket = io(import.meta.env.VITE_API_URL || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('chat:message', (m) => {
      setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));
    });
    return () => socket.close();
  }, []);

  const send = async (e) => {
    e.preventDefault();
    if (!text.trim()) return;
    const msg = await api.post(`/chat/conversations/${active}/messages`, { body: text });
    setText('');
    setMessages((prev) => [...prev, msg]);
  };

  const attach = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !active) return;
    setUploading(true);
    try {
      const token = localStorage.getItem(TOKEN_KEY);
      const fd = new FormData();
      fd.append('file', file);
      const res = await fetch(`${API_BASE}/api/upload/single`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: fd,
      });
      const data = await res.json();
      const url = data?.data?.url;
      if (!url) throw new Error(data?.message || 'Upload failed');
      const isImage = file.type.startsWith('image/');
      const msg = await api.post(`/chat/conversations/${active}/messages`, {
        body: file.name,
        message_type: isImage ? 'image' : 'text',
        attachment_url: url,
      });
      setMessages((prev) => [...prev, msg]);
    } catch (ex) { alert(ex.message); }
    finally { setUploading(false); if (fileRef.current) fileRef.current.value = ''; }
  };

  const rate = async (value) => {
    setRating(value);
    try { await api.post(`/chat/conversations/${active}/rating`, { rating: value }); } catch { /* ignore */ }
  };

  const newChat = async () => {
    const phone = prompt(t('chat.otherUserPhone'));
    if (!phone) return;
    const users = await api.get('/admin/users?q=' + phone);
    const other = users.find((u) => u.phone === phone);
    if (!other) return alert(t('chat.userNotFound'));
    const conv = await api.post('/chat/conversations', { participant_ids: [other.id] });
    setConversations(await api.get('/chat/conversations'));
    setActive(conv.id);
  };

  return (
    <div>
      <div className="page-head">
        <div><h1>{t('chat.title')}</h1><p>{t('chat.subtitle')}</p></div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {wait && (
            <span className={`badge ${wait.estimated_wait_minutes > 10 ? 'red' : 'green'}`}>
              {wait.waiting} waiting · ETA ~{wait.estimated_wait_minutes}m
            </span>
          )}
          <button className="btn" onClick={newChat}>{t('chat.startChat')}</button>
        </div>
      </div>
      <div className="panel" style={{ display: 'grid', gridTemplateColumns: '220px 1fr', gap: 16 }}>
        <div style={{ borderRight: '1px solid var(--line)' }}>
          {conversations.map((c) => (
            <div key={c.id} onClick={() => setActive(c.id)}
              style={{ padding: '10px 12px', cursor: 'pointer', borderRadius: 8, background: active === c.id ? 'var(--panel2)' : 'transparent' }}>
              {c.title || `Conversation ${c.id.slice(0, 6)}`}
            </div>
          ))}
          {conversations.length === 0 && <p style={{ color: 'var(--muted)', fontSize: 13 }}>{t('chat.noConversations')}</p>}
        </div>
        <div>
          {active ? (
            <>
              <div className="chat-box">
                {messages.map((m) => (
                  <div key={m.id} className={`chat-msg ${m.sender_id === user.id ? 'mine' : 'other'}`}>
                    {m.message_type === 'image' && m.attachment_url
                      ? <a href={m.attachment_url} target="_blank" rel="noreferrer"><img src={m.attachment_url} alt="attachment" style={{ maxWidth: 180, borderRadius: 8, display: 'block' }} /></a>
                      : (m.attachment_url
                        ? <a href={m.attachment_url} target="_blank" rel="noreferrer">{m.body || 'attachment'}</a>
                        : m.body)}
                    <small>{m.sender_name} · {new Date(m.created_at).toLocaleTimeString()}</small>
                  </div>
                ))}
              </div>
              <form className="chat-input" onSubmit={send}>
                <input value={text} onChange={(e) => setText(e.target.value)} placeholder={t('chat.typeMessage')} />
                <input type="file" ref={fileRef} onChange={attach} style={{ display: 'none' }} />
                <button type="button" className="btn ghost" disabled={uploading} onClick={() => fileRef.current?.click()}>
                  {uploading ? '…' : '📎'}
                </button>
                <button className="btn">{t('chat.send')}</button>
              </form>
              <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ color: 'var(--muted)', fontSize: 12 }}>Rate this conversation:</span>
                {[1, 2, 3, 4, 5].map((n) => (
                  <button key={n} type="button" onClick={() => rate(n)}
                    style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 18, color: n <= rating ? '#f5a623' : 'var(--muted)' }}>★</button>
                ))}
              </div>
            </>
          ) : <p style={{ color: 'var(--muted)' }}>{t('chat.selectConversation')}</p>}
        </div>
      </div>
    </div>
  );
}
