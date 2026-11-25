import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/clock_state.dart';

/// Hàng chờ lượt chấm khi mất mạng (spec 03 §5.2: "mất mạng vẫn chấm được,
/// có mạng tự gửi").
///
/// Lưu bằng `SharedPreferences` có sẵn (`core/storage`), một khoá cho mỗi
/// (công ty, người): đổi công ty hay đăng nhập người khác trên cùng máy không
/// gửi nhầm lượt của người kia. Mỗi lượt mang `client_at` lúc bấm và
/// `offline: true` — server tin giờ máy nếu lệch ≤ 12 giờ.
class PunchQueue {
  PunchQueue(this._prefs, {required this.tenantId, required this.membershipId});

  final SharedPreferences _prefs;
  final String tenantId;
  final String membershipId;

  String get _key => 'hr.punch_queue.$tenantId.$membershipId';

  List<Map<String, dynamic>> get items {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded.whereType<Map>()) e.cast<String, dynamic>(),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Loại của các lượt còn chờ, theo thứ tự (`in`, `out`).
  List<String> get kinds => [for (final i in items) '${i['kind']}'];

  bool get isEmpty => items.isEmpty;

  Future<void> add(Map<String, dynamic> punch) => _save([
    ...items,
    {...punch, 'offline': true},
  ]);

  Future<void> _save(List<Map<String, dynamic>> list) => list.isEmpty
      ? _prefs.remove(_key)
      : _prefs.setString(_key, jsonEncode(list));

  /// Gửi lần lượt từ cũ tới mới.
  ///
  /// - Thành công → bỏ khỏi hàng.
  /// - Bị từ chối (422: máy lạ, ngoài vùng, khoá tháng) → cũng bỏ: server đã
  ///   lưu lượt đó làm dữ liệu gốc kèm mã lý do; gửi lại chỉ nhân bản nó. Trả
  ///   về lời từ chối cuối để màn báo.
  /// - Vẫn mất mạng / lỗi máy chủ → dừng, giữ nguyên phần còn lại.
  Future<PunchFlushResult> flush(
    Future<void> Function(Map<String, dynamic> body) send,
  ) async {
    var pending = items;
    var sent = 0;
    PunchRejection? rejected;
    while (pending.isNotEmpty) {
      try {
        await send(pending.first);
        sent++;
      } catch (error) {
        final rejection = PunchRejection.fromError(error);
        if (rejection == null) break;
        rejected = rejection;
      }
      pending = pending.sublist(1);
      await _save(pending);
    }
    return PunchFlushResult(
      sent: sent,
      remaining: pending.length,
      rejected: rejected,
    );
  }
}

class PunchFlushResult {
  const PunchFlushResult({
    required this.sent,
    required this.remaining,
    this.rejected,
  });

  final int sent;
  final int remaining;
  final PunchRejection? rejected;
}
