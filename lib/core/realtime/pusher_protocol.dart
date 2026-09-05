import 'dart:convert';

/// The slice of the Pusher wire protocol that Laravel Reverb speaks.
///
/// Kept as pure functions on strings and maps, with no socket and no Flutter, so
/// the framing rules can be tested directly. Everything stateful lives in
/// [RealtimeClient]; everything subtle lives here.
abstract final class PusherProtocol {
  /// Reverb accepts the same handshake Pusher does.
  static const protocolVersion = 7;

  /// The endpoint a Reverb app listens on. The key is part of the path, not a
  /// header — this is what makes a wrong key fail as a closed socket rather than
  /// an auth error.
  static Uri endpoint({
    required String host,
    required int port,
    required String key,
    required bool useTls,
  }) {
    return Uri(
      scheme: useTls ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/app/$key',
      queryParameters: {
        'protocol': '$protocolVersion',
        'client': 'viomni-mobile',
        'version': '1.0',
      },
    );
  }

  /// The wire name of a private channel.
  ///
  /// Laravel's `PrivateChannel` prepends `private-` before broadcasting, so a
  /// server-side `conversation.{id}` is `private-conversation.{id}` on the wire.
  /// The prefix is also what marks a channel as guarded: subscribing without it
  /// asks for a *public* channel of that name, which succeeds, needs no auth,
  /// and then receives nothing — silently, forever. laravel-echo hides this
  /// behind `.private()`; here it is named so it cannot be forgotten.
  static String privateChannel(String name) =>
      name.startsWith('private-') ? name : 'private-$name';

  static String subscribe({required String channel, required String auth}) {
    return jsonEncode({
      'event': 'pusher:subscribe',
      'data': {'channel': channel, 'auth': auth},
    });
  }

  static String unsubscribe(String channel) {
    return jsonEncode({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channel},
    });
  }

  /// Reverb closes a connection that does not answer its ping.
  static String pong() => jsonEncode({'event': 'pusher:pong', 'data': {}});

  /// Parses one frame. Returns null for anything unreadable rather than
  /// throwing: a malformed frame must not take the connection down.
  static PusherFrame? parse(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final event = decoded['event'];
    if (event is! String) return null;

    return PusherFrame(
      event: event,
      channel: decoded['channel'] as String?,
      // `data` arrives as a JSON *string* for application events and as a nested
      // object for pusher: control events. Both shapes are normalised here so a
      // caller never has to double-decode.
      data: _decodeData(decoded['data']),
    );
  }

  static Map<String, dynamic> _decodeData(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        // Not JSON. Some events carry a bare string; there is nothing useful to
        // hand a caller expecting a map.
      }
    }
    return const {};
  }

  /// Laravel broadcasts a custom event name with a leading dot ('.message.created')
  /// so it can be told apart from a class-name broadcast. Callers want the name.
  static String normalizeEventName(String event) =>
      event.startsWith('.') ? event.substring(1) : event;

  /// True for the protocol's own bookkeeping, which carries no business meaning.
  static bool isInternal(String event) =>
      event.startsWith('pusher:') || event.startsWith('pusher_internal:');
}

class PusherFrame {
  const PusherFrame({required this.event, this.channel, this.data = const {}});

  final String event;
  final String? channel;
  final Map<String, dynamic> data;

  bool get isConnectionEstablished => event == 'pusher:connection_established';
  bool get isPing => event == 'pusher:ping';
  bool get isError => event == 'pusher:error';

  /// Present on `pusher:connection_established`. Private-channel auth is signed
  /// against it, so a subscription cannot be replayed on another connection.
  String? get socketId {
    final value = data['socket_id'];
    return value == null ? null : '$value';
  }
}
