import { randomUUID } from 'node:crypto';
import { query } from '../config/db.js';
import { io } from '../socket/socket.js';
import { fail, ok } from '../utils/response.js';
import { isUuid } from '../utils/uuid.js';
import { getRouteRecipients } from '../services/police-station.service.js';
import { env } from '../config/env.js';
import { buildIceServers } from '../services/ice-config.service.js';

const streams = new Map();
const staffRoles = new Set(['police', 'dispatcher', 'regional_admin', 'system_admin']);

const findAlert = async (sosId, res) => {
  if (!isUuid(sosId)) {
    fail(res, 'Invalid SOS id', 400);
    return null;
  }
  const { rows } = await query(
    'SELECT id, user_id, status, station_id FROM sos_alerts WHERE id = $1',
    [sosId],
  );
  if (!rows[0]) {
    fail(res, 'SOS not found', 404);
    return null;
  }
  return rows[0];
};

const getStream = (sosId, streamId, res) => {
  const stream = streams.get(streamId);
  if (!stream || stream.sosId !== sosId) {
    fail(res, 'Live SOS stream not found', 404);
    return null;
  }
  return stream;
};

export const getSosLiveIceConfig = (_req, res) => {
  try {
    ok(res, { iceServers: buildIceServers(env) });
  } catch (error) {
    fail(res, error.message, 503);
  }
};

const removeStream = (stream, endedBy = null) => {
  streams.delete(stream.streamId);
  const event = { sosId: stream.sosId, streamId: stream.streamId, endedBy };
  io.to(`user:${stream.ownerId}`).emit('sos:live-ended', event);
  if (stream.dispatcherId) {
    io.to(`user:${stream.dispatcherId}`).emit('sos:live-ended', event);
  }
  for (const userId of stream.recipientIds) {
    io.to(`user:${userId}`).emit('sos:live-ended', event);
  }
};

export const endLiveStreamsForSos = (sosId) => {
  for (const stream of streams.values()) {
    if (stream.sosId === sosId) removeStream(stream);
  }
};

export const endLiveStreamsForUser = (userId) => {
  for (const stream of streams.values()) {
    if (stream.ownerId === userId || stream.dispatcherId === userId) {
      removeStream(stream);
    }
  }
};

export const createSosLiveOffer = async (req, res) => {
  const alert = await findAlert(req.params.id, res);
  if (!alert) return;
  if (alert.user_id !== req.user.id) return fail(res, 'Only the SOS owner can start a live stream', 403);
  if (['resolved', 'cancelled'].includes(alert.status)) {
    return fail(res, 'Cannot stream from a closed SOS alert', 409);
  }

  const { offer, mediaType } = req.body;
  if (
    typeof offer?.sdp !== 'string' ||
    offer.sdp.length > 100_000 ||
    offer.type !== 'offer'
  ) {
    return fail(res, 'A valid WebRTC offer is required');
  }
  if (!['audio', 'video'].includes(mediaType)) return fail(res, 'mediaType must be audio or video');
  if ([...streams.values()].some((stream) => stream.sosId === alert.id)) {
    return fail(res, 'A live stream is already active for this SOS', 409);
  }

  const streamId = randomUUID();
  const stream = {
    streamId,
    sosId: alert.id,
    ownerId: req.user.id,
    callerName: req.user.full_name || 'Citizen',
    offer,
    mediaType,
    dispatcherId: null,
    recipientIds: [],
    route: null,
    status: 'ringing',
    ownerCandidates: [],
  };
  const recipients = await getRouteRecipients(alert.station_id);
  if (!recipients.userIds.length) {
    return fail(res, 'No station officers or central dispatch recipients are currently available', 503);
  }
  stream.recipientIds = recipients.userIds;
  stream.route = recipients.route;
  streams.set(streamId, stream);

  const offerEvent = {
    streamId,
    sosId: alert.id,
    callerId: req.user.id,
    callerName: stream.callerName,
    mediaType,
    offer,
    route: stream.route,
  };
  for (const userId of stream.recipientIds) {
    io.to(`user:${userId}`).emit('sos:live-offer', offerEvent);
  }
  ok(res, { streamId }, 'Live SOS offer sent');
};

