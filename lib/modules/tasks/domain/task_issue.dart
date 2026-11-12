import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Cờ vấn đề trên việc (TNP_DON_HANG_THEO_CAY §4.3): thợ báo (ghi chú + ảnh),
/// chỉ quản lý kế hoạch tắt ("Đã xử lý"). Đóng việc không tắt cờ.
class TaskIssue {
  const TaskIssue({
    required this.note,
    this.commentId = '',
    this.photoUrls = const [],
    this.by,
    this.byName,
    this.at,
  });

  /// `null` khi API không gửi khoá, gửi `null`, hoặc thiếu `note` (dữ liệu
  /// hỏng) — coi như không có cờ. Ảnh không có `url` thì bỏ.
  static TaskIssue? parse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final note = j['note'];
    if (note is! String) return null;
    return TaskIssue(
      note: note,
      commentId: j.strOr('comment_id', ''),
      photoUrls: [for (final p in j.mapList('photos')) ?p.str('url')],
      by: j.str('by'),
      byName: j.str('by_name'),
      at: DateUtilsX.parse(j['at']),
    );
  }

  final String commentId;
  final String note;
  final List<String> photoUrls;
  final String? by;
  final String? byName;
  final DateTime? at;
}
