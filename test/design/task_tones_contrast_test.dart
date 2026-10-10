import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/omni_task_tones.dart';

void main() {
  testWidgets('mọi chip Việc đạt 4.5:1 ở chế độ tối và sáng', (t) async {
    for (final theme in [
      OmniTheme.light(TargetPlatform.android),
      OmniTheme.dark(TargetPlatform.android),
    ]) {
      late OmniTaskTones tones;
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (c) {
              tones = OmniTaskTones.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final (name, tone) in [
        ('today', tones.today),
        ('late', tones.late),
        ('upcoming', tones.upcoming),
        ('none', tones.none),
        ('highPriority', tones.highPriority),
        ('violet', tones.violet),
      ]) {
        expect(
          contrastRatio(tone.foreground, tone.background),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} $name',
        );
      }
      // Chấm/thanh là đồ hoạ: 3:1 trên surface.
      for (final c in [
        tones.priorityHigh,
        tones.priorityNormal,
        tones.dueSoonBar,
      ]) {
        expect(
          contrastRatio(c, theme.colorScheme.surface),
          greaterThanOrEqualTo(3),
          reason: '${theme.brightness} $c',
        );
      }
    }
  });

  testWidgets('mũi tên Điều phối có token chevron theo chế độ', (t) async {
    final seen = <Brightness, Color>{};
    for (final theme in [
      OmniTheme.light(TargetPlatform.android),
      OmniTheme.dark(TargetPlatform.android),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (c) {
              seen[theme.brightness] = OmniTaskTones.of(c).chevron;
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpAndSettle();
    }
    expect(seen[Brightness.light], const Color(0xFFC9D2DE));
    expect(seen[Brightness.dark], const Color(0xFF5B6678));
  });
}
