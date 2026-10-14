import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/board_drop.dart';
import 'package:omni_app/modules/plans/domain/board_person.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

Task t(String id, double order, {bool pinned = false, String? section}) =>
    Task.fromJson({
      'id': id,
      'order': order,
      'pinned': pinned,
      'section_id': ?section,
    });

void main() {
  group('boardDropOrder', () {
    test('giữa hai hàng xóm → trung bình', () {
      expect(boardDropOrder([t('a', 1), t('b', 3)], t('m', 9), 1), 2);
    });

    test('đầu cột → sau − 1; cuối cột → trước + 1', () {
      final column = [t('a', 1), t('b', 3)];
      expect(boardDropOrder(column, t('m', 9), 0), 0);
      expect(boardDropOrder(column, t('m', 9), 2), 4);
    });

    test('cột rỗng → null (chỉ gửi section_id)', () {
      expect(boardDropOrder(const [], t('m', 9), 0), isNull);
    });

    test('thẻ thường thả ngay dưới khối ghim → bỏ hàng xóm ghim, dùng thẻ '
        'thường đầu − 1', () {
      expect(
        boardDropOrder([t('p', 0, pinned: true), t('a', 5)], t('m', 9), 1),
        4,
      );
    });

    test('chỉ có hàng xóm khác nhóm ghim → null', () {
      expect(boardDropOrder([t('p', 0, pinned: true)], t('m', 9), 1), isNull);
      expect(boardDropOrder([t('a', 5)], t('m', 9, pinned: true), 0), isNull);
    });
  });

  test('dropIndexFor: trên mọi tâm → 0; giữa → 1; dưới hết → length', () {
    const centers = [100.0, 200.0, 300.0];
    expect(dropIndexFor(centers, 10), 0);
    expect(dropIndexFor(centers, 150), 1);
    expect(dropIndexFor(centers, 999), 3);
    expect(dropIndexFor(const [], 50), 0);
  });

  test('BoardBuckets.moved: rời cột cũ, chèn đúng chỉ số cột mới, sectionId '
      'mới, giữ số cột', () {
    const sections = [
      PlanSection(id: 's1', name: 'A'),
      PlanSection(id: 's2', name: 'B'),
    ];
    final board = BoardBuckets.build(
      (
        tasks: [
          t('t1', 1, section: 's1'),
          t('t2', 2, section: 's1'),
          t('t3', 1, section: 's2'),
          t('t4', 2, section: 's2'),
        ],
        truncated: false,
      ),
      sections,
      BoardPerson.everyone,
    );

    final moved = board.moved('t1', 1, 1, 's2');

    expect(moved.buckets.length, 2);
    expect(moved.buckets[0].map((e) => e.id), ['t2']);
    expect(moved.buckets[1].map((e) => e.id), ['t3', 't1', 't4']);
    expect(moved.buckets[1][1].sectionId, 's2');
    expect(moved.columns, board.columns);
    // Bảng gốc không đổi.
    expect(board.buckets[0].map((e) => e.id), ['t1', 't2']);
  });

  test('BoardBuckets.moved: chỉ số vượt cột thì kẹp về cuối; id lạ → giữ '
      'nguyên', () {
    const sections = [
      PlanSection(id: 's1', name: 'A'),
      PlanSection(id: 's2', name: 'B'),
    ];
    final board = BoardBuckets.build(
      (tasks: [t('t1', 1, section: 's1')], truncated: false),
      sections,
      BoardPerson.everyone,
    );

    expect(board.moved('t1', 1, 9, 's2').buckets[1].map((e) => e.id), ['t1']);
    expect(board.moved('zz', 1, 0, 's2').buckets[1], isEmpty);
  });

  group('Plan.isTaskViewer', () {
    final plan = Plan.fromJson(const {
      'id': 'p',
      'name': 'P',
      'owner_id': 'u-owner',
      'member_ids': ['u-member', 'u-view'],
      'member_roles': {'u-view': 'viewer', 'u-member': 'member'},
    });

    test('chỉ vai viewer ghi rõ', () {
      expect(plan.isTaskViewer('u-view'), isTrue);
      expect(plan.isTaskViewer('u-member'), isFalse);
    });

    test('người ngoài danh sách → false; chủ → false; null → false', () {
      expect(plan.isTaskViewer('u-stranger'), isFalse);
      expect(plan.isTaskViewer('u-owner'), isFalse);
      expect(plan.isTaskViewer(null), isFalse);
    });
  });
}
