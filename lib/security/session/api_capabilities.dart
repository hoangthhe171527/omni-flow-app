import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

/// Tên khả năng API trong `/auth/context` → `api_capabilities`.
///
/// MỘT chỗ duy nhất app hỏi "bản API đang chạy đã có tính năng này chưa".
/// Trước đây mỗi tính năng tự đoán từ một khoá đi kèm trong JSON (`pinned`,
/// `is_favorite`…); đoán như vậy vỡ ngay khi API lùi bản mà dữ liệu cũ vẫn
/// còn khoá. Thiếu tên trong danh sách = chưa có = ẩn nút.
abstract final class ApiCapability {
  static const taskPin = 'tasks.pin';
  static const taskLock = 'tasks.lock';
  static const taskFollow = 'tasks.follow';
  static const taskAssignedBy = 'tasks.assigned_by';
  static const taskCompletedAt = 'tasks.completed_at';
  static const projectFavorite = 'projects.favorite';
  static const projectTransferOwner = 'projects.transfer_owner';
  static const taskLabelsForReaders = 'system_options.task_labels';
  static const taskCopy = 'tasks.copy';
  static const taskReminders = 'tasks.reminders';
  static const checklistMove = 'tasks.checklist_move';
  static const subtaskFields = 'tasks.subtask_fields';
  static const commentAttachments = 'tasks.comment_attachments';
}

/// `ref.watch(apiSupportsProvider(ApiCapability.taskPin))`. Dựng lại khi phiên
/// đổi (đăng nhập lại, đổi workspace, tải lại `/auth/context`).
final apiSupportsProvider = Provider.family<bool, String>(
  (ref, name) => ref.watch(sessionProvider.select((s) => s.apiSupports(name))),
);
