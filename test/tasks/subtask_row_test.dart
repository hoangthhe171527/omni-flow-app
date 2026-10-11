import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/subtask_row.dart';

/// The row a worker taps with a gloved thumb, in a noisy room, without looking
/// carefully. These tests guard the things that makes possible.
void main() {
  const subtask = Subtask(
    id: 'a',
    title: 'Nắp phím',
    done: false,
    assigneeId: 'u1',
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

  SubtaskRow row({
    Subtask s = subtask,
    PendingTick? pending,
    bool enabled = true,
    ValueChanged<bool>? onToggle,
    VoidCallback? onAssign,
    VoidCallback? onEdit,
  }) => SubtaskRow(
    subtask: s,
    pending: pending,
    enabled: enabled,
    onToggle: onToggle ?? (_) {},
    onRetry: () {},
    onDiscard: () {},
    onAssign: onAssign,
    onEdit: onEdit,
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

  testWidgets('the tick target is 44dp and toggles the subtask', (
    tester,
  ) async {
    bool? toggledTo;
    await tester.pumpWidget(host(row(onToggle: (v) => toggledTo = v)));

    final tick = find.bySemanticsLabel('Xong');
    expect(tester.getSize(tick).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(tick);
    expect(toggledTo, isTrue);
  });

  testWidgets('tapping the title does not tick (it opens edit instead)', (
    tester,
  ) async {
    var toggled = false;
    var edited = false;
    await tester.pumpWidget(
      host(row(onToggle: (_) => toggled = true, onEdit: () => edited = true)),
    );

    await tester.tap(find.text('Nắp phím'));
    expect(toggled, isFalse);
    expect(edited, isTrue);
  });

  testWidgets('the row is at least 44dp tall, with or without an assignee', (
    tester,
  ) async {
    await tester.pumpWidget(host(row()));
    expect(
      tester.getSize(find.byType(SubtaskRow)).height,
      greaterThanOrEqualTo(44),
    );

    await tester.pumpWidget(
      host(
        row(
          s: const Subtask(id: 'b', title: 'Body', done: false),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(SubtaskRow)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('ticking fires haptic feedback', (tester) async {
    final calls = await recordHaptics(tester);
    await tester.pumpWidget(host(row()));

    await tester.tap(find.bySemanticsLabel('Xong'));

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
      host(row(enabled: false, onToggle: (_) => toggled = true)),
    );

    await tester.tap(find.bySemanticsLabel('Xong'));
    expect(toggled, isFalse);
  });

  testWidgets('a failed tick says so and offers both ways out', (tester) async {
    await tester.pumpWidget(
      host(
        row(
          pending: const PendingTick(
            subtaskId: 'a',
            done: true,
            clientRequestId: 'c1',
            error: 'Không có kết nối mạng',
          ),
        ),
      ),
    );

    // Stated in words, not just a red tint: a silent revert is how a stage
    // gets skipped.
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Bỏ'), findsOneWidget);
  });

  testWidgets('the assignee is an avatar button, not part of the title', (
    tester,
  ) async {
    var assigned = false;
    await tester.pumpWidget(host(row(onAssign: () => assigned = true)));

    expect(find.text('Nắp phím'), findsOneWidget);
    expect(find.text('Hằng Ni'), findsNothing);
    final button = find.bySemanticsLabel('Đổi người làm: Hằng Ni');
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(button);
    expect(assigned, isTrue);
  });

  testWidgets('the row still fits its content at 200% text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        row(
          s: const Subtask(
            id: 'c',
            title: 'Hoàn thiện bề mặt và đánh bóng toàn bộ thân đàn',
            done: false,
            assigneeId: 'u2',
            assigneeName: 'Luận',
          ),
        ),
        textScale: 2,
      ),
    );

    // Older eyes under workshop lighting turn the system font size up. The row
    // has to grow rather than clip.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SubtaskRow)).height, greaterThan(44));
  });
}
