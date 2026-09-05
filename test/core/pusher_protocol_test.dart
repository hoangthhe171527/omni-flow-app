import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/pusher_protocol.dart';

/// Framing rules for the Reverb connection.
///
/// These are the details that make a realtime client either work or fail
/// silently — a wrong path, a `data` field decoded one level too few, a ping
/// left unanswered — and none of them are visible from the app's behaviour until
/// messages stop arriving.
void main() {
  group('endpoint', () {
    test('puts the app key in the path, where Reverb expects it', () {
      final url = PusherProtocol.endpoint(
        host: 'ws.example.com',
        port: 443,
        key: 'app-key',
        useTls: true,
      );

      expect(url.scheme, 'wss');
      expect(url.host, 'ws.example.com');
      expect(url.port, 443);
      expect(url.path, '/app/app-key');
      expect(url.queryParameters['protocol'], '7');
    });

    test('drops to ws for a local server', () {
      final url = PusherProtocol.endpoint(
        host: '127.0.0.1',
        port: 8080,
        key: 'local',
        useTls: false,
      );

      expect(url.scheme, 'ws');
      expect(url.port, 8080);
    });
  });

  group('parsing', () {
    test('reads the socket id off the handshake', () {
      final frame = PusherProtocol.parse(
        jsonEncode({
          'event': 'pusher:connection_established',
          // Pusher sends `data` as a JSON *string*, not an object. Missing that
          // leaves socket_id null and every private subscription unsigned.
          'data': jsonEncode({'socket_id': '123.456', 'activity_timeout': 30}),
        }),
      );

      expect(frame, isNotNull);
      expect(frame!.isConnectionEstablished, isTrue);
      expect(frame.socketId, '123.456');
    });

    test('decodes an application event payload', () {
      final frame = PusherProtocol.parse(
        jsonEncode({
          'event': '.message.created',
          'channel': 'private-conversation.c1',
          'data': jsonEncode({'conversation_id': 'c1'}),
        }),
      );

      expect(frame!.event, '.message.created');
      expect(frame.channel, 'private-conversation.c1');
      expect(frame.data['conversation_id'], 'c1');
    });

    test('accepts a payload that is already an object', () {
      final frame = PusherProtocol.parse(
        jsonEncode({
          'event': 'pusher:ping',
          'data': <String, dynamic>{},
        }),
      );

      expect(frame!.isPing, isTrue);
      expect(frame.data, isEmpty);
    });

    test('returns null for junk rather than throwing', () {
      // A malformed frame must not take the connection down with it.
      expect(PusherProtocol.parse('not json'), isNull);
      expect(PusherProtocol.parse(''), isNull);
      expect(PusherProtocol.parse(null), isNull);
      expect(PusherProtocol.parse(jsonEncode({'no': 'event'})), isNull);
      expect(PusherProtocol.parse(jsonEncode([1, 2, 3])), isNull);
    });

    test('survives a data field that is not JSON', () {
      final frame = PusherProtocol.parse(
        jsonEncode({'event': '.thing', 'channel': 'c', 'data': 'plain text'}),
      );

      expect(frame!.data, isEmpty);
    });
  });

  group('event names', () {
    test('strips the dot Laravel prefixes custom events with', () {
      expect(
        PusherProtocol.normalizeEventName('.message.created'),
        'message.created',
      );
      expect(PusherProtocol.normalizeEventName('message.created'), 'message.created');
    });

    test('recognises the protocol’s own bookkeeping', () {
      expect(PusherProtocol.isInternal('pusher:ping'), isTrue);
      expect(
        PusherProtocol.isInternal('pusher_internal:subscription_succeeded'),
        isTrue,
      );
      expect(PusherProtocol.isInternal('.message.created'), isFalse);
    });
  });

  group('outgoing frames', () {
    test('subscribe carries the channel and its signature', () {
      final sent =
          jsonDecode(
                PusherProtocol.subscribe(
                  channel: 'private-conversation.c1',
                  auth: 'key:signature',
                ),
              )
              as Map<String, dynamic>;

      expect(sent['event'], 'pusher:subscribe');
      expect(sent['data']['channel'], 'private-conversation.c1');
      expect(sent['data']['auth'], 'key:signature');
    });

    test('unsubscribe names the channel', () {
      final sent =
          jsonDecode(PusherProtocol.unsubscribe('private-x'))
              as Map<String, dynamic>;

      expect(sent['event'], 'pusher:unsubscribe');
      expect(sent['data']['channel'], 'private-x');
    });

    test('pong answers the ping that keeps the socket open', () {
      // Reverb closes a connection that does not reply, and the symptom is an
      // inbox that stops updating a minute after it was working.
      final sent = jsonDecode(PusherProtocol.pong()) as Map<String, dynamic>;

      expect(sent['event'], 'pusher:pong');
    });
  });
}
