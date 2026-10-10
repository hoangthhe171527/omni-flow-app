import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/due_chip.dart';

void main() {
  final now = DateTime(2026, 10, 10, 9);

  // Khoá của API là `due_date` (Task.fromJson), không phải `due_at`.
  Task t({DateTime? due, String status = 'todo'}) => Task.fromJson({
    'id': 'x',
    'title': 'x',
    'status': status,
    if (due != null) 'due_date': due.toIso8601String(),
  });

  test('bốn tông hạn', () {
    expect(dueToneOf(t(), now: now), (
      label: 'Chưa đặt hạn',
      tone: DueTone.none,
    ));
    expect(
      dueToneOf(t(due: DateTime(2026, 10, 10)), now: now).tone,
      DueTone.today,
    );
    expect(dueToneOf(t(due: DateTime(2026, 10, 8)), now: now), (
      label: 'Quá hạn 2 ngày',
      tone: DueTone.late,
    ));
    expect(dueToneOf(t(due: DateTime(2026, 10, 15)), now: now), (
      label: 'Hạn 15/10',
      tone: DueTone.upcoming,
    ));
  });

  test('việc đã xong không bị tô quá hạn', () {
    expect(
      dueToneOf(
        t(due: DateTime(2026, 10, 1), status: 'done'),
        now: now,
      ).tone,
      isNot(DueTone.late),
    );
  });

  testWidgets('DueChip hiện nhãn của dueToneOf', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: DueChip(task: t(due: DateTime(2020, 1, 1))),
        ),
      ),
    );

    expect(find.textContaining('Quá hạn'), findsOneWidget);
  });
}
