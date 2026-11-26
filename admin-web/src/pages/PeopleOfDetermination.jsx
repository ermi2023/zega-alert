import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, API_BASE } from '../api/client';
import { useToast } from '../components/Toast';
import { useAuth } from '../context/AuthContext';
import { io } from 'socket.io-client';

const statusBadge = (s) => ({ requested: 'amber', acknowledged: 'blue', completed: 'green', cancelled: 'gray', submitted: 'amber' }[s] || 'gray');
const emptyStationForm = {
  name: '',
  address_text: '',
  phone: '',
  region: '',
  sub_city: '',
  latitude: '',
  longitude: '',
  is_active: true,
  staff_user_ids: [],
};

export default function PeopleOfDetermination() {
  const { t } = useTranslation();
  const { user } = useAuth();
  const [calls, setCalls] = useState([]);
  const [signs, setSigns] = useState([]);
  const [stations, setStations] = useState([]);
  const [officers, setOfficers] = useState([]);
  const [stationForm, setStationForm] = useState(emptyStationForm);
  const [editingStationId, setEditingStationId] = useState(null);
  const { addToast } = useToast();
  const canManageStations = ['system_admin', 'regional_admin'].includes(user?.role);

  const load = () => {
    api.get('/pod/direct-call').then(setCalls).catch(() => {});
    api.get('/pod/sign-language').then(setSigns).catch(() => {});
  };

  const loadStations = async () => {
    try {
      const [stationRows, officerRows] = await Promise.all([
        api.get('/pod/stations'),
        api.get('/pod/stations/staff'),
      ]);
      setStations(stationRows);
      setOfficers(officerRows);
    } catch (error) {
      addToast(`Could not load station registry: ${error.message}`, 'err');
    }
  };

  useEffect(() => {
    load();
    const socket = io(API_BASE || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('pod:direct_call', load);
    socket.on('pod:sign_language', load);
    return () => socket.close();
  }, []);

  useEffect(() => {
    if (canManageStations) loadStations();
  }, [canManageStations]);

  const editStation = (station) => {
    setEditingStationId(station.id);
    setStationForm({
      name: station.name || '',
      address_text: station.address_text || '',
      phone: station.phone || '',
      region: station.region || '',
      sub_city: station.sub_city || '',
      latitude: String(station.latitude ?? ''),
      longitude: String(station.longitude ?? ''),
      is_active: station.is_active !== false,
      staff_user_ids: station.staff_user_ids || [],
    });
  };

  const resetStationForm = () => {
    setEditingStationId(null);
    setStationForm({
      ...emptyStationForm,
      region: user?.role === 'regional_admin' ? user.region || '' : '',
    });
  };

  const saveStation = async (event) => {
    event.preventDefault();
    const body = {
      ...stationForm,
      latitude: Number(stationForm.latitude),
      longitude: Number(stationForm.longitude),
    };
    try {
      if (editingStationId) {
        await api.patch(`/pod/stations/${editingStationId}`, body);
        addToast('Police station updated.', 'ok');
      } else {
        await api.post('/pod/stations', body);
        addToast('Police station registered.', 'ok');
      }
      resetStationForm();
      await loadStations();
    } catch (error) {
      addToast(error.message, 'err');
    }
  };

  const toggleOfficer = (userId) => {
    setStationForm((current) => ({
      ...current,
      staff_user_ids: current.staff_user_ids.includes(userId)
        ? current.staff_user_ids.filter((id) => id !== userId)
        : [...current.staff_user_ids, userId],
    }));
  };

  const update = async (id, status) => {
    try {
      await api.patch(`/pod/direct-call/${id}`, { status });
      addToast(`Request ${status}.`, 'ok');
      load();
    } catch (ex) { addToast(ex.message, 'err'); }
  };

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>{t('pod.title', 'People of Determination')}</h1>
          <p>{t('pod.subtitle', 'Accessibility support: direct police calls & sign language video messages')}</p>
        </div>
        <button className="btn ghost" onClick={load}>{t('sos.refresh')}</button>
      </div>

      {canManageStations && (
        <div className="panel">
          <h2>Police station registry and routing</h2>
          <p style={{ color: 'var(--muted)' }}>
            Register each station’s street/local address and map coordinates, then assign its active police accounts. Citizen chats, reports, and SOS alerts route to the closest registered station; if no station or assigned officers are available, alerts go to central dispatch only.
          </p>
          <form onSubmit={saveStation}>
            <div className="form-row">
              <label>Station name<input required value={stationForm.name} onChange={(e) => setStationForm({ ...stationForm, name: e.target.value })} /></label>
              <label>Address<input required value={stationForm.address_text} onChange={(e) => setStationForm({ ...stationForm, address_text: e.target.value })} placeholder="Street, locality, city" /></label>
              <label>Station phone<input value={stationForm.phone} onChange={(e) => setStationForm({ ...stationForm, phone: e.target.value })} /></label>
              <label>Region<input required disabled={user?.role === 'regional_admin'} value={stationForm.region || (user?.role === 'regional_admin' ? user.region || '' : '')} onChange={(e) => setStationForm({ ...stationForm, region: e.target.value })} /></label>
              <label>Sub-city / locality<input value={stationForm.sub_city} onChange={(e) => setStationForm({ ...stationForm, sub_city: e.target.value })} /></label>
              <label>Latitude<input required type="number" step="any" min="-90" max="90" value={stationForm.latitude} onChange={(e) => setStationForm({ ...stationForm, latitude: e.target.value })} /></label>
              <label>Longitude<input required type="number" step="any" min="-180" max="180" value={stationForm.longitude} onChange={(e) => setStationForm({ ...stationForm, longitude: e.target.value })} /></label>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '12px 0' }}>
              <input type="checkbox" checked={stationForm.is_active} onChange={(e) => setStationForm({ ...stationForm, is_active: e.target.checked })} />
              Active for nearest-station routing
            </label>
            <strong>Assign station officers</strong>
            <div className="form-row" style={{ margin: '8px 0 16px' }}>
              {officers.map((officer) => (
                <label key={officer.id} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input type="checkbox" checked={stationForm.staff_user_ids.includes(officer.id)} onChange={() => toggleOfficer(officer.id)} />
                  {officer.full_name} · {officer.region || 'No region'}
                </label>
              ))}
              {officers.length === 0 && <span style={{ color: 'var(--muted)' }}>No active police accounts available.</span>}
            </div>
            <button className="btn">{editingStationId ? 'Save station' : 'Register station'}</button>
            {editingStationId && <button type="button" className="btn ghost" style={{ marginLeft: 8 }} onClick={resetStationForm}>Cancel edit</button>}
          </form>

          <table style={{ marginTop: 20 }}>
            <thead><tr><th>Station</th><th>Registered address</th><th>Coordinates</th><th>Assigned officers</th><th>Status</th><th>Action</th></tr></thead>
            <tbody>
              {stations.map((station) => (
                <tr key={station.id}>
                  <td>{station.name}</td>
                  <td>{station.address_text || 'Address required'}</td>
                  <td>{station.latitude ?? '—'}, {station.longitude ?? '—'}</td>
                  <td>{station.staff_user_ids?.length || 0}</td>
                  <td>{station.is_active ? 'Active' : 'Inactive'}</td>
                  <td><button className="btn small ghost" onClick={() => editStation(station)}>Edit</button></td>
                </tr>
              ))}
              {stations.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>No police stations registered.</td></tr>}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel">
        <h2>📞 {t('pod.directCalls', 'Direct call requests')}</h2>
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>Citizen</th><th>Phone</th><th>Nearest station</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {calls.map((c) => (
              <tr key={c.id}>
                <td>{new Date(c.created_at).toLocaleString()}</td>
                <td>{c.citizen_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{c.region || '—'}</div></td>
                <td>{c.citizen_phone || '—'}</td>
                <td>{c.station_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{c.station_phone || ''}</div></td>
                <td><span className={`badge ${statusBadge(c.status)}`}>{c.status}</span></td>
                <td>
                  {c.status === 'requested' && <>
                    <button className="btn small" onClick={() => update(c.id, 'acknowledged')}>Acknowledge</button>
                    <button className="btn small danger" style={{ marginLeft: 4 }} onClick={() => update(c.id, 'cancelled')}>Cancel</button>
                  </>}
                  {['requested', 'acknowledged'].includes(c.status) &&
                    <button className="btn small" style={{ marginLeft: 4 }} onClick={() => update(c.id, 'completed')}>Complete</button>}
                </td>
              </tr>
            ))}
            {calls.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('pod.noCalls', 'No direct call requests.')}</td></tr>}
          </tbody>
        </table>
      </div>

      <div className="panel">
        <h2>🤟 {t('pod.signLanguage', 'Sign language video messages')}</h2>
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>Citizen</th><th>Note</th><th>Video</th><th>Status</th></tr></thead>
          <tbody>
            {signs.map((s) => (
              <tr key={s.id}>
                <td>{new Date(s.created_at).toLocaleString()}</td>
                <td>{s.citizen_name || '—'}<div style={{ color: 'var(--muted)', fontSize: 12 }}>{s.region || '—'}</div></td>
                <td>{s.note || '—'}</td>
                <td><a className="btn small" href={s.video_url} target="_blank" rel="noreferrer">Open video</a></td>
                <td><span className={`badge ${statusBadge(s.status)}`}>{s.status}</span></td>
              </tr>
            ))}
            {signs.length === 0 && <tr><td colSpan={5} style={{ color: 'var(--muted)' }}>{t('pod.noSigns', 'No sign language messages.')}</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
