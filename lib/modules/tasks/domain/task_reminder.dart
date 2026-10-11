import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Một lời nhắc theo giờ tự chọn (`GET|POST /tasks/{id}/reminders`,
/// `TaskReminderDTO::toArray` + `PeopleDirectory::decorateMany`).
///
/// `remind_at` server trả ISO UTC (`…Z`); app hiện theo giờ VN.
class TaskReminder {
  const TaskReminder({
    required this.id,
    required this.remindAt,
    this.audience = 'me',
    this.status = 'pending',
    this.sentAt,
    this.createdBy,
    this.createdByName,
  });

  factory TaskReminder.fromJson(Map<String, dynamic> json) => TaskReminder(
    id: json.strOr('id', ''),
    remindAt: DateUtilsX.parse(json['remind_at']),
    audience: json.strOr('audience', 'me'),
    status: json.strOr('status', 'pending'),
    sentAt: DateUtilsX.parse(json['sent_at']),
    createdBy: json.str('created_by'),
    createdByName: json.str('created_by_name'),
  );

  final String id;
  final DateTime? remindAt;

  /// `me` (chỉ người đặt) hoặc `everyone` (mọi người làm và theo dõi).
  final String audience;

  /// `pending` | `sent` | `skipped`.
  final String status;
  final DateTime? sentAt;
  final String? createdBy;
  final String? createdByName;

  bool get isPending => status == 'pending';

  bool get forEveryone => audience == 'everyone';
}

/// Một tệp người dùng chọn để gửi KÈM bình luận (multipart `files[]`).
class CommentUpload {
  const CommentUpload({
    required this.path,
    required this.name,
    required this.isImage,
    this.size,
  });

  final String path;
  final String name;
  final bool isImage;

  /// Byte; null = không đọc được cỡ (server vẫn kiểm).
  final int? size;
}
