import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/board_person.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

import '../support/fixed_background.dart';

/// Lọc theo người và chia cột chạy trong PROVIDER, không trong `build`.
///
/// Trước đây `_Board.build` lọc 500 việc rồi chia cột mỗi lần dựng lại — và
/// nó dựng lại mỗi lần lướt sang trang (setState cho chỉ báo trang), mỗi lần
/// quyền đổi, mỗi lần cha dựng lại vì bất kỳ lý do gì. Một bảng sáu cột là
/// sáu lần lọc cho một cú vuốt. Tính một lần cho mỗi (dự án, bộ lọc), và chỉ
/// tính lại khi việc hoặc bộ lọc đổi.
void main() {
  const planId = 'p1';

  final plan = Plan.fromJson({
    'id': planId,
    'name': 'Đàn cơ',
    'sections': [
      {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
      {'id': 's2', 'name': 'Đang phục chế', 'order': 1},
      {'id': 's3', 'name': 'Chờ QC', 'order': 2},
    ],
  });

  Task task(
    String id, {
    String? sectionId,
    List<String> assignees = const [],
  }) => Task.fromJson({
    'id': id,
    'title': id,
    'section_id': ?sectionId,
    'assignee_ids': assignees,
  });

  // 6 việc, 2 người, 3 cột. Một việc không có nhóm, một việc thuộc nhóm đã xoá.
  final tasks = [
    task('t1', sectionId: 's1', assignees: ['u1']),
    task('t2', sectionId: 's1', assignees: ['u2']),
    task('t3', sectionId: 's2', assignees: ['u1']),
    task('t4', sectionId: 's3'),
    task('t5', assignees: ['u2']),
    task('t6', sectionId: 'gone', assignees: ['u1']),
  ];

  List<int> sizes(BoardBuckets b) => [for (final c in b.buckets) c.length];

  ProviderContainer make({
    Plan? withPlan,
    FutureOr<PlanTasks> Function()? loadTasks,
  }) {
    final container = ProviderContainer(
      overrides: [
        planProvider(planId).overrideWith((ref) async => withPlan ?? plan),
        planTasksProvider(planId).overrideWith(
          (ref) async => loadTasks == null
              ? (tasks: tasks, truncated: false)
              : await loadTasks(),
        ),
      ],
    );
    addTearDown(container.dispose);

    return container;
  }

  Future<BoardBuckets> open(ProviderContainer c, BoardKey key) async {
    c.listen(boardBucketsProvider(key), (_, _) {});
    await c.read(planProvider(planId).future);
    await c.read(planTasksProvider(planId).future);

    return c.read(boardBucketsProvider(key)).requireValue;
  }

  group('chia rổ', () {
    test(
      'không lọc: mỗi cột đúng việc của nó; mồ côi rơi vào cột đầu',
      () async {
        final b = await open(make(), (
          planId: planId,
          person: BoardPerson.everyone,
        ));

        expect(b.columns.map((c) => c.name), [
          'Nhập xưởng',
          'Đang phục chế',
          'Chờ QC',
        ]);
        // t5 không có nhóm, t6 thuộc nhóm đã xoá: cả hai về cột đầu, không mất.
        expect(b.buckets[0].map((t) => t.id), ['t1', 't2', 't5', 't6']);
        expect(sizes(b), [4, 1, 1]);
        expect(b.countOf(0), 4);
      },
    );

    test('lọc theo một người: lọc TRƯỚC khi chia, con số đi theo', () async {
      final b = await open(make(), (
        planId: planId,
        person: const BoardPerson.person('u1', 'Hằng Ni'),
      ));

      expect(sizes(b), [2, 1, 0]);
    });

    test('"Chưa giao ai" chỉ còn việc trống', () async {
      final b = await open(make(), (
        planId: planId,
        person: BoardPerson.unassigned,
      ));

      expect(sizes(b), [0, 0, 1]);
      expect(b.buckets[2].single.id, 't4');
    });

    test('dự án chưa khai nhóm việc: một cột duy nhất chứa tất cả', () async {
      final bare = Plan.fromJson({'id': planId, 'name': 'Đàn cơ'});
      final b = await open(make(withPlan: bare), (
        planId: planId,
        person: BoardPerson.everyone,
      ));

      expect(b.columns.single.name, 'Tất cả công việc');
      expect(sizes(b), [6]);
    });
  });

  group('bộ nhớ đệm', () {
    test('cùng tham số → cùng instance, không tính lại', () async {
      final c = make();
      final first = await open(c, (
        planId: planId,
        person: BoardPerson.person('u1', 'Hằng Ni'),
      ));
      // Một record mới với một BoardPerson mới nhưng cùng giá trị.
      final again = c.read(
        boardBucketsProvider((
          planId: planId,
          person: BoardPerson.person('u1', 'Hằng Ni'),
        )),
      );

      expect(identical(again.requireValue, first), isTrue);
    });

    test('đổi người thì là một kết quả khác', () async {
      final c = make();
      final everyone = await open(c, (
        planId: planId,
        person: BoardPerson.everyone,
      ));
      final one = await open(c, (
        planId: planId,
        person: const BoardPerson.person('u2', 'Luận'),
      ));

      expect(identical(everyone, one), isFalse);
      expect(sizes(one), [2, 0, 0]);
    });
  });

  group('trạng thái nguồn đi thẳng ra', () {
    test('đang tải thì đang tải', () async {
      final c = make(loadTasks: () => Completer<PlanTasks>().future);
      c.listen(
        boardBucketsProvider((planId: planId, person: BoardPerson.everyone)),
        (_, _) {},
      );
      await c.read(planProvider(planId).future);

      final v = c.read(
        boardBucketsProvider((planId: planId, person: BoardPerson.everyone)),
      );
      expect(v.isLoading, isTrue);
      expect(v.valueOrNull, isNull);
    });

    test('lỗi thì lỗi, để màn hiện nút thử lại', () async {
      final c = make(loadTasks: () => throw StateError('offline'));
      c.listen(
        boardBucketsProvider((planId: planId, person: BoardPerson.everyone)),
        (_, _) {},
      );
      await c.read(planProvider(planId).future);
      await expectLater(
        c.read(planTasksProvider(planId).future),
        throwsStateError,
      );

      expect(
        c
            .read(
              boardBucketsProvider((
                planId: planId,
                person: BoardPerson.everyone,
              )),
            )
            .hasError,
        isTrue,
      );
    });
  });

  testWidgets('lướt trang KHÔNG tính lại rổ', (tester) async {
    final observer = _CountingObserver();

    await tester.pumpWidget(
      ProviderScope(
        observers: [observer],
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
          backgroundProvider.overrideWith(FixedBackground.new),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanBoardPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('t1'), findsOneWidget);
    final settled = observer.bucketBuilds;
    expect(settled, greaterThan(0));

    // Chạm chỉ báo để nhảy tới cột cuối, rồi vuốt ngược một trang.
    await tester.tap(find.bySemanticsLabel('Chờ QC'));
    await tester.pumpAndSettle();
    expect(find.text('t4'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('t3'), findsOneWidget);

    expect(
      observer.bucketBuilds,
      settled,
      reason:
          'Lướt trang chỉ đổi chỉ báo. Lọc lại 500 việc cho mỗi cú vuốt là '
          'thứ bảng này từng làm.',
    );
  });
}

/// Đếm số lần rổ được tính (tạo + cập nhật).
class _CountingObserver extends ProviderObserver {
  int bucketBuilds = 0;

  bool _isBuckets(ProviderBase<Object?> provider) =>
      provider.name == 'boardBuckets';

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (_isBuckets(provider)) bucketBuilds++;
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (_isBuckets(provider)) bucketBuilds++;
  }
}
