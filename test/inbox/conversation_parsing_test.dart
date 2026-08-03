import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';

/// Reading the API's actual field names.
///
/// The inbox is schema-less Mongo, so the same fact reaches the client under
/// more than one key. The unread counter is written as `unread_count`; the app
/// read only `unread`, so EVERY conversation parsed as read — no badge, no bold,
/// no highlight, on the one screen whose whole job is showing which threads are
/// waiting. It looked exactly like broken styling, and no amount of styling
/// would have fixed it.
void main() {
  group('unread', () {
    test('is read from unread_count, the name the API actually writes', () {
      final conversation = Conversation.fromJson({
        'id': 'c1',
        'channel': 'zalo',
        'unread_count': 4,
      });

      expect(conversation.unread, 4);
      expect(conversation.isUnread, isTrue);
    });

    test('still accepts the bare `unread` some payloads carry', () {
      expect(Conversation.fromJson({'id': 'c1', 'unread': 2}).unread, 2);
    });

    test('prefers unread_count when a payload somehow carries both', () {
      expect(
        Conversation.fromJson({
          'id': 'c1',
          'unread_count': 7,
          'unread': 0,
        }).unread,
        7,
      );
    });

    test('a thread with neither key is read, not unread', () {
      expect(Conversation.fromJson({'id': 'c1'}).isUnread, isFalse);
    });
  });

  group('lastMessageAt', () {
    test('prefers last_message_at, the canonical name', () {
      final conversation = Conversation.fromJson({
        'id': 'c1',
        'last_message_at': '2026-08-03T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      });

      expect(conversation.lastMessageAt?.toUtc().day, 3);
    });

    /// Sorting by `updated_at` would order the inbox by when a row was last
    /// WRITTEN — an assignment or a label edit would jump an old thread to the
    /// top as if the customer had just spoken.
    test('falls back through last_time before updated_at', () {
      final conversation = Conversation.fromJson({
        'id': 'c1',
        'last_time': '2026-08-03T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      });

      expect(conversation.lastMessageAt?.toUtc().day, 3);
    });
  });
}
