import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api.dart';

class SosLiveStreamService {
  static SosLiveStreamService? active;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];
  final List<Map<String, dynamic>> _pendingRemoteCandidates = [];
  final List<Map<String, dynamic>> _earlyRemoteCandidates = [];
  final Completer<void> _startupComplete = Completer<void>();
  Map<String, dynamic>? _earlyAnswer;
  final Set<String> _earlyEndIds = {};
  String? _sosId;
  String? _streamId;
  String? _mediaType;
  bool _remoteDescriptionSet = false;
  bool _stopping = false;
  bool _stopRequested = false;
  bool _rendererInitialized = false;
  Future<void>? _closeFuture;
  Future<void>? _finishFuture;

  void Function(String status, String? error)? onStatusChanged;

  String? get mediaType => _mediaType;

  Future<void> start(String sosId, {required String mediaType}) async {
    if (active != null) {
      throw StateError('A live SOS stream is already active.');
    }
    active = this;
    _sosId = sosId;
    _mediaType = mediaType;
    _setStatus('connecting');

    try {
      await localRenderer.initialize();
      _rendererInitialized = true;
      if (_stopRequested) return;
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': mediaType == 'video'
            ? {'width': 640, 'height': 480, 'frameRate': 15}
            : false,
      });
      if (_stopRequested) return;
      localRenderer.srcObject = _localStream;

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      if (_stopRequested) return;
      _peerConnection!.onIceCandidate = _onLocalIceCandidate;
      _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          unawaited(
            _finish(
              status: 'error',
              error: 'The live connection failed. Check your network and try again.',
            ),
          );
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected &&
            !_stopping) {
          _setStatus('disconnected', 'The live connection was interrupted.');
        }
      };

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(offer);
      if (_stopRequested) return;
      final response = await Api.post('/sos/$sosId/live/offer', {
        'mediaType': mediaType,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });
      final streamId = response is Map
          ? response['streamId']?.toString()
          : null;
      if (streamId == null || streamId.isEmpty) {
        throw StateError('The server did not start the live SOS stream.');
      }
      _streamId = streamId;
      if (_stopRequested) return;
      _setStatus('waiting');
      if (_earlyEndIds.remove(streamId)) {
        handleEnded({'streamId': streamId});
        return;
      }
      for (final data in _earlyRemoteCandidates.where(
        (data) => data['streamId'] == streamId,
      )) {
        handleIceCandidate(data);
      }
      _earlyRemoteCandidates.removeWhere(
        (data) => data['streamId'] == streamId,
      );
      final earlyAnswer = _earlyAnswer;
      if (earlyAnswer?['streamId'] == streamId) {
        _earlyAnswer = null;
        await handleAnswer(earlyAnswer!);
      }
      for (final candidate in _pendingLocalCandidates) {
        unawaited(_sendIceCandidate(candidate));
      }
      _pendingLocalCandidates.clear();
    } catch (error) {
      if (_stopRequested) return;
      _setStatus(
        'error',
        Api.userMessage(error, fallback: 'Could not start the live stream.'),
      );
      await _close();
      rethrow;
    } finally {
      if (!_startupComplete.isCompleted) _startupComplete.complete();
    }
  }

  void _onLocalIceCandidate(RTCIceCandidate candidate) {
    final value = candidate.candidate;
    if (value == null || value.isEmpty || _stopRequested) return;
    final data = <String, dynamic>{
      'candidate': value,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
    if (_streamId == null) {
      _pendingLocalCandidates.add(data);
    } else {
      unawaited(_sendIceCandidate(data));
    }
  }

  Future<void> _sendIceCandidate(Map<String, dynamic> candidate) async {
    final sosId = _sosId;
    final streamId = _streamId;
    if (sosId == null || streamId == null || _stopping) return;
    try {
      await Api.post('/sos/$sosId/live/ice', {
        'streamId': streamId,
        'candidate': candidate,
      });
    } catch (error) {
      if (!_stopping) {
        unawaited(
          _finish(
            status: 'error',
            error: Api.userMessage(
              error,
              fallback: 'Could not connect the live stream.',
            ),
          ),
        );
      }
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    if (_streamId == null) {
      _earlyAnswer = data;
      return;
    }
    if (data['streamId'] != _streamId || _peerConnection == null) return;
    try {
      final answer = data['answer'];
      if (answer is! Map || answer['sdp'] == null || answer['type'] == null) {
        throw StateError('Dispatcher returned an invalid WebRTC answer.');
      }
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      _remoteDescriptionSet = true;
      for (final candidate in _pendingRemoteCandidates) {
        await _addRemoteCandidate(candidate);
      }
      _pendingRemoteCandidates.clear();
      _setStatus('live');
    } catch (error) {
      await _finish(
        status: 'error',
        error: Api.userMessage(
          error,
          fallback: 'Could not establish the live connection.',
        ),
      );
    }
  }

  void handleIceCandidate(Map<String, dynamic> data) {
    if (data['candidate'] is! Map) return;
    if (_streamId == null) {
      _earlyRemoteCandidates.add(data);
      return;
    }
    if (data['streamId'] != _streamId) return;
    final candidate = Map<String, dynamic>.from(data['candidate'] as Map);
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
    } else {
      unawaited(
        _addRemoteCandidate(candidate).catchError((Object error) async {
          await _finish(
            status: 'error',
            error: Api.userMessage(
              error,
              fallback: 'Could not connect the live stream.',
            ),
          );
        }),
      );
    }
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> data) async {
    await _peerConnection?.addCandidate(
      RTCIceCandidate(
        data['candidate']?.toString(),
        data['sdpMid']?.toString(),
        (data['sdpMLineIndex'] as num?)?.toInt(),
      ),
    );
  }

  void handleEnded(Map<String, dynamic> data) {
    if (_streamId == null && data['streamId'] is String) {
      _earlyEndIds.add(data['streamId'] as String);
      return;
    }
    if (data['streamId'] != _streamId) return;
    _setStatus('ended');
    unawaited(_close());
  }

  Future<void> stop() => _finish();

  Future<void> _finish({String status = 'ended', String? error}) =>
      _finishFuture ??= _performFinish(status: status, error: error);

  Future<void> _performFinish({required String status, String? error}) async {
    _stopRequested = true;
    if (!_startupComplete.isCompleted) await _startupComplete.future;
    final sosId = _sosId;
    final streamId = _streamId;
    String? errorMessage;
    if (sosId != null && streamId != null) {
      try {
        await Api.post('/sos/$sosId/live/end', {'streamId': streamId});
      } catch (error) {
        errorMessage = Api.userMessage(
          error,
          fallback: 'Could not notify dispatch that the live stream ended.',
        );
      }
    }
    await _close();
    _setStatus(status, error ?? errorMessage);
  }

  Future<void> _close() => _closeFuture ??= _performClose();

  Future<void> _performClose() async {
    _stopping = true;
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _peerConnection?.close();
    await _localStream?.dispose();
    _peerConnection = null;
    _localStream = null;
    localRenderer.srcObject = null;
    if (_rendererInitialized) await localRenderer.dispose();
    _rendererInitialized = false;
    if (active == this) active = null;
  }

  void _setStatus(String status, [String? error]) {
    onStatusChanged?.call(status, error);
  }
}
