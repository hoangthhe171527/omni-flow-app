import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Dòng nào "vừa tới" được quyết định KHI FEED ĐỔI, không phải trong build.
///
/// Bản trước tính trong `itemBuilder`: `isNew = !seen.contains(id); seen.add(id)`.
/// Hai lỗi cùng lúc: ghi state trong build — nên một lần dựng lại vì cuộn hay
/// đổi theme là câu trả lời đổi (dòng đang mờ dần bỗng hết mờ); và tập "đã
/// thấy" chỉ có thêm không có bớt, phình theo phiên và nhớ cả những dòng đã rời
/// khỏi cửa sổ bảy ngày.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  final today =
      '${DateTime.now().year}-'
      '${DateTime.now().month.toString().padLeft(2, '0')}-'
      '${DateTime.now().day.toString().padLeft(2, '0')}';

  FeedEntry entry(String id) => FeedEntry(
    id: id,
    kind: FeedKind.subtaskCompleted,
    taskId: 't1',
    taskTitle: 'KAWAI HAT-5',
    at: DateTime(2026, 9, 10, 9, 35),
    userName: 'Hằng Ni',
    detail: id,
    day: today,
  );

  /// Danh sách do test điều khiển; đổi nó là "feed vừa về qua realtime".
  final rows = StateProvider<List<FeedEntry>>(
    (ref) => [entry('a3'), entry('a2'), entry('a1')],
  );

  Widget host() => ProviderScope(
    overrides: [
      workshopFeedProvider.overrideWith(
        (ref) async => (entries: ref.watch(rows), truncated: false),
      ),
      kpiPreviousDeliveredProvider.overrideWith((ref) async => 0),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(const AccessPolicy({'tasks.read', 'tasks.write'})),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TimelinePage(),
    ),
  );

  /// Những dòng đang chạy hiệu ứng "vừa tới" (bọc trong Opacity của tween).
  Set<String> fresh(WidgetTester tester, Iterable<String> ids) => {
    for (final id in ids)
      if (find
          .ancestor(
            of: find.text('Hằng Ni đã xong $id'),
            matching: find.byType(Opacity),
          )
          .evaluate()
          .isNotEmpty)
        id,
  };

  Future<void> setRows(WidgetTester tester, List<String> ids) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelinePage)),
    );
    container.read(rows.notifier).state = [for (final id in ids) entry(id)];
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lần đầu không dòng nào mới; thêm 2 thì đúng 2 dòng mới', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(fresh(tester, ['a1', 'a2', 'a3']), isEmpty);

    await setRows(tester, ['a5', 'a4', 'a3', 'a2', 'a1']);

    expect(fresh(tester, ['a1', 'a2', 'a3', 'a4', 'a5']), {'a4', 'a5'});
  });

  testWidgets('dựng lại màn (không đổi feed) KHÔNG đổi câu trả lời', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await setRows(tester, ['a5', 'a4', 'a3', 'a2', 'a1']);
    expect(fresh(tester, ['a4', 'a5']), {'a4', 'a5'});

    // Dựng lại toàn bộ cây widget; provider và feed không đổi.
    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      fresh(tester, ['a1', 'a2', 'a3', 'a4', 'a5']),
      {'a4', 'a5'},
      reason:
          'Tính trong build thì lần dựng thứ hai đã "thấy" rồi, và dòng đang '
          'mờ dần bỗng đứng phắt lại.',
    );
  });

  testWidgets(
    'dòng rời đi rồi quay lại là dòng MỚI — tập đã thấy không phình',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await setRows(tester, ['a5', 'a4', 'a3', 'a2', 'a1']);

      // Hai dòng rời khỏi cửa sổ bảy ngày.
      await setRows(tester, ['a3', 'a2', 'a1']);
      expect(fresh(tester, ['a1', 'a2', 'a3']), isEmpty);

      // ...rồi quay lại: với màn hình bây giờ chúng là dòng vừa tới.
      await setRows(tester, ['a5', 'a4', 'a3', 'a2', 'a1']);
      expect(fresh(tester, ['a1', 'a2', 'a3', 'a4', 'a5']), {'a4', 'a5'});
    },
  );
}
