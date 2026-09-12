import 'package:flutter/widgets.dart';

/// [GlobalKey] cho từng tin trên màn chat — thứ `Scrollable.ensureVisible`
/// cần để cuộn tới một kết quả tìm kiếm.
///
/// Trước đây là một `Map` trong State không bao giờ dọn: mở một hội thoại dài,
/// kéo lên vài trang, tìm vài lần — map giữ key của MỌI tin từng đi qua màn
/// hình cho đến khi trang bị huỷ, và mỗi GlobalKey là một mục trong registry
/// của framework. Một refresh sau quãng offline dài còn thay cả cửa sổ tin, nên
/// phần lớn map là tin không còn trên màn.
///
/// Trang gọi [prune] mỗi khi state đổi với tập id còn sống (tin đang hiển thị
/// + kết quả tìm kiếm). Key của tin còn sống được GIỮ nguyên: cấp lại key cho
/// một tin còn trên màn là tháo rồi dựng lại widget của nó không vì lý do gì.
class MessageKeyRegistry {
  final Map<String, GlobalKey> _keys = {};

  int get length => _keys.length;

  /// Key của [id], cấp mới nếu chưa có. Chỉ gọi từ `itemBuilder`, nên key chỉ
  /// tồn tại cho tin thực sự được dựng.
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Key của [id] nếu đã cấp; không tự cấp — tra cứu để cuộn không được làm
  /// registry phình ra.
  GlobalKey? lookup(String id) => _keys[id];

  /// Bỏ mọi key ngoài [liveIds].
  void prune(Iterable<String> liveIds) {
    final keep = liveIds is Set<String> ? liveIds : liveIds.toSet();
    _keys.removeWhere((id, _) => !keep.contains(id));
  }
}
