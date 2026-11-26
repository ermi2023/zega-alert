import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api.dart';

typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnCallEnded = void Function();

class WebRTCService {
  /// The call currently in progress, so Socket.io signaling events can be
  /// routed to the right peer connection.
  static WebRTCService? active;
  static final Map<String, List<Map<String, dynamic>>>
  _pendingSignalingCandidates = {};
  static final Map<String, Map<String, dynamic>> _pendingSignalingAnswers = {};

  static void routeAnswer(String roomId, Map<String, dynamic> answer) {
    if (roomId.isEmpty) return;
    final current = active;
    if (current != null && current._roomId == roomId) {
      unawaited(current.handleAnswer(roomId, answer));
      return;
    }
    _pendingSignalingAnswers[roomId] = answer;
  }

  static void routeIceCandidate(
    String roomId,
    Map<String, dynamic> candidate,
  ) {
    if (roomId.isEmpty) return;
    final current = active;
    if (current != null && current._roomId == roomId) {
      current.handleIceCandidate(roomId, candidate);
      return;
    }
    (_pendingSignalingCandidates[roomId] ??= []).add(candidate);
  }

  static void handleCallEnded(String roomId) {
    if (roomId.isEmpty) return;
    _pendingSignalingCandidates.remove(roomId);
    _pendingSignalingAnswers.remove(roomId);
    final current = active;
    if (current != null) {
      if (current._roomId == roomId) {
        unawaited(current.endCall(notifyPeer: false));
      } else if (current._roomId == null) {
        current._pendingEndedRoomId = roomId;
      }
    }
  }

