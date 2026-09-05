import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_status_chip.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.dark
          ? OmniTheme.dark(TargetPlatform.android)
          : OmniTheme.light(TargetPlatform.android),
      home: Scaffold(body: Center(child: child)),
    );

/// Màu của [DecoratedBox] ngoài cùng bên trong chip.
Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(OmniStatusChip),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );

  return (box.decoration as BoxDecoration).color!;
}

void main() {
  // Điểm tồn tại của widget này: chênh ĐỘ SÁNG giữa các màu trạng thái trong
  // bảng màu app là 1.04–1.20 lần (mòng két–đỏ 1.04, mòng két–cam 1.20,
  // cam–đỏ 1.15). Không cặp nào tới 3.0. Nghĩa là dưới nắng, hoặc với người
  // mù màu lục-đỏ, MÀU KHÔNG PHÂN BIỆT ĐƯỢC — hình dạng mới phân biệt được.
  testWidgets('luôn hiện cả icon lẫn chữ', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OmniStatusChip(
          icon: Icons.schedule_rounded,
          label: 'Quá hạn 3 ngày',
          tone: OmniTone.danger,
        ),
      ),
    );

    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.text('Quá hạn 3 ngày'), findsOneWidget);
  });

  testWidgets('chữ và icon cùng một màu, để đọc ra là một khối', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const OmniStatusChip(
          icon: Icons.check_rounded,
          label: 'Đã xong',
          tone: OmniTone.success,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    final text = tester.widget<Text>(find.text('Đã xong'));

    expect(icon.color, isNotNull);
    expect(text.style?.color, icon.color);
  });

  // Bốn sắc thái × hai chế độ. Đây là bài đo thật sự — nó chạy qua đúng
  // widget người dùng thấy, không phải qua một bảng hằng số.
  for (final tone in OmniTone.values) {
    for (final brightness in Brightness.values) {
      testWidgets('$tone ở chế độ $brightness đọc được', (tester) async {
        await tester.pumpWidget(
          _wrap(
            OmniStatusChip(
              icon: Icons.circle_outlined,
              label: 'Nhãn thử',
              tone: tone,
            ),
            brightness: brightness,
          ),
        );

        final text = tester.widget<Text>(find.text('Nhãn thử'));
        final ratio = contrastRatio(text.style!.color!, _fill(tester));

        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              'Chip $tone ở chế độ $brightness chỉ đạt '
              '${ratio.toStringAsFixed(2)}:1.',
        );
      });
    }
  }

  testWidgets('nền chip tách được khỏi thẻ đặt nó', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const OmniStatusChip(
          icon: Icons.circle_outlined,
          label: 'Nhãn thử',
          tone: OmniTone.danger,
        ),
      ),
    );

    final theme = OmniTheme.light(TargetPlatform.android);
    final ratio = contrastRatio(_fill(tester), theme.colorScheme.surface);

    expect(
      ratio,
      greaterThan(1.05),
      reason:
          'Nền chip trùng nền thẻ thì chip biến mất, và cái còn lại chỉ là '
          'chữ màu — đúng thứ widget này ra đời để tránh.',
    );
  });

  testWidgets('chữ dài xuống dòng chứ không tràn', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 120,
          child: OmniStatusChip(
            icon: Icons.schedule_rounded,
            label: 'Quá hạn 128 ngày kể từ mốc bàn giao',
            tone: OmniTone.danger,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('vẫn vừa ở cỡ chữ 200%', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: OmniStatusChip(
                  icon: Icons.schedule_rounded,
                  label: 'Quá hạn 3 ngày',
                  tone: OmniTone.danger,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