export const listActiveSosLiveOffers = (req, res) => {
  const activeOffers = [...streams.values()]
    .filter((stream) => stream.status === 'ringing' && stream.recipientIds.includes(req.user.id))
    .map((stream) => ({
      streamId: stream.streamId,
      sosId: stream.sosId,
      callerId: stream.ownerId,
      callerName: stream.callerName,
      mediaType: stream.mediaType,
      offer: stream.offer,
      status: stream.status,
    }));
  ok(res, activeOffers);
};

export const answerSosLiveOffer = async (req, res) => {
  const stream = getStream(req.params.id, req.body.streamId, res);
  if (!stream) return;
  if (!staffRoles.has(req.user.role)) return fail(res, 'Only dispatch staff can answer a live SOS stream', 403);
  if (!stream.recipientIds.includes(req.user.id)) {
    return fail(res, 'This SOS is routed to another station', 403);
  }
  if (stream.status !== 'ringing') return fail(res, 'This live SOS stream is no longer waiting for an answer', 409);
  const { answer } = req.body;
  if (
    typeof answer?.sdp !== 'string' ||
    answer.sdp.length > 100_000 ||
    answer.type !== 'answer'
  ) {
    return fail(res, 'A valid WebRTC answer is required');
  }

  stream.dispatcherId = req.user.id;
  stream.status = 'connected';
  io.to(`user:${stream.ownerId}`).emit('sos:live-answer', {
    sosId: stream.sosId,
    streamId: stream.streamId,
    answer,
  });
  io.to(`user:${stream.dispatcherId}`).emit('sos:live-state', {
    sosId: stream.sosId,
    streamId: stream.streamId,
    status: stream.status,
  });
  for (const userId of stream.recipientIds) {
    io.to(`user:${userId}`).emit('sos:live-state', {
      sosId: stream.sosId,
      streamId: stream.streamId,
      status: stream.status,
      dispatcherId: req.user.id,
      dispatcherName: req.user.full_name || 'Dispatcher',
    });
  }
  for (const candidate of stream.ownerCandidates) {
    io.to(`user:${stream.dispatcherId}`).emit('sos:live-ice', {
      sosId: stream.sosId,
      streamId: stream.streamId,
      candidate,
    });
  }
  stream.ownerCandidates = [];
  ok(res, null, 'Live SOS stream answered');
};

export const addSosLiveIceCandidate = async (req, res) => {
  const stream = getStream(req.params.id, req.body.streamId, res);
  if (!stream) return;
  const { candidate } = req.body;
  if (
    typeof candidate?.candidate !== 'string' ||
    candidate.candidate.length === 0 ||
    candidate.candidate.length > 4096
  ) {
    return fail(res, 'A valid ICE candidate is required');
  }

  if (req.user.id === stream.ownerId) {
    if (stream.dispatcherId) {
      io.to(`user:${stream.dispatcherId}`).emit('sos:live-ice', {
        sosId: stream.sosId,
        streamId: stream.streamId,
        candidate,
      });
    } else {
      if (stream.ownerCandidates.length >= 64) {
        return fail(res, 'Too many ICE candidates for this live stream', 429);
      }
      stream.ownerCandidates.push(candidate);
    }
  } else if (req.user.id === stream.dispatcherId) {
    io.to(`user:${stream.ownerId}`).emit('sos:live-ice', {
      sosId: stream.sosId,
      streamId: stream.streamId,
      candidate,
    });
  } else {
    return fail(res, 'Not a participant in this live SOS stream', 403);
  }
  ok(res, null, 'ICE candidate forwarded');
};

export const endSosLiveStream = async (req, res) => {
  const stream = getStream(req.params.id, req.body.streamId, res);
  if (!stream) return;
  const isPendingStaff = stream.status === 'ringing' &&
    staffRoles.has(req.user.role) &&
    stream.recipientIds.includes(req.user.id);
  if (req.user.id !== stream.ownerId &&
      req.user.id !== stream.dispatcherId &&
      !isPendingStaff) {
    return fail(res, 'Not a participant in this live SOS stream', 403);
  }

  removeStream(stream, req.user.id);
  ok(res, null, 'Live SOS stream ended');
};
