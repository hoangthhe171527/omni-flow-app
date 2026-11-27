import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Đợt A1 — thành phần dùng chung của Chuẩn Mobile UI.
void main() {
  Future<void> pump(WidgetTester t, Widget child, {double scale = 1}) =>
      t.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: child),
          ),
        ),
      );

  group('OmniPeriod', () {
    test('tuần bắt đầu thứ Hai, end là đầu kỳ sau', () {
      final w = OmniPeriod.containing(
        OmniPeriodUnit.week,
        DateTime(2026, 11, 25),
      );
      expect(w.start, DateTime(2026, 11, 23));
      expect(w.end, DateTime(2026, 11, 30));
      expect(w.label, '23/11 – 29/11');
      expect(w.contains(DateTime(2026, 11, 29, 23, 59)), isTrue);
      expect(w.contains(DateTime(2026, 11, 30)), isFalse);
    });

    test('tháng / quý / năm: nhãn và bước qua năm', () {
      final m = OmniPeriod.containing(
        OmniPeriodUnit.month,
        DateTime(2026, 12, 9),
      );
      expect(m.label, 'Tháng 12/2026');
      expect(m.next.label, 'Tháng 1/2027');
      final q = OmniPeriod.containing(
        OmniPeriodUnit.quarter,
        DateTime(2026, 11, 2),
      );
      expect(q.label, 'Quý 4 · 2026');
      expect(q.previous.label, 'Quý 3 · 2026');
      expect(q.next.start, DateTime(2027));
      expect(
        OmniPeriod.containing(OmniPeriodUnit.year, DateTime(2026, 5)).label,
        'Năm 2026',
      );
    });
  });

  group('OmniPeriodPicker', () {
    testWidgets('‹ lùi một kỳ; › khoá khi kỳ sau ở tương lai', (t) async {
      OmniPeriod? got;
      final now = OmniPeriod.containing(
        OmniPeriodUnit.month,
        DateTime(2026, 11, 25),
      );
      await pump(
        t,
        OmniPeriodPicker(
          value: now,
          latest: DateTime(2026, 11, 25),
          onChanged: (p) => got = p,
        ),
      );
      expect(find.text('Tháng 11/2026'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Kỳ sau, Tháng 12/2026'));
      expect(got, isNull);
      await t.tap(find.bySemanticsLabel('Kỳ trước, Tháng 10/2026'));
      expect(got?.label, 'Tháng 10/2026');
    });

    testWidgets('chạm tên kỳ → chọn Quý giữ mốc ngày', (t) async {
      OmniPeriod? got;
      await pump(
        t,
        OmniPeriodPicker(
          value: OmniPeriod.containing(
            OmniPeriodUnit.month,
            DateTime(2026, 8, 1),
          ),
          units: const [OmniPeriodUnit.month, OmniPeriodUnit.quarter],
          latest: DateTime(2026, 11, 25),
          onChanged: (p) => got = p,
        ),
      );
      await t.tap(find.bySemanticsLabel('Chọn kỳ, Tháng 8/2026'));
      await t.pumpAndSettle();
      await t.tap(find.text('Quý'));
      await t.pumpAndSettle();
      expect(got?.label, 'Quý 3 · 2026');
    });
  });

  group('showOmniFilterSheet', () {
    testWidgets('số kết quả sống, Đặt lại, áp trả lựa chọn', (t) async {
      OmniFilterSelection? result;
      await pump(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showOmniFilterSheet(
                context: context,
                resultNoun: 'đơn',
                groups: const [
                  OmniFilterGroup(
                    id: 'status',
                    title: 'Trạng thái',
                    options: [
                      OmniFilterOption('unpaid', 'Chưa thu'),
                      OmniFilterOption('paid', 'Đã thu'),
                    ],
                  ),
                  OmniFilterGroup(
                    id: 'owner',
                    title: 'Người phụ trách',
                    multi: true,
                    options: [
                      OmniFilterOption('a', 'Tuấn'),
                      OmniFilterOption('b', 'Minh'),
                    ],
                  ),
                ],
                countResults: (s) => s.isEmpty
                    ? 24
                    : (s['status']?.contains('paid') ?? false)
                    ? 0
                    : 7,
              );
            },
            child: const Text('mở'),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      expect(find.text('Xem 24 đơn'), findsOneWidget);

      await t.tap(find.text('Đã thu'));
      await t.pump();
      expect(find.text('Không có đơn'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Không có đơn'),
            )
            .onPressed,
        isNull,
      );

      await t.tap(find.text('Chưa thu')); // chọn một: thay Đã thu
      await t.tap(find.text('Tuấn'));
      await t.tap(find.text('Minh'));
      await t.pump();
      expect(find.text('Xem 7 đơn'), findsOneWidget);

      await t.tap(find.text('Xem 7 đơn'));
      await t.pumpAndSettle();
      expect(result, {
        'status': {'unpaid'},
        'owner': {'a', 'b'},
      });
      expect(omniFilterCount(result!), 3);
    });

    testWidgets(
      'Đặt lại bỏ mọi lựa chọn (đầu bảng lọc thống nhất 26/11/2026)',
      (t) async {
        await pump(
          t,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showOmniFilterSheet(
                context: context,
                initial: const {
                  's': {'x'},
                },
                groups: const [
                  OmniFilterGroup(
                    id: 's',
                    title: 'S',
                    options: [OmniFilterOption('x', 'X')],
                  ),
                ],
                countResults: (s) => s.isEmpty ? 10 : 2,
              ),
              child: const Text('mở'),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        expect(find.text('Xem 2 kết quả'), findsOneWidget);
        await t.tap(find.text('Đặt lại'));
        await t.pump();
        expect(find.text('Xem 10 kết quả'), findsOneWidget);
      },
    );
  });

  group('OmniEmptyState', () {
    testWidgets('trống thật: nút chính; trống do lọc: chỉ nút chữ Bỏ lọc', (
      t,
    ) async {
      var cleared = false;
      await pump(
        t,
        Column(
          children: [
            const OmniEmptyState(
              title: 'Chưa có khoản chi',
              actionLabel: 'Thêm khoản chi',
            ),
            OmniEmptyState.filtered(
              title: 'Không có đơn khớp bộ lọc',
              onAction: () => cleared = true,
            ),
          ],
        ),
      );
      expect(
        find.widgetWithText(FilledButton, 'Thêm khoản chi'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(TextButton, 'Bỏ lọc'));
      expect(cleared, isTrue);
    });

    testWidgets('lỗi: Thử lại là nút phụ, không phải nút chính', (t) async {
      await pump(t, OmniErrorView(error: Exception('x'), onRetry: () {}));
      expect(find.widgetWithText(OutlinedButton, 'Thử lại'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('Phản hồi', () {
    testWidgets('OmniBanner: câu + nút chữ', (t) async {
      var tapped = false;
      await pump(
        t,
        OmniBanner(
          tone: OmniBannerTone.warning,
          title: 'Đang ngoại tuyến',
          message: 'Hiện dữ liệu lúc 09:42',
          actionLabel: 'Thử lại',
          onAction: () => tapped = true,
        ),
      );
      expect(find.textContaining('Hiện dữ liệu lúc 09:42'), findsOneWidget);
      await t.tap(find.text('Thử lại'));
      expect(tapped, isTrue);
    });

    testWidgets('showOmniToast: toast mới thay toast cũ, có Hoàn tác', (
      t,
    ) async {
      var undone = false;
      await pump(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showOmniToast(context, 'Đã xoá khoản 1');
              showOmniToast(
                context,
                'Đã xoá khoản 2',
                actionLabel: 'Hoàn tác',
                onAction: () => undone = true,
              );
            },
            child: const Text('xoá'),
          ),
        ),
      );
      await t.tap(find.text('xoá'));
      await t.pumpAndSettle();
      expect(find.text('Đã xoá khoản 1'), findsNothing);
      expect(find.text('Đã xoá khoản 2'), findsOneWidget);
      await t.tap(find.text('Hoàn tác'));
      expect(undone, isTrue);
    });
  });

  testWidgets('OmniTotalCard: số chính không thu nhỏ ở chữ 2×, vẫn đủ số', (
    t,
  ) async {
    await pump(
      t,
      const Padding(
        padding: EdgeInsets.all(16),
        child: OmniTotalCard(label: 'Còn phải thu', amount: '128.450.000.000đ'),
      ),
      scale: 2,
    );
    expect(find.byType(FittedBox), findsNothing);
    // Chữ 2×: số giữ cỡ 32, vẫn là MỘT chuỗi đủ số (xuống dòng nếu cần),
    // không thu nhỏ, không tràn.
    final text = t.widget<Text>(find.text('128.450.000.000đ'));
    expect(text.style!.fontSize, 32);
    expect(text.maxLines, isNull);
    expect(t.takeException(), isNull);
  });
}
