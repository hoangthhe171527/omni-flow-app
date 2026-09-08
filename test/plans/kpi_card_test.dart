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
  }) => WorkshopKpi(
    delivered: delivered,
    reachedBonus: 0,
    daysLeft: 10,
    tiers: tiers,
    isConfigured: configured,
    nextTier: next,
  );

  Future<void> show(WidgetTester tester, WorkshopKpi value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(body: KpiCard(kpi: value)),
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

  testWidgets('chưa đánh dấu nhóm việc đích: nói cách sửa', (tester) async {
    // Số 0 vì chưa cấu hình trông y hệt số 0 vì tháng này chưa xong việc nào.
    await show(tester, kpi(delivered: 0, configured: false));

    expect(find.textContaining('Chưa có kế hoạch nào'), findsOneWidget);
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
}
