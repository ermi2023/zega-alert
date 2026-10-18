import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api.dart';
import '../services/webrtc_service.dart';

typedef JsonMap = Map<String, dynamic>;

/// Thin wrapper over the backend Socket.io channel.
/// The socket is owned by [MainShell]; screens register handlers here.
class SocketService {
  static io.Socket? _socket;

  /// Fired when staff updates the citizen's own SOS alert status.
  static void Function(JsonMap)? onSosStatus;

  /// Fired when a new chat message arrives on one of the user's conversations.
  static void Function(dynamic)? onChatMessage;

  /// Fired when an officer requests a callback on one of the citizen's reports.
  static void Function(JsonMap)? onCallbackNew;

  /// Fired when a WebRTC incoming call is received.
  static void Function(dynamic)? onIncomingCall;

  static bool get connected => _socket?.connected ?? false;

  static void connect() {
    if (_socket != null) return;
    _socket = io.io(
      Api.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': Api.token})
          .build(),
    );
    _socket!.onConnect((_) => print('[socket] connected'));
    _socket!.onConnectError((err) => print('[socket] connect error: $err'));
    _socket!.on('sos:status', (data) {
      if (data is Map) onSosStatus?.call(JsonMap.from(data));
    });
    _socket!.on('chat:message', (data) => onChatMessage?.call(data));
    _socket!.on('callback:new', (data) {
      if (data is Map) onCallbackNew?.call(JsonMap.from(data));
    });
    _socket!.on('webrtc:incoming-call', (data) => onIncomingCall?.call(data));
    _socket!.on('webrtc:call-ended', (_) => WebRTCService.active?.endCall());
    _socket!.on('webrtc:call-answered', (data) {
      if (data is Map && data['answer'] is Map) {
        WebRTCService.active?.handleAnswer(
          (data['roomId'] ?? '').toString(),
          Map<String, dynamic>.from(data['answer'] as Map),
        );
      }
    });
    _socket!.on('webrtc:ice-candidate', (data) {
      if (data is Map && data['candidate'] is Map) {
        WebRTCService.active?.handleIceCandidate(
          (data['roomId'] ?? '').toString(),
          Map<String, dynamic>.from(data['candidate'] as Map),
        );
      }
    });
  }

  /// Join a conversation room so `chat:send` style events are received.
  static void joinConversation(String conversationId) {
    _socket?.emit('chat:join', conversationId);
  }

  /// Join the per-alert room so dispatch:updated / sos:location events are received.
  static void joinSosRoom(String sosId) {
    _socket?.emit('sos:join', sosId);
    _socket?.emit('join', 'sos:$sosId');
  }

  static void disconnect() {
    onSosStatus = null;
    onChatMessage = null;
    onCallbackNew = null;
    onIncomingCall = null;
    _socket?.dispose();
    _socket = null;
  }
}
