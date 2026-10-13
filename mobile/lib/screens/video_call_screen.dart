import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    _rtc.onCallEnded = () {
      if (mounted) Navigator.pop(context);
    };
    if (widget.incomingOffer != null && widget.roomId != null) {
      _answerCall();
    } else {
      _startCall();
    }
  }

  Future<void> _startCall() async {
    await _rtc.startCall(widget.targetUserId, callType: widget.callType);
    if (mounted) setState(() => _statusKey = 'ringing');
  }

  Future<void> _answerCall() async {
    await _rtc.answerCall(widget.roomId!, widget.incomingOffer!, callType: widget.callType);
    if (mounted) setState(() => _statusKey = 'connecting');
  }

  void _endCall() {
    _rtc.endCall();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _rtc.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final status = _statusKey == 'connecting' ? loc.connecting : loc.ringing;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  RTCVideoView(
                    _rtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    width: 120,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        _rtc.localRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.targetName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(status, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                    onPressed: () {},
                    icon: const Icon(Icons.mic, color: Colors.white, size: 32),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                  IconButton(
                    onPressed: _endCall,
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 36),
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 32),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
