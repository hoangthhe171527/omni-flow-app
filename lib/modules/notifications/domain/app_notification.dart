import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// What a notification is about, and therefore where tapping it should go.
///
/// The API stores one of these per row. The app deliberately does not switch on
/// the free-form `metadata.type` string: an unknown value has to be a normal,
/// readable row rather than a crash or a blank line, and an enum with an
/// explicit fallback is the only shape that guarantees it.
enum NotificationKind {
  taskAssigned('TASK_ASSIGNED'),
  taskStageOpen('TASK_STAGE_OPEN'),
  taskProgress('TASK_PROGRESS'),
  taskCompleted('TASK_COMPLETED'),
  taskCommented('TASK_COMMENTED'),
  taskMentioned('TASK_MENTIONED'),
  taskDueSoon('TASK_DUE_SOON'),
  taskOverdue('TASK_OVERDUE'),
  inboxMessage('INBOX_MESSAGE'),

  /// Anything the server knows about and this build does not.
  ///
  /// A phone that has not been updated for two releases still shows the title
  /// and body the server wrote — it just cannot deep-link. Silently dropping
  /// the row would be worse: the worker would never learn the notification
  /// existed.
  other('');

  const NotificationKind(this.wire);

  final String wire;

  static NotificationKind parse(String? value) {
    for (final kind in values) {
      if (kind != other && kind.wire == value) return kind;
    }

    return other;
  }

  bool get isTask =>
      this != inboxMessage && this != other && wire.startsWith('TASK_');
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.entityType,
    this.entityId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json.strOr('id', ''),
        kind: NotificationKind.parse(json.str('notification_type')),
        title: json.strOr('title', ''),
        body: json.strOr('content', ''),
        createdAt: DateUtilsX.parse(json['created_at']),
        readAt: DateUtilsX.parse(json['read_at']),
        entityType: json.str('related_entity_type'),
        entityId: json.str('related_entity_id'),
      );

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String? entityType;
  final String? entityId;

  bool get isUnread => readAt == null;

  /// The task this notification is about, or null when it points elsewhere.
  ///
  /// Both halves have to agree. A row whose entity type says `task` but carries
  /// no id would otherwise navigate to `/tasks/` and land on a broken screen.
  String? get taskId =>
      (kind.isTask && entityType == 'task' && (entityId ?? '').isNotEmpty)
      ? entityId
      : null;

  AppNotification markedRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? DateTime.now(),
    entityType: entityType,
    entityId: entityId,
  );
}
