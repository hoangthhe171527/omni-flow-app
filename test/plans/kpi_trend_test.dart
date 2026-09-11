import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/widgets/kpi_card.dart';

/// "28 việc xong" — nhiều hay ít? Con số một mình không trả lời được.
///
/// Mọi bảng số liệu trên thị trường đặt cạnh con số một mốc so sánh, và mốc
/// tự nhiên nhất của xưởng là chính tháng trước: "+6 so với tháng 8" nói
/// "đang khá hơn" mà không cần biết mốc thưởng là bao nhiêu. Hướng đi bằng
/// biểu tượng, không bằng màu — đỏ/xanh ở đây vừa là màu thương hiệu thứ hai
/// vừa vô hình với người mù màu lục-đỏ.
void main() {
  WorkshopKpi kpi({int delivered = 28, List<BonusTier>? tiers}) => WorkshopKpi(
    delivered: delivered,
    reachedBonus: 0,
    daysLeft: 10,
    tiers: tiers ?? const [BonusTier(count: 35, bonus: 3)],
    isConfigured: true,
    nextTier: const NextTier(count: 35, bonus: 3, remaining: 7),
  );

  Future<void> show(
    WidgetTester tester,
    WorkshopKpi value, {
    int? previousDelivered,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: KpiCard(
            kpi: value,
            month: DateTime(2026, 9),
            previousDelivered: previousDelivered,
            onPrevMonth: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('dòng so với tháng trước', () {
    testWidgets('nhiều hơn: dấu cộng và mũi tên lên', (tester) async {
      await show(tester, kpi(delivered: 28), previousDelivered: 22);

      expect(find.text('+6 so với tháng 8'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('ít hơn: dấu trừ và mũi tên xuống', (tester) async {
      await show(tester, kpi(delivered: 20), previousDelivered: 23);

      expect(find.text('−3 so với tháng 8'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });

    testWidgets('bằng nhau: nói "bằng", không phải "+0"', (tester) async {
      await show(tester, kpi(delivered: 22), previousDelivered: 22);

      expect(find.text('Bằng tháng 8'), findsOneWidget);
      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
    });

    testWidgets('tháng 1 so với tháng 12, không phải "tháng 0"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: KpiCard(
              kpi: kpi(delivered: 10),
              month: DateTime(2027, 1),
              previousDelivered: 4,
              onPrevMonth: () {},
              onNextMonth: () {},
            ),
          ),
        ),
      );

      expect(find.text('+6 so với tháng 12'), findsOneWidget);
    });

    testWidgets('không có số tháng trước thì KHÔNG có dòng, không có "+28"', (
      tester,
    ) async {
      // Lượt gọi tháng trước hỏng hoặc chưa về. So với một con số không có là
      // bịa ra một xu hướng.
      await show(tester, kpi(delivered: 28));

      expect(find.textContaining('so với tháng'), findsNothing);
      expect(find.textContaining('Bằng tháng'), findsNothing);
    });

    testWidgets('không tô đỏ khi giảm: hướng đi nằm ở biểu tượng', (
      tester,
    ) async {
      await show(tester, kpi(delivered: 20), previousDelivered: 23);

      final line = tester.widget<Text>(find.text('−3 so với tháng 8'));
      final scheme = Theme.of(
        tester.element(find.byType(KpiCard)),
      ).colorScheme;

      expect(line.style?.color, scheme.onSurfaceVariant);
    });
  });

  testWidgets('câu "chưa khai bảng mốc" là chữ nhỏ, không tranh với con số', (
    tester,
  ) async {
    // Câu này dành cho người quản trị đọc MỘT lần; con số dành cho cả xưởng
    // đọc mỗi ngày. Cùng cỡ với dòng mốc thưởng thì nó tranh mắt với thứ
    // thẻ này sinh ra để nói.
    await show(tester, kpi(tiers: const []));

    final sentence = tester.widget<Text>(
      find.text('Workspace chưa khai bảng mốc thưởng.'),
    );
    final theme = Theme.of(tester.element(find.byType(KpiCard))).textTheme;

    expect(sentence.style?.fontSize, theme.labelSmall?.fontSize);
  });

  test('provider tháng trước hỏi API đúng tháng liền trước tháng đang xem', () async {
    // Tháng đang xem là tháng 1 thì tháng trước là tháng 12 NĂM TRƯỚC —
    // `DateTime(y, 0)` tự lùi năm, nhưng đây là chỗ đáng có một bài kiểm.
    final api = _MonthRecorder();
    final container = ProviderContainer(
      overrides: [
        plansApiProvider.overrideWithValue(api),
        kpiMonthProvider.overrideWith((ref) => DateTime(2026, 1)),
      ],
    );
    addTearDown(container.dispose);

    final previous = await container.read(kpiPreviousDeliveredProvider.future);

    expect(api.months, [DateTime(2025, 12)]);
    expect(previous, 22);
  });
}

class _MonthRecorder implements PlansApi {
  final months = <DateTime?>[];

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async {
    months.add(month);

    return WorkshopKpi(
      delivered: month?.month == 12 ? 22 : 28,
      reachedBonus: 0,
      daysLeft: 0,
      tiers: const [],
      isConfigured: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
