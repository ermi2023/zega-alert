import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api.dart';

typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnCallEnded = void Function();

class WebRTCService {
  /// The call currently in progress, so Socket.io signaling events can be
  /// routed to the right peer connection.
  static WebRTCService? active;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _roomId;
  String? _peerUserId;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  OnRemoteStream? onRemoteStream;
  OnCallEnded? onCallEnded;

  bool get isInCall => _peerConnection != null;
  String? get roomId => _roomId;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> disposeRenderers() async {
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }

  Future<void> _openLocalStream(String callType) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': callType == 'video'
          ? {'width': 640, 'height': 480, 'frameRate': 15}
          : false,
    });
    localRenderer.srcObject = _localStream;
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(candidate);
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        onRemoteStream?.call(event.streams[0]);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }
  }

  Future<void> startCall(String targetUserId, {String callType = 'video'}) async {
    active = this;
    _peerUserId = targetUserId;
    await initRenderers();
    await _openLocalStream(callType);
    await _createPeerConnection();

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': callType == 'video',
    });
    await _peerConnection!.setLocalDescription(offer);

    final res = await Api.post('/webrtc/offer', {
      'targetUserId': targetUserId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'callType': callType,
    });
    if (res is Map && res['roomId'] != null) _roomId = res['roomId'] as String;
  }

  Future<void> answerCall(String roomId, Map<String, dynamic> offer, {String callType = 'video'}) async {
    active = this;
    _roomId = roomId;
    await initRenderers();
    await _openLocalStream(callType);
    await _createPeerConnection();

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await Api.post('/webrtc/answer', {
      'roomId': roomId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<void> handleAnswer(String roomId, Map<String, dynamic> answer) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  void handleIceCandidate(String roomId, Map<String, dynamic> candidate) {
    _peerConnection?.addCandidate(
      RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']),
    );
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    if (_roomId == null || _peerUserId == null) return;
    Api.post('/webrtc/ice-candidate', {
      'roomId': _roomId,
      'targetUserId': _peerUserId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  Future<void> endCall() async {
    final rid = _roomId;
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      await _peerConnection?.close();
    } catch (_) {}
    if (rid != null) {
      Api.post('/webrtc/end', {'roomId': rid}).catchError((_) => null);
    }
    _peerConnection = null;
    _localStream = null;
    _roomId = null;
    _peerUserId = null;
    if (active == this) active = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    onCallEnded?.call();
  }
}
