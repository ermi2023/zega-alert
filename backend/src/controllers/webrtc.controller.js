import { io } from '../socket/socket.js';
import { ok, fail } from '../utils/response.js';

// In-memory signaling store (for dev; production would use Redis)
const rooms = new Map();

export const createOffer = async (req, res) => {
  const { targetUserId, offer, callType = 'video' } = req.body;
  if (!targetUserId || !offer) return fail(res, 'targetUserId and offer are required');

  const roomId = `call:${[req.user.id, targetUserId].sort().join(':')}`;
  rooms.set(roomId, {
    caller: req.user.id,
    callee: targetUserId,
    offer,
    callType,
    status: 'ringing',
    createdAt: Date.now(),
  });

  io.to(`user:${targetUserId}`).emit('webrtc:incoming-call', {
    roomId,
    callerId: req.user.id,
    callerName: req.user.full_name || 'Unknown',
    callType,
    offer,
  });

  ok(res, { roomId }, 'Call offer sent');
};

export const createAnswer = async (req, res) => {
  const { roomId, answer } = req.body;
  if (!roomId || !answer) return fail(res, 'roomId and answer are required');

  const room = rooms.get(roomId);
  if (!room) return fail(res, 'Call room not found', 404);
  room.answer = answer;
  room.status = 'connected';

  io.to(`user:${room.caller}`).emit('webrtc:call-answered', { roomId, answer });
  ok(res, null, 'Answer sent');
};

export const addIceCandidate = async (req, res) => {
  const { roomId, targetUserId, candidate } = req.body;
  if (!roomId || !candidate) return fail(res, 'roomId and candidate required');

  io.to(`user:${targetUserId}`).emit('webrtc:ice-candidate', { roomId, candidate });
  ok(res, null, 'ICE candidate forwarded');
};

export const endCall = async (req, res) => {
  const { roomId } = req.body;
  if (!roomId) return fail(res, 'roomId required');

  const room = rooms.get(roomId);
  if (room) {
    const peerId = room.caller === req.user.id ? room.callee : room.caller;
    io.to(`user:${peerId}`).emit('webrtc:call-ended', { roomId });
    room.status = 'ended';
    rooms.delete(roomId);
  }
  ok(res, null, 'Call ended');
};
