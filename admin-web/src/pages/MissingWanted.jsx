import { useEffect, useState, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { api, API_BASE, assetUrl } from '../api/client';
import { useAuth } from '../context/AuthContext';
import Icon from '../components/Icon';

const personBadge = (v) => ({ missing: 'amber', found: 'green', wanted: 'red', captured: 'green' }[v] || 'gray');

const emptyForm = (kind) => ({
  id: null,
  name: '', age: '', gender: '', photo_url: '', photos: [], description: '', last_seen_address: '',
  crime_description: '', danger_level: 'low', contact_phone: '',
  kind,
});

// Single combined edit + create dialog. When `editing` is non-null we PATCH,
// otherwise we POST a new record.
function PersonFormDialog({ open, initial, onClose, onSaved }) {
  const { t } = useTranslation();
  const [form, setForm] = useState(() => initial || emptyForm('missing'));
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [err, setErr] = useState('');
  const isEdit = Boolean(form.id);

  useEffect(() => {
    setForm(initial ? { ...initial } : emptyForm('missing'));
    setErr('');
  }, [initial, open]);

  if (!open) return null;

  const set = (patch) => setForm((f) => ({ ...f, ...patch }));

  const uploadFiles = async (files) => {
    if (!files.length) return;
    setUploading(true);
    try {
      const token = localStorage.getItem('zega_admin_token');
      const baseUrl = API_BASE || (window.location.hostname === 'localhost' ? 'http://localhost:5000' : '');
      const newUrls = [];
      for (const file of files) {
        const fd = new FormData();
        fd.append('file', file);
        const res = await fetch(`${baseUrl}/api/upload/single`, {
          method: 'POST',
          headers: token ? { Authorization: `Bearer ${token}` } : {},
          body: fd,
        });
        const data = await res.json();
        const url = data?.data?.url;
        if (url) newUrls.push(assetUrl(url));
      }
      if (newUrls.length > 0) {
        set((f) => {
          const updated = [...(f.photos || []), ...newUrls];
          return { photos: updated, photo_url: updated[0] || '' };
        });
      }
    } catch (e) { setErr('Upload failed: ' + e.message); }
    finally { setUploading(false); }
  };

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true); setErr('');
    const kind = form.kind;
    const allPhotos = Array.isArray(form.photos) && form.photos.length > 0
      ? form.photos
      : (form.photo_url?.trim() ? [form.photo_url.trim()] : []);
    const payload = {
      name: form.name.trim(),
      age: form.age ? parseInt(form.age, 10) : null,
      gender: form.gender || null,
      photo_url: allPhotos[0] || null,
      photos: allPhotos,
      contact_phone: form.contact_phone.trim() || null,
    };
    if (kind === 'missing') payload.last_seen_address = form.last_seen_address.trim() || null;
    if (kind === 'missing') payload.description = form.description.trim() || null;
    if (kind === 'wanted') {
      payload.crime_description = form.crime_description.trim() || null;
      payload.danger_level = form.danger_level;
    }
    try {
      if (isEdit) {
        await api.patch(`/persons/${kind === 'missing' ? 'missing' : 'wanted'}/${form.id}`, payload);
      } else {
        await api.post(`/persons/${kind === 'missing' ? 'missing' : 'wanted'}`, payload);
      }
      onSaved(isEdit ? t('persons.caseUpdated') : (kind === 'missing'
        ? 'Missing person saved as a draft. Click "Publish to app" to make it visible.'
        : t('persons.wantedRegistered')));
      onClose();
    } catch (ex) { setErr(ex.message); }
    finally { setSaving(false); }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1100, padding: 16 }}>
      <div style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: 20, maxWidth: 560, width: '100%', maxHeight: '92vh', overflowY: 'auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <h3 style={{ margin: 0 }}>
            {isEdit
              ? (form.kind === 'missing' ? t('persons.editMissing') : t('persons.editWanted'))
              : t('persons.registerCase')}
          </h3>
          <button className="btn ghost small" onClick={onClose} aria-label={t('persons.cancel')}>&times;</button>
        </div>
        <div className="tabs" style={{ marginBottom: 12 }}>
          <button className={`tab ${form.kind === 'missing' ? 'active' : ''}`} disabled={isEdit} onClick={() => set({ kind: 'missing' })}>{t('persons.missingPerson')}</button>
          <button className={`tab ${form.kind === 'wanted' ? 'active' : ''}`} disabled={isEdit} onClick={() => set({ kind: 'wanted' })}>{t('persons.wantedPerson')}</button>
        </div>
        {err && <div className="msg err" style={{ marginBottom: 10 }}>{err}</div>}
        <form onSubmit={submit}>
          <div className="form-row">
            <label>{t('persons.fullName')}<input value={form.name} onChange={(e) => set({ name: e.target.value })} required /></label>
            <label>{t('persons.age')}<input value={form.age} type="number" min="0" onChange={(e) => set({ age: e.target.value })} /></label>
            <label>{t('persons.gender')}
              <select value={form.gender} onChange={(e) => set({ gender: e.target.value })}>
                <option value="">{t('persons.unknown')}</option><option>{t('persons.male')}</option><option>{t('persons.female')}</option>
              </select>
            </label>
            <label>{t('persons.contactPhone')}<input value={form.contact_phone} onChange={(e) => set({ contact_phone: e.target.value })} /></label>
          </div>
          <div className="form-row">
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', fontWeight: 600, marginBottom: 4, fontSize: 13 }}>{t('persons.photos')}</label>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <input type="file" accept="image/*" multiple style={{ fontSize: 12, flex: 1 }} disabled={uploading}
                  onChange={(e) => uploadFiles(Array.from(e.target.files || []))} />
                {uploading && <span style={{ fontSize: 12, color: 'var(--muted)' }}>Uploading...</span>}
              </div>
              {form.photos && form.photos.length > 0 && (
                <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                  {form.photos.map((pUrl, idx) => (
                    <div key={idx} style={{ position: 'relative', display: 'inline-block' }}>
                      <img src={assetUrl(pUrl)} alt={`Uploaded ${idx + 1}`} style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 6, border: '1px solid var(--line)' }} />
                      <button type="button" title="Remove photo"
                        onClick={() => set((f) => { const updated = f.photos.filter((_, i) => i !== idx); return { photos: updated, photo_url: updated[0] || '' }; })}
                        style={{ position: 'absolute', top: -4, right: -4, background: '#ef4444', color: '#fff', border: 'none', borderRadius: '50%', width: 18, height: 18, fontSize: 11, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>×</button>
                    </div>
                  ))}
                </div>
              )}
              <input type="text" value={form.photo_url || ''} placeholder={t('persons.photoHint')}
                onChange={(e) => { const val = e.target.value; set((f) => ({ photo_url: val, photos: val ? (f.photos?.length ? [val, ...f.photos.slice(1)] : [val]) : (f.photos || []) })); }}
                style={{ marginTop: 6, width: '100%', fontSize: 12 }} />
            </div>
            {form.kind === 'missing'
              ? <label>{t('persons.lastSeen')}<input value={form.last_seen_address} onChange={(e) => set({ last_seen_address: e.target.value })} /></label>
              : <label>{t('persons.dangerLevel')}
                  <select value={form.danger_level} onChange={(e) => set({ danger_level: e.target.value })}>
                    <option value="low">{t('persons.low')}</option>
                    <option value="medium">{t('persons.medium')}</option>
                    <option value="high">{t('persons.high')}</option>
                    <option value="critical">{t('persons.critical')}</option>
                  </select>
                </label>}
          </div>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>
            {form.kind === 'missing' ? t('persons.description') : t('persons.crimeDescription')}
            <textarea rows={3} value={form.kind === 'missing' ? form.description : form.crime_description}
              onChange={(e) => set(form.kind === 'missing' ? { description: e.target.value } : { crime_description: e.target.value })} />
          </label>
          <div className="form-actions" style={{ marginTop: 12 }}>
            <button className="btn" disabled={saving}>{saving ? '…' : (isEdit ? t('persons.save') : t('persons.register'))}</button>
            <button type="button" className="btn ghost" onClick={onClose}>{t('persons.cancel')}</button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function MissingWanted() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const canPublish = ['regional_admin', 'system_admin'].includes(user?.role);
  const canDelete = canPublish; // same role set for delete actions
  const [missing, setMissing] = useState([]);
  const [missingStats, setMissingStats] = useState(null);
  const [missingPending, setMissingPending] = useState([]);
  const [wanted, setWanted] = useState([]);
  const [wantedPending, setWantedPending] = useState([]);
  const [sightings, setSightings] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null); // {kind, ...row}
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [viewMode, setViewMode] = useState('cards');
  const [search, setSearch] = useState('');
  const [selectedCase, setSelectedCase] = useState(null);
  const [activeTab, setActiveTab] = useState('missing');
  // Collapsible "Unpublished cases" panel + sub-tabs to switch between
  // missing / wanted drafts so admins don't have to scroll past them to
  // reach the main tabs below.
  const [draftsExpanded, setDraftsExpanded] = useState(true);
  const [draftsTab, setDraftsTab] = useState('all'); // 'all' | 'missing' | 'wanted'

  const load = () => {
    api.get('/persons/missing/stats').then(setMissingStats).catch(() => {});
    api.get('/persons/missing').then(setMissing).catch(() => {});
    api.get('/persons/missing?approval=pending').then(setMissingPending).catch(() => {});
    api.get('/persons/wanted').then(setWanted).catch(() => {});
    api.get('/persons/wanted?approval=pending').then(setWantedPending).catch(() => {});
    api.get('/persons/sightings').then(setSightings).catch(() => {});
  };
  useEffect(() => { load(); }, []);

  const flash = (type, text) => { setMsg({ type, text }); window.scrollTo({ top: 0, behavior: 'smooth' }); };

  const patchStatus = async (kind, id, status) => {
    try {
      await api.patch(`/persons/${kind}/${id}`, { status });
      flash('ok', t('persons.caseUpdated'));
      load();
    } catch (ex) { flash('err', ex.message); }
  };
  const publish = async (kind, id) => {
    try {
      await api.patch(`/persons/${kind}/${id}/publish`);
      flash('ok', t('persons.casePublished'));
      load();
    } catch (ex) { flash('err', ex.message); }
  };
  const unpublish = async (kind, id) => {
    if (!window.confirm(t('persons.caseUnpublished'))) return;
    try {
      await api.patch(`/persons/${kind}/${id}/unpublish`);
      flash('ok', t('persons.caseUnpublished'));
      load();
    } catch (ex) { flash('err', ex.message); }
  };
  const reject = async (kind, id) => {
    const reason = window.prompt(t('persons.rejectPrompt'), 'Insufficient information');
    if (reason === null) return;
    try {
      await api.patch(`/persons/${kind}/${id}/reject`, { reason });
      flash('ok', t('persons.rejected'));
      load();
    } catch (ex) { flash('err', ex.message); }
  };

  const editCase = (kind, row) => {
    setEditing({ kind, ...row });
    setShowForm(false);
  };
  const newCase = (kind) => {
    setEditing(null);
    setShowForm(true);
  };

  const deleteCase = async (kind, id) => {
    if (!window.confirm(t('persons.confirmDelete'))) return;
    try {
      await api.del(`/persons/${kind}/${id}`);
      flash('ok', t('persons.caseDeleted'));
      if (selectedCase && selectedCase.id === id) setSelectedCase(null);
      load();
    } catch (ex) { flash('err', ex.message); }
  };

  const filteredMissing = useMemo(() => {
    if (!search.trim()) return missing;
    const q = search.toLowerCase();
    return missing.filter((m) =>
      (m.name && m.name.toLowerCase().includes(q)) ||
      (m.case_code && m.case_code.toLowerCase().includes(q)) ||
      (m.last_seen_address && m.last_seen_address.toLowerCase().includes(q))
    );
  }, [missing, search]);

  const filteredWanted = useMemo(() => {
    if (!search.trim()) return wanted;
    const q = search.toLowerCase();
    return wanted.filter((w) =>
      (w.name && w.name.toLowerCase().includes(q)) ||
      (w.case_code && w.case_code.toLowerCase().includes(q)) ||
      (w.crime_description && w.crime_description.toLowerCase().includes(q))
    );
  }, [wanted, search]);

  const allPending = [...missingPending, ...wantedPending.map(w => ({ ...w, _kind: 'wanted' }))];

  // Reusable action buttons row used in both card and modal layouts.
  const ActionButtons = ({ kind, row }) => (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      {canPublish && (row.is_approved
        ? <button className="btn small ghost" onClick={() => unpublish(kind, row.id)}>{t('persons.unpublish')}</button>
        : <button className="btn small" onClick={() => publish(kind, row.id)}>{t('persons.publish')}</button>)}
      {!row.is_approved && canPublish && <button className="btn small danger" onClick={() => reject(kind, row.id)}>{t('persons.reject')}</button>}
      {kind === 'missing' && row.status === 'missing' && (
        <button className="btn small" style={{ background: '#ea580c', borderColor: '#ea580c' }} onClick={() => patchStatus('missing', row.id, 'found')}>✓ {t('persons.markFound')}</button>
      )}
      {kind === 'wanted' && row.status === 'wanted' && (
        <button className="btn small danger" onClick={() => patchStatus('wanted', row.id, 'captured')}>{t('persons.markCaptured')}</button>
      )}
      {canPublish && <button className="btn small ghost" onClick={() => editCase(kind, row)}>✎ {t('persons.edit')}</button>}
      {canDelete && <button className="btn small danger" onClick={() => deleteCase(kind, row.id)}>🗑 {t('persons.delete')}</button>}
      <button className="btn small ghost" onClick={() => setSelectedCase({ ...row, _kind: kind })}>{t('persons.viewCase')}</button>
    </div>
  );

  return (
    <div>
      <div className="page-head hero" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className="dot red pulse" />
            <h1 style={{ margin: 0 }}>{t('nav.persons')}</h1>
          </div>
          <p>{t('persons.subtitle')}</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" style={{ background: '#dc2626', borderColor: '#dc2626' }} onClick={() => newCase('missing')}>+ {t('persons.missingPerson')}</button>
          <button className="btn" style={{ background: '#b45309', borderColor: '#b45309' }} onClick={() => newCase('wanted')}>+ {t('persons.wantedPerson')}</button>
        </div>
      </div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      {/* KPI cards (unchanged from original) */}
      <div className="cards kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', marginBottom: 16 }}>
        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top"><span className="kpi-icon red"><Icon name="star" size={16} /></span><span className="kpi-label">ACTIVE CASES</span></div>
          <div className="kpi-value" style={{ color: '#fb7185' }}>{missingStats?.active_cases || missing.filter(m => m.status === 'missing').length || 0}</div>
          <div className="kpi-meta">Under active investigation</div>
        </div>
        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top"><span className="kpi-icon green"><Icon name="check" size={16} /></span><span className="kpi-label">FOUND THIS MONTH</span></div>
          <div className="kpi-value" style={{ color: '#4ade80' }}>{missingStats?.found_this_month || missing.filter(m => m.status === 'found').length || 0}</div>
          <div className="kpi-meta">Safely reunited with families</div>
        </div>
        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top"><span className="kpi-icon amber"><Icon name="clock" size={16} /></span><span className="kpi-label">NEW REPORTS (24H)</span></div>
          <div className="kpi-value" style={{ color: '#fbbf24' }}>{String(missingStats?.new_reports_24h || 0).padStart(2, '0')}</div>
          <div className="kpi-meta">Received in last 24 hours</div>
        </div>
        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top"><span className="kpi-icon blue"><Icon name="chart" size={16} /></span><span className="kpi-label">SUCCESS RATE</span></div>
          <div className="kpi-value" style={{ color: '#38bdf8' }}>{missingStats?.success_rate || 0}%</div>
          <div className="kpi-meta">Recovery resolution rate</div>
        </div>
      </div>

      {/* Unpublished / draft cases — collapsible, with All / Missing / Wanted
          sub-tabs so admins can switch between draft kinds instead of
          scrolling past a long list to reach the main tabs below. */}
      {allPending.length > 0 && (
        <div className="panel" style={{ borderColor: 'var(--amber, #f59e0b)', marginBottom: 16 }}>
          <div
            className="section-head"
            style={{ cursor: 'pointer', userSelect: 'none' }}
            onClick={() => setDraftsExpanded((v) => !v)}
            title={draftsExpanded ? 'Collapse' : 'Expand'}
            role="button"
            aria-expanded={draftsExpanded}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              {/* Rotating chevron — pure text so no icon dependency. */}
              <span
                style={{
                  display: 'inline-block',
                  transition: 'transform 0.18s ease',
                  transform: draftsExpanded ? 'rotate(90deg)' : 'rotate(0deg)',
                  fontSize: 14,
                  color: 'var(--muted)',
                  lineHeight: 1,
                }}
                aria-hidden="true"
              >▶</span>
              <h2 style={{ margin: 0 }}>{t('persons.drafts')} ({allPending.length})</h2>
            </div>
            <span className="badge amber">Not visible in the app</span>
          </div>

          {draftsExpanded && (
            <>
              <p style={{ color: 'var(--muted)', fontSize: 13, margin: '0 0 12px' }}>{t('persons.draftsHint')}</p>

              {/* Sub-tabs: All / Missing / Wanted */}
              <div className="tabs" style={{ margin: '0 0 12px' }}>
                <button
                  className={`tab ${draftsTab === 'all' ? 'active' : ''}`}
                  onClick={() => setDraftsTab('all')}
                >All ({allPending.length})</button>
                <button
                  className={`tab ${draftsTab === 'missing' ? 'active' : ''}`}
                  onClick={() => setDraftsTab('missing')}
                >{t('persons.missingPersons')} ({missingPending.length})</button>
                <button
                  className={`tab ${draftsTab === 'wanted' ? 'active' : ''}`}
                  onClick={() => setDraftsTab('wanted')}
                >{t('persons.wantedPersons')} ({wantedPending.length})</button>
              </div>

              <table>
                <thead><tr><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>Type</th><th>{t('persons.lastSeen')}</th><th>{t('persons.contact')}</th><th>{t('persons.action')}</th></tr></thead>
                <tbody>
                  {allPending
                    .filter((m) => {
                      if (draftsTab === 'all') return true;
                      const kind = m._kind || 'missing';
                      return kind === draftsTab;
                    })
                    .map((m) => {
                      const kind = m._kind || 'missing';
                      return (
                        <tr key={kind + m.id}>
                          <td><b>{m.name}</b><br /><small>{m.case_code || `${kind === 'wanted' ? 'WP-' : 'MP-'}${m.id.slice(0, 4).toUpperCase()}`}</small></td>
                          <td>{m.age ?? '—'}</td>
                          <td><span className={`badge ${kind === 'wanted' ? 'red' : 'amber'}`}>{kind}</span></td>
                          <td>{kind === 'missing' ? (m.last_seen_address || '—') : (m.crime_description || '—')}</td>
                          <td>{m.contact_phone || '—'}</td>
                          <td><ActionButtons kind={kind} row={m} /></td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </>
          )}
        </div>
      )}

      {/* Main tabs + search */}
      <div className="panel">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 12 }}>
          <div className="tabs" style={{ margin: 0 }}>
            <button className={`tab ${activeTab === 'missing' ? 'active' : ''}`} onClick={() => setActiveTab('missing')}>
              {t('persons.missingPersons')} ({missing.length})
            </button>
            <button className={`tab ${activeTab === 'wanted' ? 'active' : ''}`} onClick={() => setActiveTab('wanted')}>
              {t('persons.wantedPersons')} ({wanted.length})
            </button>
            <button className={`tab ${activeTab === 'sightings' ? 'active' : ''}`} onClick={() => setActiveTab('sightings')}>
              {t('persons.latestSightings')} ({sightings.length})
            </button>
          </div>
          <div className="segmented-control">
            <button className={viewMode === 'cards' ? 'active' : ''} onClick={() => setViewMode('cards')}>Cards</button>
            <button className={viewMode === 'table' ? 'active' : ''} onClick={() => setViewMode('table')}>Table</button>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 16 }}>
          <div style={{ flex: 1, position: 'relative' }}>
            <input type="text" placeholder="Search by name, ID, or location..." value={search} onChange={(e) => setSearch(e.target.value)}
              style={{ width: '100%', padding: '9px 12px 9px 34px', background: 'var(--panel2)', border: '1px solid var(--line)', borderRadius: 'var(--r-sm)', color: 'var(--text)' }} />
            <span style={{ position: 'absolute', left: 10, top: 11, color: 'var(--muted)' }}><Icon name="search" size={14} /></span>
          </div>
        </div>

        {/* Missing tab */}
        {activeTab === 'missing' && (
          viewMode === 'cards' ? (
            <div className="person-card-grid">
              {filteredMissing.map((m) => (
                <div key={m.id} className="person-card" style={m.is_approved ? undefined : { borderColor: 'rgba(245, 158, 11, 0.45)' }}>
                  <div className="person-card-header">
                    {m.photo_url ? <img src={assetUrl(m.photo_url)} alt={m.name} className="person-card-img" /> : <div className="person-card-placeholder">{m.name.slice(0, 1)}</div>}
                    <span className={`person-card-tag ${m.status === 'found' ? 'found' : 'active'}`}>{m.status === 'found' ? 'FOUND' : 'ACTIVE'}</span>
                    <span className="person-card-id">{m.case_code || `MP-${m.id.slice(0, 4).toUpperCase()}`}</span>
                  </div>
                  <div className="person-card-body">
                    <h3 className="person-card-name">{m.name}</h3>
                    <div className="person-card-detail"><Icon name="user" size={13} /><span>Age: {m.age || '—'} years old</span></div>
                    <div className="person-card-detail"><Icon name="pin" size={13} /><span>Last Seen: {m.last_seen_address || '—'}</span></div>
                    <div className="person-card-detail"><Icon name="clock" size={13} /><span>Missing since: {m.created_at ? new Date(m.created_at).toLocaleDateString() : 'Recently'}</span></div>
                    <div className="person-card-detail">
                      <Icon name={m.is_approved ? 'check' : 'clock'} size={13} />
                      <span>{m.is_approved ? <span className="badge green">{t('persons.published')}</span> : <span className="badge amber">{t('persons.draft')}</span>}</span>
                    </div>
                  </div>
                  <div className="person-card-actions"><ActionButtons kind="missing" row={m} /></div>
                </div>
              ))}
              {filteredMissing.length === 0 && <p style={{ color: 'var(--muted)', padding: 12 }}>{t('persons.none')}</p>}
            </div>
          ) : (
            <table>
              <thead><tr><th>Case ID</th><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.lastSeen')}</th><th>{t('persons.contact')}</th><th>{t('persons.status')}</th><th>Approval</th><th>{t('persons.action')}</th></tr></thead>
              <tbody>
                {filteredMissing.map((m) => (
                  <tr key={m.id}>
                    <td><code>{m.case_code || `MP-${m.id.slice(0, 4).toUpperCase()}`}</code></td>
                    <td>{m.name}</td><td>{m.age ?? '—'}</td>
                    <td>{m.last_seen_address || '—'}<br /><small>{m.last_seen_at ? new Date(m.last_seen_at).toLocaleString() : '—'}</small></td>
                    <td>{m.contact_phone || '—'}</td>
                    <td><span className={`badge ${personBadge(m.status)}`}>{m.status}</span></td>
                    <td>{m.is_approved ? <span className="badge green">{t('persons.published')}</span> : (m.rejection_reason ? <span className="badge red">{t('persons.rejected')}</span> : <span className="badge amber">{t('persons.draft')}</span>)}</td>
                    <td><ActionButtons kind="missing" row={m} /></td>
                  </tr>
                ))}
                {filteredMissing.length === 0 && <tr><td colSpan={8} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
              </tbody>
            </table>
          )
        )}

        {/* Wanted tab */}
        {activeTab === 'wanted' && (
          viewMode === 'cards' ? (
            <div className="person-card-grid">
              {filteredWanted.map((w) => (
                <div key={w.id} className="person-card" style={{ borderColor: w.is_approved ? 'rgba(239, 68, 68, 0.3)' : 'rgba(245, 158, 11, 0.45)' }}>
                  <div className="person-card-header">
                    {w.photo_url ? <img src={assetUrl(w.photo_url)} alt={w.name} className="person-card-img" /> : <div className="person-card-placeholder" style={{ color: '#ef4444' }}>{w.name.slice(0, 1)}</div>}
                    <span className={`person-card-tag ${w.status === 'captured' ? 'found' : 'wanted'}`}>{w.status === 'captured' ? 'CAPTURED' : 'WANTED'}</span>
                    <span className="person-card-id">{w.case_code || `WP-${w.id.slice(0, 4).toUpperCase()}`}</span>
                  </div>
                  <div className="person-card-body">
                    <h3 className="person-card-name">{w.name}</h3>
                    <div className="person-card-detail"><Icon name="user" size={13} /><span>Age: {w.age || '—'} · {t('persons.danger')}: <b style={{ color: w.danger_level === 'critical' ? '#ef4444' : '#f59e0b' }}>{t('persons.' + (w.danger_level || 'low'))}</b></span></div>
                    <div className="person-card-detail"><Icon name="warning" size={13} /><span>Charges: {w.crime_description || '—'}</span></div>
                    <div className="person-card-detail">
                      <Icon name={w.is_approved ? 'check' : 'clock'} size={13} />
                      <span>{w.is_approved ? <span className="badge green">{t('persons.published')}</span> : <span className="badge amber">{t('persons.draft')}</span>}</span>
                    </div>
                  </div>
                  <div className="person-card-actions"><ActionButtons kind="wanted" row={w} /></div>
                </div>
              ))}
              {filteredWanted.length === 0 && <p style={{ color: 'var(--muted)', padding: 12 }}>{t('persons.none')}</p>}
            </div>
          ) : (
            <table>
              <thead><tr><th>ID</th><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.crime')}</th><th>{t('persons.danger')}</th><th>{t('persons.status')}</th><th>Approval</th><th>{t('persons.action')}</th></tr></thead>
              <tbody>
                {filteredWanted.map((w) => (
                  <tr key={w.id}>
                    <td><code>{w.case_code || `WP-${w.id.slice(0, 4).toUpperCase()}`}</code></td>
                    <td>{w.name}</td><td>{w.age ?? '—'}</td>
                    <td>{w.crime_description || '—'}</td>
                    <td><span className={`badge ${w.danger_level === 'critical' ? 'red' : 'amber'}`}>{t('persons.' + (w.danger_level || 'low'))}</span></td>
                    <td><span className={`badge ${personBadge(w.status)}`}>{w.status}</span></td>
                    <td>{w.is_approved ? <span className="badge green">{t('persons.published')}</span> : (w.rejection_reason ? <span className="badge red">{t('persons.rejected')}</span> : <span className="badge amber">{t('persons.draft')}</span>)}</td>
                    <td><ActionButtons kind="wanted" row={w} /></td>
                  </tr>
                ))}
                {filteredWanted.length === 0 && <tr><td colSpan={8} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
              </tbody>
            </table>
          )
        )}

        {/* Sightings tab */}
        {activeTab === 'sightings' && (
          <table>
            <thead><tr><th>{t('persons.seen')}</th><th>Location</th><th>Description</th></tr></thead>
            <tbody>
              {sightings.map((s) => (
                <tr key={s.id}>
                  <td>{new Date(s.seen_at).toLocaleString()}</td>
                  <td>{s.address_text || `${s.latitude?.toFixed(4)}, ${s.longitude?.toFixed(4)}`}</td>
                  <td>{s.description || '—'}</td>
                </tr>
              ))}
              {sightings.length === 0 && <tr><td colSpan={3} style={{ color: 'var(--muted)' }}>{t('persons.noSightings')}</td></tr>}
            </tbody>
          </table>
        )}
      </div>

      {/* Edit / create dialog */}
      <PersonFormDialog
        open={showForm || editing !== null}
        initial={editing || emptyForm('missing')}
        onClose={() => { setShowForm(false); setEditing(null); }}
        onSaved={(text) => { flash('ok', text); load(); }}
      />

      {/* Case File view modal */}
      {selectedCase && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 16 }}>
          <div style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: 24, maxWidth: 560, width: '100%', maxHeight: '92vh', overflowY: 'auto' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <h3 style={{ margin: 0 }}>{t('persons.viewCase')}: {selectedCase.case_code || selectedCase.name}</h3>
              <button className="btn ghost small" onClick={() => setSelectedCase(null)}>&times;</button>
            </div>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
              {selectedCase.photo_url ? (
                <img src={assetUrl(selectedCase.photo_url)} alt="" style={{ width: 120, height: 120, borderRadius: 8, objectFit: 'cover' }} />
              ) : (
                <div style={{ width: 120, height: 120, borderRadius: 8, background: 'var(--panel2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 36 }}>?</div>
              )}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 13 }}>
                <div><b>{t('persons.fullName')}:</b> {selectedCase.name}</div>
                <div><b>{t('persons.age')}:</b> {selectedCase.age || '—'}</div>
                <div><b>{t('persons.gender')}:</b> {selectedCase.gender || '—'}</div>
                <div><b>{t('persons.status')}:</b> <span className={`badge ${selectedCase.status === 'found' || selectedCase.status === 'captured' ? 'green' : 'red'}`}>{selectedCase.status}</span></div>
                <div><b>Mobile app:</b>{' '}
                  {selectedCase.is_approved
                    ? <span className="badge green">{t('persons.published')}</span>
                    : <span className="badge amber">{t('persons.draft')}</span>}
                </div>
                <div><b>Registered:</b> {new Date(selectedCase.created_at || Date.now()).toLocaleDateString()}</div>
              </div>
            </div>
            {selectedCase.last_seen_address && <p style={{ fontSize: 13 }}><b>{t('persons.lastSeen')}:</b> {selectedCase.last_seen_address}</p>}
            {selectedCase.crime_description && <p style={{ fontSize: 13 }}><b>{t('persons.crimeDescription')}:</b> {selectedCase.crime_description}</p>}
            {selectedCase.description && <p style={{ fontSize: 13 }}><b>{t('persons.description')}:</b> {selectedCase.description}</p>}
            <p style={{ fontSize: 13 }}><b>{t('persons.contactPhone')}:</b> {selectedCase.contact_phone || '991 / Federal Police Hotline'}</p>
            <div style={{ marginTop: 16, display: 'flex', justifyContent: 'flex-end', gap: 8, flexWrap: 'wrap' }}>
              <ActionButtons kind={selectedCase._kind || 'missing'} row={selectedCase} />
              <button className="btn ghost" onClick={() => setSelectedCase(null)}>{t('persons.cancel')}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
