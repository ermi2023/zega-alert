import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, API_BASE } from '../api/client';
import { io } from 'socket.io-client';
import LiveMap from '../components/LiveMap';

const timeAgo = (d) => {
  if (!d) return '—';
  const s = Math.floor((Date.now() - new Date(d)) / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return Math.floor(s/60) + 'm ago';
  if (s < 86400) return Math.floor(s/3600) + 'h ago';
  return Math.floor(s/86400) + 'd ago';
};

const badge = (v) => ({ triggered: 'red', acknowledged: 'amber', dispatched: 'blue', resolved: 'green', cancelled: 'gray', pending: 'amber', under_review: 'blue', verified: 'green', rejected: 'red', closed: 'gray' }[v] || 'gray');

const distanceMeters = (a, b) => {
  if (!a || !b) return null;
  const R = 6371000;
  const lat1 = (a.latitude * Math.PI) / 180;
  const lat2 = (b.latitude * Math.PI) / 180;
  const dLat = lat2 - lat1;
  const dLng = ((b.longitude - a.longitude) * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

const unitStatusStyle = (status) => ({
  completed: { background: '#d4edda', color: '#155724' },
  on_scene: { background: '#cce5ff', color: '#004085' },
  en_route: { background: '#fff3cd', color: '#856404' },
  assigned: { background: '#f8f9fa', color: '#495057' },
}[status] || { background: '#f8f9fa', color: '#495057' });

function useSosAlarm() {
  const permissionRef = useRef('default');

  useEffect(() => {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission().then((p) => { permissionRef.current = p; });
    } else if ('Notification' in window) {
      permissionRef.current = Notification.permission;
    }
  }, []);

  const playAlarm = (muted) => {
    if (muted) return;
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const gainNode = ctx.createGain();
      gainNode.gain.setValueAtTime(0.4, ctx.currentTime);
      gainNode.connect(ctx.destination);

      const osc = ctx.createOscillator();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(800, ctx.currentTime);
      // Sweep 800Hz ↔ 1200Hz repeatedly over 3 seconds
      for (let i = 0; i < 6; i++) {
        osc.frequency.linearRampToValueAtTime(1200, ctx.currentTime + i * 0.5 + 0.25);
        osc.frequency.linearRampToValueAtTime(800, ctx.currentTime + i * 0.5 + 0.5);
      }
      osc.connect(gainNode);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 3);

      // Flash the body red
      document.body.classList.add('sos-flash');
      setTimeout(() => document.body.classList.remove('sos-flash'), 2000);

      setTimeout(() => ctx.close(), 3200);
    } catch (e) {
      /* AudioContext not available */
    }
  };

  const showDesktopNotification = (title, body) => {
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(title, { body });
    }
  };

  return { playAlarm, showDesktopNotification };
}

