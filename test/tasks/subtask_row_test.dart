import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/subtask_row.dart';

/// The row a worker taps with a gloved thumb, in a noisy room, without looking
/// carefully. These tests guard the three things that makes possible.
void main() {
  const subtask = Subtask(
    id: 'a',
    title: 'Nắp phím',
    done: false,
    assigneeName: 'Hằng Ni',
  );

  Widget host(Widget child, {double textScale = 1}) => MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );

  Future<List<MethodCall>> recordHaptics(WidgetTester tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);

        return null;
      },
    );

    return calls;
  }

  testWidgets('the whole row is the tap target, not just the box', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: null,
          enabled: true,
          onToggle: (_) => toggled = true,
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    // Tapping the far right edge — nowhere near the checkbox — must count.
    // Aiming at a 24dp box with dirty hands is how the wrong stage gets ticked.
    final row = tester.getRect(find.byType(SubtaskRow));
    await tester.tapAt(Offset(row.right - 8, row.center.dy));
    expect(toggled, isTrue);
  });

  testWidgets('the row is at least 56dp tall', (tester) async {
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    // 48dp is the Android floor; this is a workshop, so the floor is 56.
    expect(
      tester.getSize(find.byType(SubtaskRow)).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('a short row stays 56dp even with no assignee', (tester) async {
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: const Subtask(id: 'b', title: 'Body', done: false),
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SubtaskRow)).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('ticking fires haptic feedback', (tester) async {
    final calls = await recordHaptics(tester);
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    await tester.tap(find.byType(SubtaskRow));

    // The room is loud and they may not be looking at the screen; the buzz is
    // the only confirmation that actually lands.
    expect(
      calls.map((call) => call.method),
      contains('HapticFeedback.vibrate'),
    );
  });

  testWidgets('a read-only viewer cannot tick', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: null,
          enabled: false,
          onToggle: (_) => toggled = true,
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    await tester.tap(find.byType(SubtaskRow));
    expect(toggled, isFalse);
  });

  testWidgets('a failed tick says so and offers both ways out', (tester) async {
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: const PendingTick(
            subtaskId: 'a',
            done: true,
            clientRequestId: 'c1',
            error: 'Không có kết nối mạng',
          ),
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    // Stated in words, not just a red tint: a silent revert is how a stage
    // gets skipped.
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Bỏ'), findsOneWidget);
  });

  testWidgets('the assignee is a chip, not part of the title', (tester) async {
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: subtask,
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(find.text('Nắp phím'), findsOneWidget);
    expect(find.text('Hằng Ni'), findsOneWidget);
  });

  testWidgets('the row still fits its content at 200% text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SubtaskRow(
          subtask: const Subtask(
            id: 'c',
            title: 'Hoàn thiện bề mặt và đánh bóng toàn bộ thân đàn',
            done: false,
            assigneeName: 'Luận',
          ),
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
        textScale: 2,
      ),
    );

    // Older eyes under workshop lighting turn the system font size up. The row
    // has to grow rather than clip.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SubtaskRow)).height, greaterThan(56));
  });
}
