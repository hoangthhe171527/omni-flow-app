import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  test('mọi tông ô icon đạt 4.5:1 cả sáng lẫn tối', () {
    final surface = OmniTheme.dark().colorScheme.surface;
    for (final hue in OmniHue.values) {
      final l = OmniFeatureTones.light(hue);
      final d = OmniFeatureTones.dark(hue, surface);
      expect(
        contrastRatio(l.foreground, l.background),
        greaterThanOrEqualTo(4.5),
        reason: 'sáng $hue',
      );
      expect(
        contrastRatio(d.foreground, d.background),
        greaterThanOrEqualTo(4.5),
        reason: 'tối $hue',
      );
    }
  });
}
