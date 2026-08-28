import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/notifications/application/push_notifications.dart';

void main() {
  group('push platform', () {
    test('maps only Android and iOS to API platform values', () {
      expect(pushPlatformForTarget(TargetPlatform.android), 'android');
      expect(pushPlatformForTarget(TargetPlatform.iOS), 'ios');
      expect(pushPlatformForTarget(TargetPlatform.fuchsia), isNull);
      expect(pushPlatformForTarget(TargetPlatform.linux), isNull);
      expect(pushPlatformForTarget(TargetPlatform.macOS), isNull);
      expect(pushPlatformForTarget(TargetPlatform.windows), isNull);
    });
  });

  group('APNs readiness', () {
    test('waits for APNs before allowing iOS FCM token work', () async {
      final responses = <String?>[null, '', 'apns-token'];
      final delays = <Duration>[];

      final token = await waitForApnsToken(
        readToken: () async => responses.removeAt(0),
        delay: (duration) async => delays.add(duration),
        retryDelay: const Duration(milliseconds: 25),
      );

      expect(token, 'apns-token');
      expect(delays, [
        const Duration(milliseconds: 25),
        const Duration(milliseconds: 25),
      ]);
    });

    test('fails clearly after a bounded number of attempts', () async {
      var reads = 0;

      await expectLater(
        waitForApnsToken(
          readToken: () async {
            reads++;
            return null;
          },
          delay: (_) async {},
          maxAttempts: 3,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('3 attempts'),
          ),
        ),
      );
      expect(reads, 3);
    });
  });

  group('foreground presentation', () {
    test('uses the Android local notification path', () {
      expect(
        shouldShowLocalForegroundNotification(
          platform: 'android',
          hasRemoteNotification: true,
        ),
        isTrue,
      );
    });

    test('avoids duplicate iOS alerts but covers data-only messages', () {
      expect(
        shouldShowLocalForegroundNotification(
          platform: 'ios',
          hasRemoteNotification: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLocalForegroundNotification(
          platform: 'ios',
          hasRemoteNotification: false,
        ),
        isTrue,
      );
    });
  });

  group('PushIntent', () {
    test('keeps conversation_id routing for notification taps', () {
      final intent = PushIntent.fromData({
        'type': 'inbox_message',
        'conversation_id': 'conversation-42',
        'channel': 'zalo',
        'notification_id': 'notification-7',
      });

      expect(intent?.conversationId, 'conversation-42');
    });

    test('ignores unrelated or unroutable payloads', () {
      expect(
        PushIntent.fromData({
          'type': 'something_else',
          'conversation_id': 'conversation-42',
        }),
        isNull,
      );
      expect(PushIntent.fromData({'type': 'inbox_message'}), isNull);
    });
  });
}
