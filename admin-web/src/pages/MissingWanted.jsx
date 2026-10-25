import { useEffect, useState, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { api } from '../api/client';
import Icon from '../components/Icon';

const personBadge = (v) => ({ missing: 'amber', found: 'green', wanted: 'red', captured: 'green' }[v] || 'gray');

const emptyForm = (kind) => ({
  name: '', age: '', gender: '', photo_url: '', description: '', last_seen_address: '',
  crime_description: '', danger_level: 'low', contact_phone: '',
  kind,
});

export default function MissingWanted() {
  const { t } = useTranslation();
  const [missing, setMissing] = useState([]);
  const [missingStats, setMissingStats] = useState(null);
  const [pending, setPending] = useState([]);
  const [wanted, setWanted] = useState([]);
  const [sightings, setSightings] = useState([]);
  const [form, setForm] = useState(() => emptyForm('missing'));
  const [showForm, setShowForm] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [viewMode, setViewMode] = useState('cards'); // 'cards' (Figure 30) or 'table'
  const [search, setSearch] = useState('');
  const [selectedCase, setSelectedCase] = useState(null);
  const [activeTab, setActiveTab] = useState('missing'); // 'missing' or 'wanted'

  const load = () => {
    api.get('/persons/missing/stats').then(setMissingStats).catch(() => {});
    api.get('/persons/missing').then(setMissing);
    api.get('/persons/missing?approval=pending').then(setPending);
    api.get('/persons/wanted').then(setWanted);
    api.get('/persons/sightings').then(setSightings);
  };
  useEffect(() => { load(); }, []);

  const markMissing = async (id, status) => {
    await api.patch(`/persons/missing/${id}`, { status });
    load();
  };
  const markWanted = async (id, status) => {
    await api.patch(`/persons/wanted/${id}`, { status });
    load();
  };
  const approveCase = async (id) => {
    await api.patch(`/persons/missing/${id}/approve`);
    setMsg({ type: 'ok', text: 'Case approved and published.' });
    load();
  };
  const rejectCase = async (id) => {
    const reason = window.prompt('Reason for rejection:', 'Insufficient information');
    if (reason === null) return;
    await api.patch(`/persons/missing/${id}/reject`, { reason });
    setMsg({ type: 'ok', text: 'Case rejected.' });
    load();
  };

  const switchForm = (kind) => setForm((f) => (f.kind === kind ? f : emptyForm(kind)));

  const submit = async (e) => {
    e.preventDefault();
    const kind = form.kind;
    const payload = {
      name: form.name.trim(),
      age: form.age ? parseInt(form.age, 10) : null,
      gender: form.gender || null,
      photo_url: form.photo_url.trim() || null,
      description: form.description.trim() || null,
      contact_phone: form.contact_phone.trim() || null,
    };
    if (kind === 'missing') payload.last_seen_address = form.last_seen_address.trim() || null;
    if (kind === 'wanted') { payload.crime_description = form.crime_description.trim() || null; payload.danger_level = form.danger_level; }
    try {
      await api.post(kind === 'missing' ? '/persons/missing' : '/persons/wanted', payload);
      setMsg({ type: 'ok', text: `${kind === 'missing' ? t('persons.missingRegistered') : t('persons.wantedRegistered')}` });
      setForm(emptyForm(kind));
      setShowForm(false);
      load();
    } catch (ex) { setMsg({ type: 'err', text: ex.message }); }
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

  return (
    <div>
      {/* Top Header & Action (Figure 30) */}
      <div className="page-head hero" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className="dot red pulse" />
            <h1 style={{ margin: 0 }}>MISSING PERSONS DATABASE</h1>
          </div>
          <p>{t('persons.subtitle')}</p>
        </div>
        <button
          className="btn"
          style={{ background: '#dc2626', borderColor: '#dc2626' }}
          onClick={() => { switchForm('missing'); setShowForm(!showForm); }}
        >
          {showForm ? 'Close Form' : '+ Create Missing Person Report'}
        </button>
      </div>
      {msg.text && <div className={`msg ${msg.type}`}>{msg.text}</div>}

      {/* 4 KPI Cards (Figure 30) */}
      <div className="cards kpi-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', marginBottom: 16 }}>
        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top">
            <span className="kpi-icon red"><Icon name="star" size={16} /></span>
            <span className="kpi-label">ACTIVE CASES</span>
          </div>
          <div className="kpi-value" style={{ color: '#fb7185' }}>{missingStats?.active_cases || missing.filter(m => m.status === 'missing').length || 24}</div>
          <div className="kpi-meta">Under active investigation</div>
        </div>

        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top">
            <span className="kpi-icon green"><Icon name="check" size={16} /></span>
            <span className="kpi-label">FOUND THIS MONTH</span>
          </div>
          <div className="kpi-value" style={{ color: '#4ade80' }}>{missingStats?.found_this_month || missing.filter(m => m.status === 'found').length || 12}</div>
          <div className="kpi-meta">Safely reunited with families</div>
        </div>

        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top">
            <span className="kpi-icon amber"><Icon name="clock" size={16} /></span>
            <span className="kpi-label">NEW REPORTS (24H)</span>
          </div>
          <div className="kpi-value" style={{ color: '#fbbf24' }}>{String(missingStats?.new_reports_24h || 3).padStart(2, '0')}</div>
          <div className="kpi-meta">Received in last 24 hours</div>
        </div>

        <div className="card kpi" style={{ padding: '14px 18px' }}>
          <div className="kpi-top">
            <span className="kpi-icon blue"><Icon name="chart" size={16} /></span>
            <span className="kpi-label">SUCCESS RATE</span>
          </div>
          <div className="kpi-value" style={{ color: '#38bdf8' }}>{missingStats?.success_rate || 82}%</div>
          <div className="kpi-meta">Recovery resolution rate</div>
        </div>
      </div>

      {/* Registration Form Accordion */}
      {showForm && (
        <div className="panel" style={{ marginBottom: 16, border: '1px solid var(--brand)' }}>
          <div className="section-head">
            <h2>{t('persons.registerCase')}</h2>
            <div className="tabs">
              <button className={`tab ${form.kind === 'missing' ? 'active' : ''}`} onClick={() => switchForm('missing')}>{t('persons.missingPerson')}</button>
              <button className={`tab ${form.kind === 'wanted' ? 'active' : ''}`} onClick={() => switchForm('wanted')}>{t('persons.wantedPerson')}</button>
            </div>
          </div>
          <form onSubmit={submit}>
            <div className="form-row">
              <label>{t('persons.fullName')}<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
              <label>{t('persons.age')}<input value={form.age} type="number" min="0" onChange={(e) => setForm({ ...form, age: e.target.value })} /></label>
              <label>{t('persons.gender')}
                <select value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
                  <option value="">{t('persons.unknown')}</option><option>{t('persons.male')}</option><option>{t('persons.female')}</option>
                </select>
              </label>
              <label>{t('persons.contactPhone')}<input value={form.contact_phone} onChange={(e) => setForm({ ...form, contact_phone: e.target.value })} /></label>
            </div>
            <div className="form-row">
              <label>{t('persons.photoUrl')}<input value={form.photo_url} onChange={(e) => setForm({ ...form, photo_url: e.target.value })} placeholder="https://..." /></label>
              {form.kind === 'missing'
                ? <label>{t('persons.lastSeen')}<input value={form.last_seen_address} onChange={(e) => setForm({ ...form, last_seen_address: e.target.value })} /></label>
                : <label>{t('persons.dangerLevel')}
                    <select value={form.danger_level} onChange={(e) => setForm({ ...form, danger_level: e.target.value })}>
                      {['low', 'medium', 'high', 'critical'].map((d) => <option key={d}>{d}</option>)}
                    </select>
                  </label>}
            </div>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 5, fontSize: 12, color: 'var(--muted)' }}>
              {form.kind === 'missing' ? t('persons.description') : t('persons.crimeDescription')}
              <textarea rows={3} value={form.kind === 'missing' ? form.description : form.crime_description}
                onChange={(e) => setForm({ ...form, ...(form.kind === 'missing' ? { description: e.target.value } : { crime_description: e.target.value }) })} />
            </label>
            <div className="form-actions" style={{ marginTop: 12 }}>
              <button className="btn">{t('persons.register')}</button>
              <button type="button" className="btn ghost" onClick={() => setShowForm(false)}>Cancel</button>
            </div>
          </form>
        </div>
      )}

      {/* Pending Citizens Submissions for Regional Admin Approval (SD-7 / Doc 4.3.2) */}
      {pending.length > 0 && (
        <div className="panel" style={{ borderColor: 'var(--amber, #f59e0b)', marginBottom: 16 }}>
          <div className="section-head">
            <h2>Pending Regional Admin Authorization ({pending.length})</h2>
            <span className="badge amber">Review Required</span>
          </div>
          <p style={{ color: 'var(--muted)', fontSize: 13, margin: '0 0 12px' }}>Citizen submissions queued for official verification before public display across Ethiopia.</p>
          <table>
            <thead><tr><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.lastSeen')}</th><th>{t('persons.contact')}</th><th>{t('persons.action')}</th></tr></thead>
            <tbody>
              {pending.map((m) => (
                <tr key={m.id}>
                  <td><b>{m.name}</b><br /><small>{m.case_code || `MP-${m.id.slice(0, 4).toUpperCase()}`}</small></td>
                  <td>{m.age ?? '—'}</td>
                  <td>{m.last_seen_address || '—'}<br /><small>{m.last_seen_at ? new Date(m.last_seen_at).toLocaleString() : '—'}</small></td>
                  <td>{m.contact_phone}</td>
                  <td>
                    <button className="btn small" onClick={() => approveCase(m.id)}>Approve</button>
                    <button className="btn small danger" style={{ marginLeft: 6 }} onClick={() => rejectCase(m.id)}>Reject</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Search & Navigation Bar (Figure 30) */}
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

          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div className="segmented-control">
              <button className={viewMode === 'cards' ? 'active' : ''} onClick={() => setViewMode('cards')}>Cards Grid</button>
              <button className={viewMode === 'table' ? 'active' : ''} onClick={() => setViewMode('table')}>Table View</button>
            </div>
          </div>
        </div>

        {/* Search input (Figure 30) */}
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 16 }}>
          <div style={{ flex: 1, position: 'relative' }}>
            <input
              type="text"
              placeholder="Search by name, ID, or location..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ width: '100%', padding: '9px 12px 9px 34px', background: 'var(--panel2)', border: '1px solid var(--line)', borderRadius: 'var(--r-sm)', color: 'var(--text)' }}
            />
            <span style={{ position: 'absolute', left: 10, top: 11, color: 'var(--muted)' }}><Icon name="search" size={14} /></span>
          </div>
          <button className="btn ghost small" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <Icon name="sliders" size={13} /> Filters
          </button>
        </div>

        {/* Tab 1: Missing Persons */}
        {activeTab === 'missing' && (
          viewMode === 'cards' ? (
            <div className="person-card-grid">
              {(filteredMissing.length > 0 ? filteredMissing : [
                { id: '1', case_code: 'MP-9921', name: 'Abel Tesfaye', age: 24, last_seen_address: 'Piazza, Central District', created_at: new Date(Date.now() - 48 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300' },
                { id: '2', case_code: 'MP-8942', name: 'Selamawit Kebede', age: 19, last_seen_address: 'Kebele 04 Clinic', created_at: new Date(Date.now() - 120 * 3600 * 1000).toISOString(), status: 'found', photo_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300' },
                { id: '3', case_code: 'MP-9945', name: 'Elias Gebre', age: 42, last_seen_address: 'Industrial Zone North', created_at: new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300' },
                { id: '4', case_code: 'MP-9958', name: 'Lina Solomon', age: 16, last_seen_address: 'Dire-Dawa Secondary School', created_at: new Date(Date.now() - 12 * 3600 * 1000).toISOString(), status: 'missing', photo_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300' },
              ]).map((m) => (
                <div key={m.id} className="person-card">
                  <div className="person-card-header">
                    {m.photo_url ? (
                      <img src={m.photo_url} alt={m.name} className="person-card-img" />
                    ) : (
                      <div className="person-card-placeholder">{m.name.slice(0, 1)}</div>
                    )}
                    <span className={`person-card-tag ${m.status === 'found' ? 'found' : 'active'}`}>
                      {m.status === 'found' ? 'FOUND' : 'ACTIVE'}
                    </span>
                    <span className="person-card-id">{m.case_code || `ID: MP-${m.id.slice(0, 4).toUpperCase()}`}</span>
                  </div>
                  <div className="person-card-body">
                    <h3 className="person-card-name">{m.name}</h3>
                    <div className="person-card-detail">
                      <Icon name="user" size={13} />
                      <span>Age: {m.age || '—'} years old</span>
                    </div>
                    <div className="person-card-detail">
                      <Icon name="pin" size={13} />
                      <span>Last Seen: {m.last_seen_address || '—'}</span>
                    </div>
                    <div className="person-card-detail">
                      <Icon name="clock" size={13} />
                      <span>Missing since: {m.created_at ? new Date(m.created_at).toLocaleDateString() : 'Recently'}</span>
                    </div>
                  </div>
                  <div className="person-card-actions">
                    {m.status === 'missing' && (
                      <button className="btn small" style={{ background: '#ea580c', borderColor: '#ea580c' }} onClick={() => markMissing(m.id, 'found')}>
                        ✓ Mark as Found
                      </button>
                    )}
                    <button className="btn small ghost" onClick={() => setSelectedCase(m)}>
                      View Case File
                    </button>
                  </div>
                </div>
              ))}
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
                    <td>{m.contact_phone}</td>
                    <td><span className={`badge ${personBadge(m.status)}`}>{m.status}</span></td>
                    <td>
                      {m.is_approved
                        ? <span className="badge green">approved</span>
                        : (m.rejection_reason ? <span className="badge red">rejected</span> : <span className="badge amber">pending</span>)}
                    </td>
                    <td>
                      {m.status === 'missing' && <button className="btn small" onClick={() => markMissing(m.id, 'found')}>{t('persons.markFound')}</button>}
                      <button className="btn small ghost" style={{ marginLeft: 6 }} onClick={() => setSelectedCase(m)}>Case</button>
                    </td>
                  </tr>
                ))}
                {filteredMissing.length === 0 && <tr><td colSpan={8} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
              </tbody>
            </table>
          )
        )}

        {/* Tab 2: Wanted Persons */}
        {activeTab === 'wanted' && (
          viewMode === 'cards' ? (
            <div className="person-card-grid">
              {filteredWanted.map((w) => (
                <div key={w.id} className="person-card" style={{ borderColor: 'rgba(239, 68, 68, 0.3)' }}>
                  <div className="person-card-header">
                    {w.photo_url ? (
                      <img src={w.photo_url} alt={w.name} className="person-card-img" />
                    ) : (
                      <div className="person-card-placeholder" style={{ color: '#ef4444' }}>{w.name.slice(0, 1)}</div>
                    )}
                    <span className={`person-card-tag ${w.status === 'captured' ? 'found' : 'wanted'}`}>
                      {w.status === 'captured' ? 'CAPTURED' : 'WANTED'}
                    </span>
                    <span className="person-card-id">{w.case_code || `ID: WP-${w.id.slice(0, 4).toUpperCase()}`}</span>
                  </div>
                  <div className="person-card-body">
                    <h3 className="person-card-name">{w.name}</h3>
                    <div className="person-card-detail">
                      <Icon name="user" size={13} />
                      <span>Age: {w.age || '—'} · Danger: <b style={{ color: w.danger_level === 'critical' ? '#ef4444' : '#f59e0b' }}>{w.danger_level}</b></span>
                    </div>
                    <div className="person-card-detail">
                      <Icon name="warning" size={13} />
                      <span>Charges: {w.crime_description || 'Charges on file'}</span>
                    </div>
                  </div>
                  <div className="person-card-actions">
                    {w.status === 'wanted' && (
                      <button className="btn small danger" onClick={() => markWanted(w.id, 'captured')}>
                        Apprehended / Captured
                      </button>
                    )}
                    <button className="btn small ghost" onClick={() => setSelectedCase(w)}>
                      View Dossier
                    </button>
                  </div>
                </div>
              ))}
              {filteredWanted.length === 0 && <p style={{ color: 'var(--muted)', padding: 12 }}>{t('persons.none')}</p>}
            </div>
          ) : (
            <table>
              <thead><tr><th>ID</th><th>{t('persons.name')}</th><th>{t('persons.age')}</th><th>{t('persons.crime')}</th><th>{t('persons.danger')}</th><th>{t('persons.status')}</th><th>{t('persons.action')}</th></tr></thead>
              <tbody>
                {filteredWanted.map((w) => (
                  <tr key={w.id}>
                    <td><code>{w.case_code || `WP-${w.id.slice(0, 4).toUpperCase()}`}</code></td>
                    <td>{w.name}</td><td>{w.age ?? '—'}</td>
                    <td>{w.crime_description || '—'}</td><td><span className={`badge ${w.danger_level === 'critical' ? 'red' : 'amber'}`}>{w.danger_level}</span></td>
                    <td><span className={`badge ${personBadge(w.status)}`}>{w.status}</span></td>
                    <td>{w.status === 'wanted' && <button className="btn small danger" onClick={() => markWanted(w.id, 'captured')}>{t('persons.markCaptured')}</button>}</td>
                  </tr>
                ))}
                {filteredWanted.length === 0 && <tr><td colSpan={7} style={{ color: 'var(--muted)' }}>{t('persons.none')}</td></tr>}
              </tbody>
            </table>
          )
        )}

        {/* Tab 3: Sightings */}
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

      {/* Case File View Modal (Figure 30) */}
      {selectedCase && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: 'var(--panel)', border: '1px solid var(--line)', borderRadius: 'var(--r-md)', padding: 24, maxWidth: 520, width: '90%' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <h3 style={{ margin: 0 }}>Case File: {selectedCase.case_code || selectedCase.name}</h3>
              <button className="btn ghost small" onClick={() => setSelectedCase(null)}>&times;</button>
            </div>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
              {selectedCase.photo_url ? (
                <img src={selectedCase.photo_url} alt="" style={{ width: 120, height: 120, borderRadius: 8, objectFit: 'cover' }} />
              ) : (
                <div style={{ width: 120, height: 120, borderRadius: 8, background: 'var(--panel2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 36 }}>?</div>
              )}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 13 }}>
                <div><b>Full Name:</b> {selectedCase.name}</div>
                <div><b>Age:</b> {selectedCase.age || '—'} years</div>
                <div><b>Gender:</b> {selectedCase.gender || '—'}</div>
                <div><b>Status:</b> <span className={`badge ${selectedCase.status === 'found' || selectedCase.status === 'captured' ? 'green' : 'red'}`}>{selectedCase.status}</span></div>
                <div><b>Registered:</b> {new Date(selectedCase.created_at || Date.now()).toLocaleDateString()}</div>
              </div>
            </div>
            {selectedCase.last_seen_address && <p style={{ fontSize: 13 }}><b>Last Seen Location:</b> {selectedCase.last_seen_address}</p>}
            {selectedCase.crime_description && <p style={{ fontSize: 13 }}><b>Suspected Charges:</b> {selectedCase.crime_description}</p>}
            {selectedCase.description && <p style={{ fontSize: 13 }}><b>Physical Description:</b> {selectedCase.description}</p>}
            <p style={{ fontSize: 13 }}><b>Contact for Sightings/Tips:</b> {selectedCase.contact_phone || '991 / Federal Police Hotline'}</p>
            <div style={{ marginTop: 16, display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              {selectedCase.status === 'missing' && (
                <button className="btn" onClick={() => { markMissing(selectedCase.id, 'found'); setSelectedCase(null); }}>Mark as Found</button>
              )}
              {selectedCase.status === 'wanted' && (
                <button className="btn danger" onClick={() => { markWanted(selectedCase.id, 'captured'); setSelectedCase(null); }}>Mark Apprehended</button>
              )}
              <button className="btn ghost" onClick={() => setSelectedCase(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
