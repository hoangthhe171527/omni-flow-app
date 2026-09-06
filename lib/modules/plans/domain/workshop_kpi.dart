import '../../../core/utils/json.dart';

/// Một mốc thưởng: bao nhiêu cây thì được bao nhiêu triệu.
class BonusTier {
  const BonusTier({required this.count, required this.bonus});

  final int count;

  /// Triệu đồng. Đơn vị do tài liệu xưởng đặt (§1), không phải do app chọn.
  final int bonus;
}

/// Mốc kế tiếp, kèm khoảng cách còn lại.
class NextTier extends BonusTier {
  const NextTier({
    required super.count,
    required super.bonus,
    required this.remaining,
  });

  final int remaining;
}

/// "Tháng này xong bao nhiêu cây, còn bao xa tới mốc thưởng."
///
/// §B4 của `TNP_PIANO_WORKSHOP_FLOW.md`: con số này thay hoàn toàn việc đếm
/// tay trên Zalo, và cuối tháng chủ xưởng đọc nó để trao thưởng.
///
/// Một lỗi ở đây không hiện ra thành màn trắng. Nó hiện ra thành một con số
/// sai, trông y hệt một con số đúng — nên mọi trường đều có mặc định an toàn
/// và mọi phép chia đều canh mẫu số.
class WorkshopKpi {
  const WorkshopKpi({
    required this.delivered,
    required this.reachedBonus,
    required this.daysLeft,
    required this.tiers,
    required this.isConfigured,
    this.nextTier,
  });

  factory WorkshopKpi.fromJson(Map<String, dynamic> json) {
    final next = json.child('next_tier');

    final tiers =
        json
            .child('tiers')
            .entries
            .map(
              (e) => BonusTier(
                count: int.tryParse(e.key) ?? 0,
                bonus: e.value is num ? (e.value as num).toInt() : 0,
              ),
            )
            .where((t) => t.count > 0)
            .toList()
          // JSON object không đảm bảo thứ tự khoá, và một bảng mốc hiện lộn
          // xộn đọc như dữ liệu hỏng.
          ..sort((a, b) => a.count.compareTo(b.count));

    return WorkshopKpi(
      delivered: json.intOr('delivered'),
      reachedBonus: json.intOr('reached_bonus'),
      daysLeft: json.intOr('days_left'),
      tiers: tiers,
      // Rỗng nghĩa là chưa kế hoạch nào đánh dấu cột đích, và `delivered` sẽ
      // luôn là 0. Một số 0 vì chưa cấu hình trông y hệt một số 0 vì chưa làm
      // được cây nào — widget phải nói ra là cái nào.
      isConfigured: json.strList('counting_sections').isNotEmpty,
      nextTier: next.isEmpty
          ? null
          : NextTier(
              count: next.intOr('count'),
              bonus: next.intOr('bonus'),
              remaining: next.intOr('remaining'),
            ),
    );
  }

  final int delivered;

  /// Triệu đồng của mốc CAO NHẤT đã đạt. 0 khi chưa tới mốc đầu tiên.
  final int reachedBonus;

  final int daysLeft;
  final List<BonusTier> tiers;
  final NextTier? nextTier;

  /// Đã có kế hoạch nào đánh dấu cột đích chưa.
  final bool isConfigured;

  /// Đã vượt mốc cao nhất — tin tốt, không phải lỗi.
  bool get isAtTopTier => nextTier == null && tiers.isNotEmpty;

  /// Số cây cần xong mỗi ngày để kịp mốc kế tiếp.
  ///
  /// null khi không còn mốc nào, hoặc khi hết ngày: chia cho 0 cho ra Infinity,
  /// và Infinity in thẳng ra màn hình.
  double? get perDayNeeded {
    final next = nextTier;
    if (next == null || daysLeft <= 0) return null;

    return next.remaining / daysLeft;
  }

  /// 0.0–1.0 tới mốc kế tiếp. 1.0 khi đã vượt mốc cao nhất.
  double get progressToNext {
    final next = nextTier;
    if (next == null) return 1;
    if (next.count <= 0) return 0;

    return (delivered / next.count).clamp(0, 1);
  }
}