export default function Sos() {
  const { t } = useTranslation();
  const [rows, setRows] = useState([]);
  const [filter, setFilter] = useState('');
  const [units, setUnits] = useState({});
  const [assignDialog, setAssignDialog] = useState(null);
  const [availableOfficers, setAvailableOfficers] = useState([]);
  const [assignmentError, setAssignmentError] = useState(null);
  const [officers, setOfficers] = useState({});
  const [muted, setMuted] = useState(false);
  const [regionFilter, setRegionFilter] = useState('');
  const [subCityFilter, setSubCityFilter] = useState('');
  const [connected, setConnected] = useState(true);
  const [page, setPage] = useState(1);
  const [liveStreams, setLiveStreams] = useState([]);
  const PER_PAGE = 20;
  const rowsRef = useRef([]);
  const mutedRef = useRef(muted);
  const livePeersRef = useRef(new Map());

  const { playAlarm, showDesktopNotification } = useSosAlarm();

  useEffect(() => { mutedRef.current = muted; }, [muted]);

  const load = () => api.get(`/sos${filter ? `?status=${filter}` : ''}`).then(setRows);
  useEffect(() => { load(); }, [filter]);

  useEffect(() => {
    let active = true;
    api.get('/sos/live/active')
      .then((offers) => {
        if (!active || !Array.isArray(offers)) return;
        setLiveStreams((current) => [
          ...current.filter((stream) => !offers.some((offer) => offer.streamId === stream.streamId)),
          ...offers,
        ]);
      })
      .catch((error) => console.error('Could not load active SOS live streams:', error));
    return () => { active = false; };
  }, []);

  useEffect(() => { rowsRef.current = rows; }, [rows]);

  const loadUnits = async (sosId) => {
    try {
      const data = await api.get(`/dispatch/${sosId}/units`);
      setUnits((prev) => ({ ...prev, [sosId]: data }));
    } catch { /* ignore */ }
  };

  useEffect(() => {
    const socket = io(API_BASE || undefined, {
      auth: { token: localStorage.getItem('zega_admin_token') },
    });
    socket.on('sos:new', (a) => {
      const alert = a.alert || a;
      setRows((p) => [alert, ...p.filter((x) => x.id !== alert.id)]);
      socket.emit('join', `sos:${alert.id}`);
      playAlarm(mutedRef.current);
      showDesktopNotification(
        '🚨 NEW SOS ALERT',
        'Citizen needs help — ' + (alert.address_text || alert.region || 'location pending')
      );
    });
    // Citizens stream their GPS every 12s while an SOS is active, so the pin moves.
    socket.on('sos:location', ({ sosId, latitude, longitude }) => {
      setRows((p) => p.map((s) => (s.id === sosId ? { ...s, latitude, longitude } : s)));
    });
    // Patrol units report their position continuously.
    socket.on('officer:position', (p) => {
      setOfficers((prev) => ({ ...prev, [p.userId]: p }));
    });
    socket.on('dispatch:updated', ({ sosId }) => loadUnits(sosId));
    socket.on('sos:live-offer', (offer) => {
      setLiveStreams((current) => [
        ...current.filter((stream) => stream.streamId !== offer.streamId),
        { ...offer, status: 'ringing' },
      ]);
    });
    socket.on('sos:live-state', (update) => {
      setLiveStreams((current) => current.map((stream) =>
        stream.streamId === update.streamId ? { ...stream, ...update } : stream
      ));
    });
    socket.on('sos:live-ice', ({ streamId, candidate }) => {
      const peer = livePeersRef.current.get(streamId);
      if (!peer || !candidate) return;
      if (peer.pc.remoteDescription) {
        peer.pc.addIceCandidate(new RTCIceCandidate(candidate))
          .catch((error) => {
            updateLiveStream(streamId, { status: 'error', error: error.message });
            endLiveStream({ sosId: peer.sosId, streamId });
          });
      } else {
        peer.pendingRemoteCandidates.push(candidate);
      }
    });
    socket.on('sos:live-ended', ({ streamId }) => {
      const peer = livePeersRef.current.get(streamId);
      peer?.pc.close();
      livePeersRef.current.delete(streamId);
      setLiveStreams((current) => current.filter((stream) => stream.streamId !== streamId));
    });
    socket.on('connect', () => {
      setConnected(true);
      // Join each active SOS room so dispatch:updated events (emitted to
      // `sos:<id>`) are received instead of only to the staff broadcast.
      rowsRef.current
        .filter((s) => ['triggered', 'acknowledged', 'dispatched'].includes(s.status))
        .forEach((s) => socket.emit('join', `sos:${s.id}`));
    });
    socket.on('disconnect', () => setConnected(false));
    return () => {
      socket.close();
      livePeersRef.current.forEach((peer, streamId) => {
        peer.ending = true;
        peer.pc.close();
        api.post(`/sos/${peer.sosId}/live/end`, { streamId })
          .catch((error) => console.error('Could not end SOS live stream:', error));
      });
      livePeersRef.current.clear();
    };
  }, []);

  const updateLiveStream = (streamId, changes) => {
    setLiveStreams((current) => current.map((stream) =>
      stream.streamId === streamId ? { ...stream, ...changes } : stream
    ));
  };

  const endLiveStream = async (stream) => {
    const peer = livePeersRef.current.get(stream.streamId);
    if (peer?.ending) return;
    if (peer) peer.ending = true;
    try {
      await api.post(`/sos/${stream.sosId}/live/end`, { streamId: stream.streamId });
    } catch (error) {
      if (peer) peer.ending = false;
      updateLiveStream(stream.streamId, { status: 'error', error: error.message });
      return;
    }
    peer?.pc.close();
    livePeersRef.current.delete(stream.streamId);
  };

  const acceptLiveStream = async (stream) => {
    updateLiveStream(stream.streamId, { status: 'connecting', error: null });
    const pc = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ],
    });
    const peer = {
      pc,
      sosId: stream.sosId,
      pendingRemoteCandidates: [],
      pendingLocalCandidates: [],
      answered: false,
    };
    livePeersRef.current.set(stream.streamId, peer);
    pc.ontrack = (event) => {
      if (event.streams[0]) {
        updateLiveStream(stream.streamId, { remoteStream: event.streams[0] });
      }
    };
    pc.onicecandidate = (event) => {
      if (!event.candidate) return;
      const candidate = event.candidate.toJSON();
      if (!peer.answered) {
        peer.pendingLocalCandidates.push(candidate);
        return;
      }
      api.post(`/sos/${stream.sosId}/live/ice`, {
        streamId: stream.streamId,
        candidate,
      }).catch((error) => {
        updateLiveStream(stream.streamId, { status: 'error', error: error.message });
        endLiveStream(stream);
      });
    };
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === 'failed' || pc.connectionState === 'disconnected') {
        updateLiveStream(stream.streamId, {
          status: 'error',
          error: 'The live media connection was interrupted.',
        });
        if (!peer.ending) endLiveStream(stream);
      }
    };
    try {
      await pc.setRemoteDescription(stream.offer);
      for (const candidate of peer.pendingRemoteCandidates) {
        await pc.addIceCandidate(new RTCIceCandidate(candidate));
      }
      peer.pendingRemoteCandidates = [];
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await api.post(`/sos/${stream.sosId}/live/answer`, {
        streamId: stream.streamId,
        answer: { type: answer.type, sdp: answer.sdp },
      });
      peer.answered = true;
      updateLiveStream(stream.streamId, { status: 'connected' });
      for (const candidate of peer.pendingLocalCandidates) {
        await api.post(`/sos/${stream.sosId}/live/ice`, {
          streamId: stream.streamId,
          candidate,
        });
      }
      peer.pendingLocalCandidates = [];
    } catch (error) {
      pc.close();
      livePeersRef.current.delete(stream.streamId);
      updateLiveStream(stream.streamId, { status: 'error', error: error.message });
      try {
        await api.post(`/sos/${stream.sosId}/live/end`, { streamId: stream.streamId });
      } catch {
        // The dashboard already shows the negotiation failure.
      }
    }
  };

  const rowIds = rows.map((s) => s.id).join(',');
  useEffect(() => {
    rowIds.split(',').filter(Boolean).forEach((id) => loadUnits(id));
  }, [rowIds]);

  useEffect(() => {
    api.get('/position/officers').then((list) => {
      const map = {};
      list.forEach((p) => { map[p.userId] = p; });
      setOfficers(map);
    }).catch(() => {});
  }, []);

  const openAssign = async (sosId) => {
    try {
      const officers = await api.get('/auth/staff?q=');
      const routeRecipientIds = rows.find((row) => row.id === sosId)?.route_recipient_ids || [];
      setAvailableOfficers(officers.filter((officer) =>
        routeRecipientIds.includes(officer.id) &&
        (officer.role === 'police' || officer.role === 'dispatcher')));
    } catch { setAvailableOfficers([]); }
    setAssignmentError(null);
    setAssignDialog(sosId);
  };

  const assignUnits = async (sosId, officerIds) => {
    try {
      await api.post(`/dispatch/${sosId}/assign`, { officer_ids: officerIds });
      loadUnits(sosId);
      setAssignDialog(null);
      setAssignmentError(null);
    } catch (error) {
      setAssignmentError(error.message);
    }
  };

  const removeUnit = async (sosId, assignmentId) => {
    await api.del(`/dispatch/${sosId}/${assignmentId}`);
    loadUnits(sosId);
  };

  const updateUnitStatus = async (sosId, assignmentId, status) => {
    await api.patch(`/dispatch/${sosId}/${assignmentId}/status`, { status });
    loadUnits(sosId);
  };

  const setStatus = async (id, status) => {
    await api.patch(`/sos/${id}/status`, { status });
    load();
  };

  const activeRows = rows.filter((s) => s.latitude && s.longitude && ['triggered', 'acknowledged', 'dispatched'].includes(s.status));
  const officerPts = Object.values(officers).filter((p) => p.latitude && p.longitude);

  const liveEta = (s, u) => {
    const pos = officers[u.assigned_to];
    const distance = pos && s.latitude != null && s.longitude != null ? distanceMeters(pos, s) : u.distance_m;
    if (distance == null) return { distance: null, eta: u.eta_seconds };
    return { distance, eta: Math.round(distance / 11.1) };
  };

  const filteredRows = rows.filter(s =>
    (!regionFilter || (s.region || '').toLowerCase().includes(regionFilter.toLowerCase())) &&
    (!subCityFilter || (s.sub_city || '').toLowerCase().includes(subCityFilter.toLowerCase()))
  );

  const totalPages = Math.max(1, Math.ceil(filteredRows.length / PER_PAGE));
  const safePage = Math.min(page, totalPages);
  const paged = filteredRows.slice((safePage - 1) * PER_PAGE, safePage * PER_PAGE);

  const exportCsv = () => {
    const headers = ['Time','User','Phone','Location','Region','Routed to','Status'];
    const csv = [headers, ...filteredRows.map(s => [
      s.created_at,
      s.user_name || '',
      s.user_phone || '',
      s.address_text || '',
      s.region || '',
      s.dispatch_route === 'nearest_station'
        ? s.station_name || 'Nearest station'
        : `Central dispatch${s.station_name ? ` (${s.station_name} unstaffed)` : ''}`,
      s.status,
    ])].map(r => r.map(c => `"${String(c||'').replace(/"/g,'""')}"`).join(',')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\uFEFF'+csv],{type:'text/csv'})); a.download = 'sos-alerts.csv'; a.click();
  };

  return (
    <div>
      <div className="page-head">
        <div><h1>{t('sos.title')}{!connected && <span style={{background:'#dc2626',color:'#fff',padding:'4px 12px',borderRadius:8,fontSize:12,fontWeight:700,marginLeft:12}}>⚠ DISCONNECTED — Reconnecting...</span>}</h1><p>{t('sos.subtitle')}</p></div>
        <div className="filters">
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="">{t('sos.allStatuses')}</option>
            {['triggered', 'acknowledged', 'dispatched', 'resolved', 'cancelled'].map((s) => <option key={s}>{s}</option>)}
          </select>
          <input placeholder="Region..." value={regionFilter} onChange={e => setRegionFilter(e.target.value)} style={{ marginLeft: 8, padding: '6px 10px', borderRadius: 6, border: '1px solid var(--line)', background: 'var(--panel)', color: 'var(--text)', fontSize: 13 }} />
          <input placeholder="Sub-city..." value={subCityFilter} onChange={e => setSubCityFilter(e.target.value)} style={{ marginLeft: 8, padding: '6px 10px', borderRadius: 6, border: '1px solid var(--line)', background: 'var(--panel)', color: 'var(--text)', fontSize: 13 }} />
          <button className="btn ghost" onClick={load}>{t('sos.refresh')}</button>
          <button className="btn ghost" onClick={() => setMuted(m => !m)}>{muted ? '🔇 Muted' : '🔊 Alarm On'}</button>
          <button className="btn ghost" onClick={exportCsv}>Export CSV</button>
        </div>
      </div>

      <div className="panel" style={{ marginBottom: 16, padding: 12 }}>
        <div className="section-head" style={{ marginBottom: 10 }}>
          <h2>Live SOS Tracking<small>Citizens &amp; responding units</small></h2>
          <span className="pill"><span className="dot red pulse" /> {activeRows.length} Active</span>
        </div>
        <LiveMap alerts={activeRows} officers={officerPts} height={360} />
      </div>

      {liveStreams.length > 0 && (
        <div className="panel" style={{ marginBottom: 16, padding: 12 }}>
          <div className="section-head" style={{ marginBottom: 10 }}>
            <h2>Live SOS audio/video<small>Citizen-started streams</small></h2>
          </div>
          {liveStreams.map((stream) => {
            const hasLocalPeer = livePeersRef.current.has(stream.streamId);
            return (
              <div key={stream.streamId} style={{ marginBottom: 10, padding: 10, border: '1px solid #fca5a5', borderRadius: 8, background: '#fff7f7' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                  <strong>Live {stream.mediaType} from {stream.callerName}</strong>
                  <span>SOS {stream.sosId.slice(0, 8)}</span>
                  <span>
                    {stream.status === 'ringing'
                      ? 'Waiting for dispatch to accept'
                      : stream.status === 'connected'
                        ? `Connected to ${stream.dispatcherName || 'dispatch'}`
                        : stream.status}
                  </span>
                  {stream.status === 'ringing' && (
                    <>
                      <button className="btn small" onClick={() => acceptLiveStream(stream)}>Accept live stream</button>
                      <button className="btn small danger" onClick={() => endLiveStream(stream)}>Decline</button>
                    </>
                  )}
                  {hasLocalPeer && ['connected', 'connecting', 'error'].includes(stream.status) && (
                    <button className="btn small danger" onClick={() => endLiveStream(stream)}>End stream</button>
                  )}
                  {stream.error && <span style={{ color: '#b91c1c' }}>{stream.error}</span>}
                </div>
                {stream.remoteStream && (
                  <video
                    autoPlay
                    playsInline
                    controls
                    ref={(element) => {
                      if (element && element.srcObject !== stream.remoteStream) {
                        element.srcObject = stream.remoteStream;
                      }
                    }}
                    style={{ display: 'block', width: 'min(100%, 480px)', maxHeight: 300, marginTop: 8, background: '#111', borderRadius: 6 }}
                  />
                )}
              </div>
            );
          })}
        </div>
      )}

      <div className="panel">
        <table>
          <thead><tr><th>{t('sos.time')}</th><th>{t('sos.user')}</th><th>{t('reports.location')}</th><th>{t('sos.region')}</th><th>Routed to</th><th>{t('sos.status')}</th><th>{t('sos.actions')}</th></tr></thead>
          <tbody>
            {paged.map((s) => (
              <tr key={s.id}>
                <td title={new Date(s.created_at).toLocaleString()}>{timeAgo(s.created_at)}</td>
                <td>{s.user_name || '—'}<br /><small>{s.user_phone}</small></td>
                <td>{s.address_text || `${s.latitude?.toFixed(4)}, ${s.longitude?.toFixed(4)}`}</td>
                <td>{s.region || '—'}</td>
                <td>{s.dispatch_route === 'nearest_station'
                  ? s.station_name || 'Nearest station'
                  : `Central dispatch${s.station_name ? ` (${s.station_name} unstaffed)` : ''}`}</td>
                <td><span className={`badge ${badge(s.status)}`}>{s.status}</span>
                  {s.geofence && s.latitude != null && s.longitude != null && (
                    s.geofence.inside_safety_zone ? (
                      <div className="msg ok" style={{ margin: '4px 0 0' }}>
                        Inside safety area: {(s.geofence.matching_zones || []).map((zone) => zone.name).join(', ')}
                      </div>
                    ) : (
                      <div className="msg err" style={{ margin: '4px 0 0' }}>Outside marked safety areas</div>
                    )
                  )}
                  {s.geofence?.nearest_police_station && (
                    <div className="msg ok" style={{ margin: '4px 0 0' }}>Police station {Math.round(s.geofence.nearest_police_station.dist)}m away</div>
                  )}
                </td>
                <td>
                  {s.status === 'triggered' && <button className="btn small" onClick={() => setStatus(s.id, 'acknowledged')}>{t('sos.acknowledge')}</button>}
                  {s.status === 'acknowledged' && <button className="btn small" onClick={() => setStatus(s.id, 'dispatched')}>{t('sos.dispatch')}</button>}
                  {['triggered', 'acknowledged', 'dispatched'].includes(s.status) && (
                    <>
                      <button className="btn small" style={{ marginLeft: 6 }} onClick={() => setStatus(s.id, 'resolved')}>{t('sos.resolve')}</button>
                      <button className="btn small danger" style={{ marginLeft: 6 }} onClick={() => setStatus(s.id, 'cancelled')}>{t('sos.cancel')}</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
            {paged.map((s) => (
              <tr key={`${s.id}-units`}>
                <td colSpan={7} style={{ padding: 0 }}>
                  <div style={{ padding: '8px 16px', background: '#f8f9fa', borderTop: '1px solid #eee' }}>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
                      <strong style={{ fontSize: 13 }}>{t('sos.assignedUnits')}</strong>
                      <button className="btn small" onClick={() => openAssign(s.id)}>{t('sos.assignUnit')}</button>
                      <button className="btn small ghost" onClick={() => loadUnits(s.id)}>{t('sos.refresh')}</button>
                    </div>
                    {units[s.id] && units[s.id].length > 0 ? (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                        {units[s.id].map((u) => (
                          <span key={u.id} style={{
                            display: 'inline-flex', alignItems: 'center', gap: 4,
                            padding: '4px 8px', borderRadius: 6,
                            ...unitStatusStyle(u.status),
                            fontSize: 12, border: '1px solid #ddd',
                          }}>
                            {u.officer_name} ({u.officer_role})
                            <span style={{ fontSize: 10, color: 'var(--muted)' }}>[{u.status}]</span>
                            {(() => {
                              const { distance, eta } = liveEta(s, u);
                              if (eta == null || u.status === 'completed' || u.status === 'on_scene') return null;
                              return (
                                <span style={{ fontSize: 10, color: '#856404' }}>
                                  ETA ~{Math.max(1, Math.round(eta / 60))}m{distance != null ? ` (${(distance / 1000).toFixed(1)}km)` : ''}
                                </span>
                              );
                            })()}
                            {u.status !== 'completed' && (
                              <select
                                value={u.status}
                                onChange={(e) => updateUnitStatus(s.id, u.id, e.target.value)}
                                style={{ fontSize: 10, padding: '1px 2px', marginLeft: 2 }}
                              >
                                {['assigned', 'en_route', 'on_scene', 'completed'].map((st) => (
                                  <option key={st} value={st}>{st}</option>
                                ))}
                              </select>
                            )}
                            <button onClick={() => removeUnit(s.id, u.id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'red', fontSize: 14 }}>&times;</button>
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span style={{ fontSize: 12, color: 'var(--muted)' }}>{t('sos.noUnits')}</span>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {filteredRows.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)' }}>{t('sos.noAlerts')}</td></tr>}
          </tbody>
        </table>
        {/* Pagination */}
        {totalPages > 1 && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, marginTop: 14 }}>
            <button className="btn small ghost" disabled={safePage <= 1} onClick={() => setPage(p => Math.max(1, p - 1))}>← Previous</button>
            <span style={{ fontSize: 13, color: 'var(--muted)' }}>Page {safePage} of {totalPages} ({filteredRows.length} total)</span>
            <button className="btn small ghost" disabled={safePage >= totalPages} onClick={() => setPage(p => Math.min(totalPages, p + 1))}>Next →</button>
          </div>
        )}
      </div>

      {assignDialog && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: 'white', borderRadius: 12, padding: 24, maxWidth: 400, width: '90%' }}>
            <h3>{t('sos.assignUnits')}</h3>
            {assignmentError && <p role="alert" style={{ color: '#b91c1c' }}>{assignmentError}</p>}
            <div style={{ maxHeight: 300, overflow: 'auto' }}>
              {availableOfficers.map((o) => (
                <label key={o.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderBottom: '1px solid #eee' }}>
                  <input type="checkbox" data-officer-id={o.id} />
                  <span>{o.full_name}</span>
                  <span style={{ fontSize: 11, color: 'var(--muted)' }}>{o.role}</span>
                </label>
              ))}
              {availableOfficers.length === 0 && <p style={{ color: 'var(--muted)' }}>{t('sos.noOfficers')}</p>}
            </div>
            <div style={{ marginTop: 16, display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setAssignDialog(null)}>{t('sos.cancel')}</button>
              <button className="btn" onClick={() => {
                const checkboxes = document.querySelectorAll('[data-officer-id]:checked');
                const ids = Array.from(checkboxes).map((cb) => cb.dataset.officerId);
                if (ids.length) assignUnits(assignDialog, ids);
              }}>{t('sos.assignSelected')}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
