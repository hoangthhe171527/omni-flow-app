import '../../../core/error/app_exception.dart';
import '../data/inbox_api.dart';

/// Kết quả một lượt gán hàng loạt.
class BulkAssignOutcome {
  const BulkAssignOutcome({
    required this.done,
    required this.skipped,
    this.error,
  });

  /// Số hội thoại đã gán xong.
  final int done;

  /// Số hội thoại API từ chối bằng 422 — hội thoại Zalo/Facebook CÁ NHÂN chỉ
  /// thuộc chủ tài khoản kết nối (Đợt 5 A9), không giao cho người khác được.
  final int skipped;

  /// Lỗi thật đầu tiên (mạng, 5xx, quyền…). Có lỗi này thì giữ lựa chọn để
  /// người dùng thử lại.
  final AppException? error;

  /// Câu báo cho người dùng.
  String get message {
    if (error case final e?) {
      return skipped > 0 || done > 0
          ? 'Đã gán $done, bỏ qua $skipped hội thoại cá nhân. ${e.message}'
          : e.message;
    }
    if (skipped > 0) return 'Đã gán $done, bỏ qua $skipped hội thoại cá nhân.';
    return 'Đã gán $done hội thoại.';
  }
}

/// Gán [ids] cho [assigneeId], từng hội thoại một, KHÔNG dừng ở lỗi đầu.
///
/// Trước đây một 422 (hội thoại cá nhân) giữa danh sách làm cả lượt dừng lại
/// và báo lỗi: các hội thoại phía sau không được gán, còn những hội thoại phía
/// trước đã gán thì danh sách không làm mới — người dùng tưởng không có gì
/// xảy ra.
Future<BulkAssignOutcome> bulkAssign(
  InboxApi api,
  List<String> ids,
  String? assigneeId, {
  String? note,
}) async {
  var done = 0;
  var skipped = 0;
  AppException? error;
  for (final id in ids) {
    try {
      await api.assign(id, assigneeId, note: note);
      done++;
    } on ValidationException {
      skipped++;
    } on AppException catch (e) {
      error ??= e;
    }
  }

  return BulkAssignOutcome(done: done, skipped: skipped, error: error);
}