  void _flushSignalingCandidates(String roomId) {
    final candidates = _pendingSignalingCandidates.remove(roomId) ?? [];
    for (final candidate in candidates) {
      handleIceCandidate(roomId, candidate);
    }
  }

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _roomId;
  String? _peerUserId;
  String? _pendingEndedRoomId;
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];
  final List<Map<String, dynamic>> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _renderersInitialized = false;
  bool _ending = false;
  Future<void>? _endFuture;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  OnRemoteStream? onRemoteStream;
  OnCallEnded? onCallEnded;

  bool get isInCall => _peerConnection != null;
  String? get roomId => _roomId;

  Future<void> initRenderers() async {
    if (_renderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersInitialized = true;
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
      _queueOrSendIceCandidate(candidate);
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        onRemoteStream?.call(event.streams[0]);
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setStatus('connected');
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _setStatus('disconnected');
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setStatus('error', 'The call connection failed. Check your network.');
        unawaited(endCall(notifyUi: false));
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        unawaited(endCall(notifyPeer: false));
      }
    };

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }
  }

  Future<void> startCall(String targetUserId, {String callType = 'video'}) async {
    if (active != null && active != this) {
      throw StateError('Another call is already active.');
    }
    active = this;
    _ending = false;
    _pendingEndedRoomId = null;
    _peerUserId = targetUserId;
    _setStatus('connecting');
    try {
      await initRenderers();
      if (_ending) return;
      await _openLocalStream(callType);
      if (_ending) return;
      await _createPeerConnection();
      if (_ending) return;

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': callType == 'video',
      });
      await _peerConnection!.setLocalDescription(offer);
      if (_ending) return;

      final res = await Api.post('/webrtc/offer', {
        'targetUserId': targetUserId,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'callType': callType,
      });
      if (res is! Map || res['roomId'] == null) {
        throw StateError('The call server did not create a call room.');
      }
      _roomId = res['roomId'].toString();
      if (_pendingEndedRoomId == _roomId) {
        _pendingEndedRoomId = null;
        await endCall(notifyPeer: false);
        return;
      }
      _pendingEndedRoomId = null;
      if (_ending) return;
      _flushSignalingCandidates(_roomId!);
      _setStatus('ringing');
      final pendingAnswer = _pendingSignalingAnswers.remove(_roomId);
      if (pendingAnswer != null) {
        await handleAnswer(_roomId!, pendingAnswer);
      }
      await _flushLocalCandidates();
    } catch (error) {
      _setStatus('error', error.toString());
      await endCall(notifyPeer: false, notifyUi: false);
      rethrow;
    }
  }

  Future<void> answerCall(
    String roomId,
    Map<String, dynamic> offer, {
    required String peerUserId,
    String callType = 'video',
  }) async {
    if (active != null && active != this) {
      throw StateError('Another call is already active.');
    }
    active = this;
    _ending = false;
    _roomId = roomId;
    _peerUserId = peerUserId;
    _flushSignalingCandidates(roomId);
    _setStatus('connecting');
    try {
      await initRenderers();
      if (_ending) return;
      await _openLocalStream(callType);
      if (_ending) return;
      await _createPeerConnection();
      if (_ending) return;

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      if (_ending) return;
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      if (_ending) return;

      await Api.post('/webrtc/answer', {
        'roomId': roomId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    } catch (error) {
      _setStatus('error', error.toString());
      await endCall(notifyPeer: false, notifyUi: false);
      rethrow;
    }
  }

  Future<void> handleAnswer(String roomId, Map<String, dynamic> answer) async {
    if (_ending || roomId != _roomId) return;
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();
    } catch (error) {
      _setStatus('error', 'Could not connect the call: $error');
      unawaited(endCall(notifyUi: false));
    }
  }

  void handleIceCandidate(String roomId, Map<String, dynamic> candidate) {
    if (_ending || roomId != _roomId) return;
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    unawaited(
      _addRemoteCandidate(candidate).catchError((Object error) {
        _setStatus('error', 'Could not connect the call: $error');
        return endCall(notifyUi: false);
      }),
    );
  }

  void _queueOrSendIceCandidate(RTCIceCandidate candidate) {
    final value = candidate.candidate;
    if (value == null || value.isEmpty || _ending) return;
    final data = <String, dynamic>{
      'candidate': value,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
    if (_roomId == null || _peerUserId == null) {
      _pendingLocalCandidates.add(data);
    } else {
      unawaited(_sendIceCandidate(data));
    }
  }

  Future<void> _flushLocalCandidates() async {
    final candidates = List<Map<String, dynamic>>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    for (final candidate in candidates) {
      await _sendIceCandidate(candidate);
    }
  }

  Future<void> _sendIceCandidate(Map<String, dynamic> candidate) async {
    final roomId = _roomId;
    final peerUserId = _peerUserId;
    if (roomId == null || peerUserId == null || _ending) return;
    try {
      await Api.post('/webrtc/ice-candidate', {
        'roomId': roomId,
        'targetUserId': peerUserId,
        'candidate': candidate,
      });
    } catch (error) {
      _setStatus('error', 'Could not send call network data: $error');
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final candidates = List<Map<String, dynamic>>.from(
      _pendingRemoteCandidates,
    );
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> candidate) async {
    await _peerConnection?.addCandidate(
      RTCIceCandidate(
        candidate['candidate']?.toString(),
        candidate['sdpMid']?.toString(),
        (candidate['sdpMLineIndex'] as num?)?.toInt(),
      ),
    );
  }

  void setMicrophoneEnabled(bool enabled) {
    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = enabled;
    }
  }

  void setCameraEnabled(bool enabled) {
    for (final track in _localStream?.getVideoTracks() ?? []) {
      track.enabled = enabled;
    }
  }

  void Function(String status, String? error)? onStatusChanged;

  void _setStatus(String status, [String? error]) {
    onStatusChanged?.call(status, error);
  }

  Future<void> endCall({
    bool notifyPeer = true,
    bool notifyUi = true,
  }) =>
      _endFuture ??= _endCall(notifyPeer: notifyPeer, notifyUi: notifyUi);

  Future<void> _endCall({
    required bool notifyPeer,
    required bool notifyUi,
  }) async {
    _ending = true;
    final rid = _roomId;
    if (rid != null) {
      _pendingSignalingCandidates.remove(rid);
      _pendingSignalingAnswers.remove(rid);
    }
    try {
      for (final track in _localStream?.getTracks() ?? []) {
        await track.stop();
      }
      await _peerConnection?.close();
    } catch (error) {
      _setStatus('error', 'Could not close the local call cleanly: $error');
    }
    if (rid != null && notifyPeer) {
      try {
        await Api.post('/webrtc/end', {'roomId': rid});
      } catch (error) {
        _setStatus('error', 'Could not notify the other caller: $error');
      }
    }
    _peerConnection = null;
    _localStream = null;
    _roomId = null;
    _peerUserId = null;
    _remoteDescriptionSet = false;
    _pendingLocalCandidates.clear();
    _pendingRemoteCandidates.clear();
    if (active == this) active = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    if (_renderersInitialized) {
      try {
        await disposeRenderers();
      } catch (error) {
        _setStatus('error', 'Could not release call media: $error');
      }
    }
    _renderersInitialized = false;
    if (notifyUi) onCallEnded?.call();
  }
}
