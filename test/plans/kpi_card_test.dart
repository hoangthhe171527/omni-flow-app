import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/widgets/kpi_card.dart';

/// Thẻ KPI phải phân biệt được ba lý do khác nhau cho cùng một màn hình trống.
///
/// Bảng mốc thưởng vừa chuyển từ config của bản triển khai sang cấu hình của
/// từng workspace. Trước đó bảng luôn có sẵn nên "chưa khai mốc" là chuyện
/// không thể xảy ra; bây giờ nó là trạng thái bình thường của mọi workspace
/// mới — và nó cho `nextTier == null`, y hệt "đã vượt mốc cao nhất".
void main() {
  WorkshopKpi kpi({
    int delivered = 12,
    List<BonusTier> tiers = const [BonusTier(count: 35, bonus: 3)],
    NextTier? next,
    bool configured = true,
    int rework = 0,
  }) => WorkshopKpi(
    delivered: delivered,
    reachedBonus: 0,
    daysLeft: 10,
    tiers: tiers,
    isConfigured: configured,
    rework: rework,
    nextTier: next,
  );

  /// [past] mở thẻ ở một tháng ĐÃ KHÉP.
  ///
  /// `onNextMonth == null` là tín hiệu duy nhất cho "đang ở tháng hiện tại" —
  /// mũi tên tới tắt và tháng đang chạy luôn là cùng một sự thật, nên thẻ đọc
  /// một cờ chứ không hai.
  Future<void> show(
    WidgetTester tester,
    WorkshopKpi value, {
    bool past = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: KpiCard(
            kpi: value,
            month: DateTime(2026, past ? 8 : 9),
            onPrevMonth: () {},
            onNextMonth: past ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa khai mốc: nói ra, KHÔNG chúc mừng', (tester) async {
    await show(tester, kpi(tiers: const []));

    expect(find.text('Workspace chưa khai bảng mốc thưởng.'), findsOneWidget);
    expect(find.text('Đã đạt mốc cao nhất của tháng.'), findsNothing);
    // Không có mốc thì không có gì để chạy tới — thanh đầy 100% là lời khen
    // bịa ra.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('có mốc mà hết mốc kế tiếp: đã đạt mốc cao nhất', (tester) async {
    await show(tester, kpi(delivered: 99));

    expect(find.text('Đã đạt mốc cao nhất của tháng.'), findsOneWidget);
  });

  testWidgets('chưa đánh dấu nhóm việc đích: một DÒNG, không phải một khối', (
    tester,
  ) async {
    // Số 0 vì chưa cấu hình trông y hệt số 0 vì tháng này chưa xong việc nào,
    // nên vẫn phải nói ra. Nhưng câu cũ chiếm cả một thẻ ở ĐẦU màn Dòng việc —
    // đúng chỗ dễ thấy nhất của ngày — để nói một điều người thợ không làm gì
    // được và người quản đốc chỉ cần đọc một lần.
    await show(tester, kpi(delivered: 0, configured: false));

    expect(
      find.textContaining('nên chưa đếm được việc nào hoàn thành'),
      findsNothing,
    );
    expect(find.text('Đánh dấu nhóm việc đích'), findsOneWidget);

    final height = tester.getSize(find.byType(KpiCard)).height;
    expect(
      height,
      lessThan(64),
      reason: 'Một dòng bấm được, không phải một thẻ cao bằng thẻ KPI thật.',
    );
  });

  testWidgets('dòng đó bấm được và dẫn tới chỗ sửa', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: KpiCard(
            kpi: kpi(delivered: 0, configured: false),
            month: DateTime(2026, 9),
            onConfigure: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Đánh dấu nhóm việc đích'));

    expect(tapped, isTrue);
  });

  testWidgets('có mốc kế tiếp: hiện khoảng cách và nhịp cần thiết', (
    tester,
  ) async {
    await show(
      tester,
      kpi(next: const NextTier(count: 35, bonus: 3, remaining: 23)),
    );

    expect(find.textContaining('Còn 23 việc tới mốc 35'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets("số lần làm lại hiện ra khi có, ẩn khi bằng 0", (tester) async {
    // §B3: "hệ thống tự đếm rework". Một số 0 khoe ra không nói thêm được gì,
    // còn một con số khác 0 thì là thứ đáng bàn trong cuộc họp cuối tháng.
    await show(tester, kpi(rework: 3));
    expect(find.text("3 lần phải làm lại trong tháng"), findsOneWidget);

    await show(tester, kpi());
    expect(find.textContaining("phải làm lại"), findsNothing);
  });
}
