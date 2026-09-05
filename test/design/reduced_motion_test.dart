import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/platform/omni_motion_scope.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';

/// Đọc [OmniMotion.of] dưới một [MediaQuery] do test đặt.
Future<OmniMotionSpec> _read(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  late OmniMotionSpec spec;

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          spec = OmniMotion.of(context);

          return const SizedBox();
        },
      ),
    ),
  );

  return spec;
}

void main() {
  testWidgets('mặc định giữ nguyên thang 140/220/350', (tester) async {
    final spec = await _read(tester, disableAnimations: false);

    expect(spec.enabled, isTrue);
    expect(spec.fast, OmniDuration.fast);
    expect(spec.base, OmniDuration.base);
    expect(spec.slow, OmniDuration.slow);
  });

  testWidgets('khi hệ điều hành tắt hiệu ứng, mọi thời lượng về 0', (
    tester,
  ) async {
    final spec = await _read(tester, disableAnimations: true);

    expect(spec.enabled, isFalse);
    expect(spec.fast, Duration.zero);
    expect(spec.base, Duration.zero);
    expect(
      spec.slow,
      Duration.zero,
      reason:
          '"Giảm chuyển động" nghĩa là bỏ hẳn phần di chuyển, không phải làm '
          'nó nhanh hơn. Một cú trượt 60ms vẫn là một cú trượt.',
    );
  });

  group('PageController.goTo', () {
    testWidgets('bình thường thì trượt qua nhiều khung hình', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _pager(controller, disableAnimations: false),
      );

      final context = tester.element(find.byType(PageView));
      controller.goTo(context, 2);

      // Một khung hình sau khi bắt đầu, nó chưa tới nơi — tức là có chuyển động.
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.page, isNot(closeTo(2, 0.01)));

      await tester.pumpAndSettle();
      expect(controller.page, closeTo(2, 0.01));
    });

    testWidgets('khi tắt hiệu ứng thì tới nơi ngay khung hình đầu', (
      tester,
    ) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_pager(controller, disableAnimations: true));

      final context = tester.element(find.byType(PageView));
      controller.goTo(context, 2);
      await tester.pump();

      expect(controller.page, closeTo(2, 0.01));
    });
  });
}

Widget _pager(
  PageController controller, {
  required bool disableAnimations,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: PageView(
      controller: controller,
      children: const [
        SizedBox.expand(),
        SizedBox.expand(),
        SizedBox.expand(),
      ],
    ),
  ),
);
