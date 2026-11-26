import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String targetUserId;
  final String targetName;
  final String callType;
  final String? roomId;
  final Map<String, dynamic>? incomingOffer;

  const VideoCallScreen({
    super.key,
    required this.targetUserId,
    required this.targetName,
    this.callType = 'video',
    this.roomId,
    this.incomingOffer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _rtc = WebRTCService();
  String _statusKey = 'connecting';
  String? _callError;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _hasRemoteStream = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _rtc.onCallEnded = () {
      if (!mounted || _closing) return;
      _closing = true;
      Navigator.of(context).maybePop();
    };
    _rtc.onStatusChanged = (status, error) {
      if (!mounted) return;
      setState(() {
        _statusKey = status;
        _callError = error;
      });
    };
    _rtc.onRemoteStream = (_) {
      if (mounted) setState(() => _hasRemoteStream = true);
    };
    if (widget.incomingOffer != null && widget.roomId != null) {
      _answerCall();
    } else {
      _startCall();
    }
  }

  Future<void> _startCall() async {
    try {
      await _rtc.startCall(widget.targetUserId, callType: widget.callType);
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusKey = 'error';
          _callError = Api.userMessage(
            error,
            fallback: 'Could not connect the call. Check your connection and try again.',
          );
        });
      }
    }
  }

  Future<void> _answerCall() async {
    try {
      await _rtc.answerCall(
        widget.roomId!,
        widget.incomingOffer!,
        peerUserId: widget.targetUserId,
        callType: widget.callType,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusKey = 'error';
          _callError = Api.userMessage(
            error,
            fallback: 'Could not connect the call. Check your connection and try again.',
          );
        });
      }
    }
  }

  Future<void> _endCall() async {
    if (_closing) return;
    _closing = true;
    await _rtc.endCall(notifyUi: false);
    if (mounted) Navigator.of(context).maybePop();
  }

  String _statusLabel(AppLocalizations loc) => switch (_statusKey) {
    'connecting' => loc.connecting,
    'ringing' => loc.ringing,
    'connected' => 'Connected',
    'disconnected' => 'Reconnecting…',
    'error' => _callError ?? 'Call failed',
    _ => _statusKey,
  };

  void _toggleMicrophone() {
    setState(() => _microphoneEnabled = !_microphoneEnabled);
    _rtc.setMicrophoneEnabled(_microphoneEnabled);
  }

  void _toggleCamera() {
    setState(() => _cameraEnabled = !_cameraEnabled);
    _rtc.setCameraEnabled(_cameraEnabled);
  }

  @override
  void dispose() {
    _rtc.onCallEnded = null;
    _rtc.onStatusChanged = null;
    _rtc.onRemoteStream = null;
    unawaited(_rtc.endCall(notifyUi: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final status = _statusLabel(loc);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_hasRemoteStream)
                    RTCVideoView(
                      _rtc.remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Waiting for the other person…',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  if (widget.callType == 'video')
                    Positioned(
                      top: 16,
                      right: 16,
                      width: 120,
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RTCVideoView(
                          _rtc.localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.targetName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _toggleMicrophone,
                    tooltip: _microphoneEnabled
                        ? 'Mute microphone'
                        : 'Unmute microphone',
                    icon: Icon(
                      _microphoneEnabled ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: 32,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  IconButton(
                    onPressed: _endCall,
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 36,
                    ),
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  if (widget.callType == 'video')
                    IconButton(
                      onPressed: _toggleCamera,
                      tooltip: _cameraEnabled
                          ? 'Turn camera off'
                          : 'Turn camera on',
                      icon: Icon(
                        _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                        color: Colors.white,
                        size: 32,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white24,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
