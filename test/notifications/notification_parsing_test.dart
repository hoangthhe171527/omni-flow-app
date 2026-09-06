import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';

/// What the bell reads off the wire, and where a tap goes.
void main() {
  AppNotification parse(Map<String, dynamic> json) =>
      AppNotification.fromJson(json);

  group('kinds', () {
    test('each task event keeps its own identity', () {
      // These were all TASK_ASSIGNED until the API was fixed. If they collapse
      // back into one, the list shows a handout icon on a completion.
      expect(
        parse({'notification_type': 'TASK_ASSIGNED'}).kind,
        NotificationKind.taskAssigned,
      );
      expect(
        parse({'notification_type': 'TASK_COMPLETED'}).kind,
        NotificationKind.taskCompleted,
      );
      expect(
        parse({'notification_type': 'TASK_STAGE_OPEN'}).kind,
        NotificationKind.taskStageOpen,
      );
    });

    test('a type this build has never heard of is still a readable row', () {
      // A phone two releases behind must still show what the server wrote.
      // Dropping the row would mean the worker never learns it existed.
      final unknown = parse({
        'notification_type': 'PIANO_DELIVERED',
        'title': 'Đàn đã giao',
        'content': 'KAWAI HAT-5 đã tới nhà khách',
      });

      expect(unknown.kind, NotificationKind.other);
      expect(unknown.title, 'Đàn đã giao');
      expect(unknown.body, 'KAWAI HAT-5 đã tới nhà khách');
    });

    test('a missing type does not throw', () {
      expect(parse(const {}).kind, NotificationKind.other);
    });
  });

  group('read state', () {
    test('no read_at means unread', () {
      expect(parse({'notification_type': 'TASK_ASSIGNED'}).isUnread, isTrue);
    });

    test('a read_at means read', () {
      final read = parse({
        'notification_type': 'TASK_ASSIGNED',
        'read_at': '2026-09-05T08:00:00Z',
      });

      expect(read.isUnread, isFalse);
    });

    test('marking read locally does not lose anything else', () {
      final before = parse({
        'notification_type': 'TASK_ASSIGNED',
        'title': 'Bạn có việc mới',
        'related_entity_type': 'task',
        'related_entity_id': 't-1',
      });

      final after = before.markedRead();

      expect(after.isUnread, isFalse);
      expect(after.title, 'Bạn có việc mới');
      expect(after.taskId, 't-1');
    });
  });

  group('where a tap goes', () {
    test('a task notification resolves to its task', () {
      final assigned = parse({
        'notification_type': 'TASK_ASSIGNED',
        'related_entity_type': 'task',
        'related_entity_id': 't-1',
      });

      expect(assigned.taskId, 't-1');
    });

    test('a task type with no id goes nowhere rather than to /tasks/', () {
      // Both halves have to agree. Half a link navigates to a broken screen,
      // which is worse than not navigating.
      final broken = parse({
        'notification_type': 'TASK_ASSIGNED',
        'related_entity_type': 'task',
        'related_entity_id': '',
      });

      expect(broken.taskId, isNull);
    });

    test('an inbox notification is not treated as a task', () {
      final message = parse({
        'notification_type': 'INBOX_MESSAGE',
        'related_entity_type': 'conversation',
        'related_entity_id': 'c-1',
      });

      expect(message.taskId, isNull);
      expect(message.kind.isTask, isFalse);
    });

    test('an unknown type never routes, even with a task entity', () {
      final unknown = parse({
        'notification_type': 'TASK_SOMETHING_NEW',
        'related_entity_type': 'task',
        'related_entity_id': 't-9',
      });

      // It reads fine; it just does not guess at a destination this build
      // may not have.
      expect(unknown.taskId, isNull);
    });
  });
}
