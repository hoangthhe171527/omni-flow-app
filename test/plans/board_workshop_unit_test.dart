import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_tabs.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/board_person.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_task_card.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';

/// Kho nối Xưởng trên bảng kế hoạch: cột ảo "Đã giao" và thẻ việc có cây.
void main() {
  const sections = [
    PlanSection(id: 's1', name: 'Chờ làm'),
    PlanSection(id: 's2', name: 'Đang làm'),
  ];

  Task task(
    String id, {
    String section = 's1',
    String status = 'todo',
    String role = 'refurbish',
    String? place,
    String sale = 'available',
    String? customer,
    int steps = 0,
    int done = 0,
  }) => Task.fromJson({
    'id': id,
    'title': 'gõ tay $id',
    'status': status,
    'section_id': section,
    'checklist': [
      for (var i = 0; i < steps; i++)
        {'id': 'c$i', 'title': 'Bước $i', 'done': i < done},
    ],
    if (place != null) ...{
      'subject': {'type': 'unit', 'id': 'u-$id', 'role': role},
      'unit': {
        'id': 'u-$id',
        'maker': 'YAMAHA',
        'model': 'U1E',
        'serial': '1176498',
        'lot_id': 'l61',
        'lot_code': 'Ep 61',
        'place': place,
        'sale': sale,
        'customer_id': customer == null ? null : 'c1',
        'customer_name': customer,
      },
    },
  });

  group('cột ảo Đã giao', () {
    test('việc tân trang có cây đã giao rời nhóm đã lưu, vào cột cuối', () {
      final board = BoardBuckets.build(
        (
          tasks: [
            task('a'),
            task('b', section: 's2', place: 'in_stock'),
            task('c', section: 's2', place: 'delivered'),
            task('w', place: 'delivered', role: 'warranty'),
          ],
          truncated: false,
        ),
        sections,
        BoardPerson.everyone,
      );

      expect(
        [for (final c in board.columns) c.name],
        ['Chờ làm', 'Đang làm', 'Đã giao'],
      );
      expect(board.columns.last.isDelivered, isTrue);
      expect(
        [
          for (final b in board.buckets) [for (final t in b) t.id],
        ],
        [
          ['a', 'w'],
          ['b'],
          ['c'],
        ],
      );
    });

    test('không có cây đã giao thì không có cột ảo', () {
      final board = BoardBuckets.build(
        (
          tasks: [
            task('a'),
            task('b', place: 'in_stock'),
          ],
          truncated: false,
        ),
        sections,
        BoardPerson.everyone,
      );

      expect(board.columns, sections);
    });

    test('dựng lại với cột của chính bảng: không nhân đôi cột ảo', () {
      final loaded = (
        tasks: [
          task('a'),
          task('c', place: 'delivered'),
        ],
        truncated: false,
      );
      final first = BoardBuckets.build(loaded, sections, BoardPerson.everyone);
      final again = BoardBuckets.build(
        loaded,
        first.columns,
        BoardPerson.everyone,
      );

      expect(
        [for (final c in again.columns) c.id],
        ['s1', 's2', PlanSection.deliveredId],
      );
      expect(again.buckets.last.single.id, 'c');
      // Cột thật giữ nguyên chỉ số — chỗ thả tính `order` dựa vào điều này.
      expect(again.buckets[0].single.id, 'a');
    });
  });

  group('thẻ việc có cây', () {
    Widget wrap(Task task) => ProviderScope(
      overrides: [
        taskLabelsProvider.overrideWith((ref) async => const <TaskLabel>[]),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 284,
              child: BoardTaskCard(task: task, onTap: () {}),
            ),
          ),
        ),
      ),
    );

    Text line(WidgetTester t) =>
        t.widget<Text>(find.byKey(const ValueKey('card-unit-line')));

    testWidgets('tên cây + serial, khách · lô đậm khi đã bán, vạch tiến độ', (
      t,
    ) async {
      await t.pumpWidget(
        wrap(
          task(
            'a',
            place: 'in_stock',
            sale: 'sold',
            customer: 'Trần Minh Khôi',
            steps: 10,
            done: 8,
          ),
        ),
      );
      await t.pumpAndSettle();

      // Tên lấy từ Kho, không phải tiêu đề gõ tay.
      expect(find.text('YAMAHA U1E 1176498'), findsOneWidget);
      expect(find.text('gõ tay a'), findsNothing);
      expect(line(t).data, 'Trần Minh Khôi · Ep 61');
      expect(line(t).style!.fontWeight, FontWeight.w600);
      expect(find.text('8/10'), findsOneWidget);
      expect(
        t
            .widget<OmniProgressBar>(
              find.byKey(const ValueKey('card-unit-progress')),
            )
            .value,
        0.8,
      );
    });

    testWidgets(
      'chưa có khách: dòng mờ; việc xong thì thôi tô ưu tiên',
      (t) async {
        await t.pumpWidget(wrap(task('a', place: 'in_stock')));
        await t.pumpAndSettle();
        expect(line(t).data, 'Chưa có khách · Ep 61');
        expect(line(t).style!.fontWeight, FontWeight.w400);
        // Không có công đoạn thì không có vạch.
        expect(find.byType(OmniProgressBar), findsNothing);

        await t.pumpWidget(
          wrap(
            task(
              'a',
              place: 'in_stock',
              sale: 'sold',
              customer: 'Lê Thu Hà',
              status: 'done',
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(line(t).style!.fontWeight, FontWeight.w400);
      },
    );

    testWidgets('việc thường giữ nguyên tiêu đề, không có dòng cây', (t) async {
      await t.pumpWidget(wrap(task('a', steps: 2, done: 1)));
      await t.pumpAndSettle();

      expect(find.text('gõ tay a'), findsOneWidget);
      expect(find.byKey(const ValueKey('card-unit-line')), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
    });
  });
}
