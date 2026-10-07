import 'dart:async';

import '../../../core/utils/media_url.dart';

/// Nghỉ giữa hai lượt tự tải lại tin vì media lỗi (MS-I24).
///
/// Link media Hộp thư ký 12 giờ. Một màn chat mở qua đêm thì MỌI tệp trong đó
/// hết hạn cùng lúc, nên lượt tải lại phải được gộp và phải có khoảng nghỉ:
/// không có nó, một tệp đã bị xoá phía server (403 mãi mãi) thành một vòng
/// lặp gọi API.
const mediaReloadCooldown = Duration(minutes: 10);

/// Xin URL ký mới cho một tệp media đã hết hạn.
///
/// Không có đường API riêng để ký lại MỘT URL: URL ký được dựng trong
/// `InboxController` khi tin được đọc ra. Nên "xin lại" ở đây = tải lại cửa sổ
/// tin đang giữ ([onReload]) rồi tra URL mới của đúng tệp đó ([lookup]).
///
/// Ba điều lớp này giữ, và là lý do nó không nằm rải trong widget:
///
///  * **Đúng MỘT lượt cho mỗi tệp.** Tệp đã xin một lần mà URL mới cũng hỏng
///    thì rơi về trạng thái lỗi sẵn có, không xin nữa. Tra theo
///    [mediaCacheKey] nên hai URL chỉ khác chữ ký được tính là MỘT tệp.
///  * **Một lượt tải lại cho cả loạt.** Mười ảnh cùng hết hạn trong một khung
///    hình là một lượt gọi API, không phải mười.
///  * **Lượt tải lại hỏng không tiêu lượt.** Mất mạng giữa đường thì tệp đó
///    vẫn còn quyền xin lại khi mạng về.
class MediaUrlResolver {
  MediaUrlResolver({
    required this.onReload,
    required this.lookup,
    DateTime Function()? clock,
    Duration cooldown = mediaReloadCooldown,
  }) : _clock = clock ?? DateTime.now,
       _cooldown = cooldown;

  /// Tải lại cửa sổ tin đang giữ (URL trong đó được ký mới).
  final Future<void> Function() onReload;

  /// URL mới của tệp này sau lượt tải lại, hoặc null khi nó không còn.
  final String? Function(String url) lookup;

  final DateTime Function() _clock;
  final Duration _cooldown;

  final Set<String> _attempted = {};
  Future<bool>? _inFlight;
  DateTime? _lastReload;

  /// URL ký mới cho [url], hoặc null khi không lấy được — gồm cả trường hợp
  /// tệp này đã xin một lần rồi (lần hỏng thứ hai là trạng thái lỗi).
  ///
  /// [force] cho nút "Tải lại" của người dùng: một lần bấm là một lượt, không
  /// thể thành vòng lặp.
  Future<String?> refresh(String url, {bool force = false}) async {
    final key = mediaCacheKey(url);
    if (!_attempted.add(key) && !force) return null;

    if (!await _reload(force: force)) {
      // Không tải lại được: giữ quyền xin lại cho tệp này.
      _attempted.remove(key);
      return null;
    }
    return lookup(url);
  }

  /// Chỉ tải lại cửa sổ tin, không tra URL nào — đường của ẢNH, nơi URL mới
  /// tới widget qua `didUpdateWidget` chứ không qua giá trị trả về.
  Future<void> reloadAll({bool force = false}) => _reload(force: force);

  Future<bool> _reload({required bool force}) async {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final last = _lastReload;
    if (!force && last != null && _clock().difference(last) < _cooldown) {
      return false;
    }

    final completer = Completer<bool>();
    _inFlight = completer.future;
    try {
      await onReload();
      _lastReload = _clock();
      completer.complete(true);
    } catch (_) {
      // Giữ nguyên thứ đang hiện; mỗi tệp còn nút tải lại riêng.
      completer.complete(false);
    } finally {
      _inFlight = null;
    }
    return completer.future;
  }
}
