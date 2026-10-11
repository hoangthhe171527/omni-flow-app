import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/modules/opportunities/presentation/widgets/stage_strip.dart';

void main() {
  const yellow = Color(0xFFFACC15);

  test('vàng #FACC15 thô không đủ tương phản trên nền sáng; sau khi chỉnh đủ '
      '4.5:1 (chữ) và 3:1 (cung)', () {
    final light = OmniTheme.light(TargetPlatform.android).colorScheme.surface;
    expect(contrastRatio(yellow, light), lessThan(3));
    expect(
      contrastRatio(readableStageColor(yellow, light), light),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(readableStageColor(yellow, light, minRatio: 3), light),
      greaterThanOrEqualTo(3),
    );
  });

  test('nền tối: vàng giữ nguyên, màu tối bị nâng sáng lên đủ 4.5:1', () {
    final dark = OmniTheme.dark(TargetPlatform.android).colorScheme.surface;
    expect(readableStageColor(yellow, dark), yellow);
    const navy = Color(0xFF1E3A8A);
    final fixed = readableStageColor(navy, dark);
    expect(contrastRatio(fixed, dark), greaterThanOrEqualTo(4.5));
  });
}
