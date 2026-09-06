import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';

/// Con số trên bảng thưởng.
///
/// §B4 của tài liệu xưởng: nó thay hoàn toàn việc đếm tay trên Zalo, và cuối
/// tháng chủ đọc nó để trao thưởng. Một lỗi phân tích ở đây không hiện ra
/// thành màn trắng — nó hiện ra thành một con số sai, trông y hệt một con số
/// đúng.
void main() {
  /// Một phản hồi NHẤT QUÁN: `remaining` dẫn xuất từ `delivered`, đúng như
  /// API tính (`count - delivered`). Bản đầu của helper này để `remaining`
  /// cố định, nên bài "nhịp cần thiết" đọc ra 2.3 thay vì 0.5 — dữ liệu test
  /// sai chứ không phải code sai, và một fixture không thể tồn tại thật thì
  /// không chứng minh được gì.
  Map<String, dynamic> payload({
    int delivered = 12,
    int reached = 0,
    int? nextCount = 35,
    Map<String, dynamic> tiers = const {'35': 3, '40': 6},
    List<String> sections = const ['s4'],
    int daysLeft = 18,
  }) {
    final next = nextCount == null
        ? null
        : {'count': nextCount, 'bonus': 3, 'remaining': nextCount - delivered};

    return {
      'from': '2026-09-01T00:00:00+07:00',
      'until': '2026-10-01T00:00:00+07:00',
      'delivered': delivered,
      'reached_bonus': reached,
      'next_tier': next,
      'tiers': tiers,
      'days_left': daysLeft,
      'counting_sections': sections,
    };
  }

  test('đọc được một phản hồi đầy đủ', () {
    final kpi = WorkshopKpi.fromJson(payload());

    expect(kpi.delivered, 12);
    expect(kpi.reachedBonus, 0);
    expect(kpi.nextTier?.count, 35);
    expect(kpi.nextTier?.bonus, 3);
    expect(kpi.nextTier?.remaining, 23);
    expect(kpi.daysLeft, 18);
  });

  test('vượt mốc cao nhất là tin tốt, không phải lỗi', () {
    final kpi = WorkshopKpi.fromJson(
      payload(delivered: 99, reached: 25, nextCount: null),
    );

    expect(kpi.nextTier, isNull);
    expect(
      kpi.isAtTopTier,
      isTrue,
      reason: 'Widget hiện "đã đạt mốc cao nhất", không phải một ô trống.',
    );
  });

  test('chưa đánh dấu cột đích thì con số 0 KHÔNG có nghĩa là chưa làm gì', () {
    final kpi = WorkshopKpi.fromJson(payload(delivered: 0, sections: const []));

    expect(
      kpi.isConfigured,
      isFalse,
      reason:
          'Một số 0 vì chưa cấu hình trông y hệt một số 0 vì chưa làm được cây '
          'nào. Widget phải nói ra là cái nào.',
    );
  });

  test('đã đánh dấu cột đích thì 0 nghĩa là thật sự chưa xong cây nào', () {
    final kpi = WorkshopKpi.fromJson(payload(delivered: 0));

    expect(kpi.isConfigured, isTrue);
  });

  test('nhịp cần thiết: còn bao nhiêu cây trên bao nhiêu ngày', () {
    final kpi = WorkshopKpi.fromJson(payload(delivered: 30, daysLeft: 10));

    // Còn 5 cây (35 − 30) trong 10 ngày. Đây là con số §B4 gọi là "nhịp cần
    // thiết so với ngày còn lại".
    expect(kpi.perDayNeeded, closeTo(0.5, 0.001));
  });

  test('hết ngày mà chưa tới mốc thì nhịp là null, không phải vô cực', () {
    final kpi = WorkshopKpi.fromJson(payload(delivered: 30, daysLeft: 0));

    expect(
      kpi.perDayNeeded,
      isNull,
      reason: 'Chia cho 0 ngày cho ra Infinity, và Infinity in ra màn hình.',
    );
  });

  test('đã đạt mốc cao nhất thì không còn nhịp nào để tính', () {
    final kpi = WorkshopKpi.fromJson(payload(delivered: 99, nextCount: null));

    expect(kpi.perDayNeeded, isNull);
  });

  test('tiến độ tới mốc kế tiếp nằm trong 0..1', () {
    expect(WorkshopKpi.fromJson(payload(delivered: 0)).progressToNext, 0);
    expect(
      WorkshopKpi.fromJson(payload(delivered: 30)).progressToNext,
      closeTo(30 / 35, 0.001),
    );
    expect(
      WorkshopKpi.fromJson(
        payload(delivered: 99, nextCount: null),
      ).progressToNext,
      1,
    );
  });

  test('phản hồi thiếu trường vẫn đọc được, không ném lỗi', () {
    // Tài liệu Mongo không có lược đồ và API đổi được. Một widget ném lỗi ở
    // đây là màn Timeline trắng, chứ không phải một widget thiếu số.
    final kpi = WorkshopKpi.fromJson({});

    expect(kpi.delivered, 0);
    expect(kpi.nextTier, isNull);
    expect(kpi.isConfigured, isFalse);
  });

  test('bảng mốc đọc theo thứ tự tăng dần dù JSON trả về lộn xộn', () {
    final kpi = WorkshopKpi.fromJson(
      payload(tiers: const {'50': 10, '35': 3, '40': 6}),
    );

    expect(kpi.tiers.map((t) => t.count), [35, 40, 50]);
    expect(kpi.tiers.map((t) => t.bonus), [3, 6, 10]);
  });
}
