import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

import '../support/fixed_background.dart';

/// Dòng việc theo `Timeline.dc.html`: thẻ KPI tháng có vạch mốc, feed 7 ngày
/// theo ngày với dòng "… ĐÃ XONG".
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  WorkshopKpi kpi({
    int delivered = 64,
    List<int> tiers = const [50, 80, 100],
    (int, int, int)? next,
    int daysLeft = 22,
    int rework = 1,
  }) => WorkshopKpi(
    delivered: delivered,
    reachedBonus: 0,
    daysLeft: daysLeft,
    tiers: [for (final c in tiers) BonusTier(count: c, bonus: c ~/ 5)],
    isConfigured: true,
    rework: rework,
    nextTier: next == null
        ? null
        : NextTier(count: next.$1, bonus: next.$2, remaining: next.$3),
  );

  FeedEntry entry({
    required FeedKind kind,
    required String user,
    required String title,
    required String plan,
    required DateTime at,
    String id = 'x',
  }) => FeedEntry(
    id: id,
    kind: kind,
    taskId: 't1',
    taskTitle: kind == FeedKind.subtaskCompleted ? 'Steinway D' : title,
    at: at,
    userName: user,
    detail: kind == FeedKind.subtaskCompleted ? title : null,
    planName: plan,
    day: iso(DateTime.now()),
  );

  // Mốc UTC: 01:45Z = 08:45 giờ VN.
  DateTime today(int h, int m) => DateTime.utc(2026, 9, 10, h - 7, m);

  Future<void> host(
    WidgetTester t, {
    WorkshopKpi? kpiValue,
    int previous = 22,
    List<FeedEntry> feed = const [],
    bool reduceMotion = false,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundProvider.overrideWith(FixedBackground.new),
          kpiPreviousDeliveredProvider.overrideWith((ref) async => previous),
          workshopFeedProvider.overrideWith(
            (ref) async => (entries: feed, truncated: true),
          ),
          workshopKpiProvider.overrideWith((ref) async => kpiValue ?? kpi()),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(
              AccessPolicy(const {
                'tasks.read',
                'tasks.write',
                'tasks.projects.manage.all',
              }),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const TimelinePage()),
              GoRoute(
                path: '/tasks/:id',
                name: TaskRoutes.detail,
                builder: (_, state) =>
                    Text('chi tiết ${state.pathParameters['id']}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('KPI: số, chip so sánh, mốc thưởng tiếp, làm lại', (t) async {
    await host(t, kpiValue: kpi(next: (80, 16, 16)), previous: 58);
    await t.pumpAndSettle();
    expect(find.text('64'), findsOneWidget);
    expect(find.text('việc xong trong tháng'), findsOneWidget);
    // Tháng liền trước tháng đang xem (tháng hiện tại), kể cả tháng 1 -> 12.
    final prevMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
    expect(find.text('+6 so với tháng ${prevMonth.month}'), findsOneWidget);
    expect(find.textContaining('Còn 16 việc tới mốc 80'), findsOneWidget);
    expect(find.text('Mốc 80 việc'), findsOneWidget);
    expect(find.text('1 lần làm lại'), findsOneWidget);
    expect(find.byKey(const Key('kpi-tier-mark')), findsNWidgets(3));
  });

  testWidgets('tháng hiện tại: "Tháng sau" vô hiệu', (t) async {
    await host(t, kpiValue: kpi(delivered: 1));
    await t.pumpAndSettle();
    final next = t.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(next.onPressed, isNull);
    final prev = t.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
    );
    expect(prev.onPressed, isNotNull);
    // Vùng chạm 44x44.
    expect(
      t.getSize(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded)),
      const Size(44, 44),
    );
  });

  testWidgets('feed: nhóm ngày hoa + "n việc", dòng piano_done có ĐÃ XONG', (
    t,
  ) async {
    await host(
      t,
      feed: [
        entry(
          id: 'a',
          kind: FeedKind.pianoDone,
          user: 'Hoàng',
          title: 'Đánh bóng vỏ đàn Steinway',
          plan: 'Sửa chữa đàn',
          at: today(8, 45),
        ),
        entry(
          id: 'b',
          kind: FeedKind.subtaskCompleted,
          user: 'Minh',
          title: 'Thay búa La 4',
          plan: 'Sửa chữa đàn',
          at: today(9, 20),
        ),
      ],
    );
    await t.pumpAndSettle();
    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('2 việc'), findsOneWidget);
    expect(find.text('HOÀNG ĐÃ XONG'), findsOneWidget);
    expect(find.text('Đánh bóng vỏ đàn Steinway'), findsOneWidget);
    expect(find.text('Sửa chữa đàn · 08:45'), findsOneWidget);
    expect(find.text('Minh · Thay búa La 4 – Steinway D'), findsOneWidget);
    expect(find.text('Chỉ hiện 7 ngày gần nhất.'), findsOneWidget);
  });

  testWidgets('giảm chuyển động: đổi tháng không để lại hoạt ảnh', (t) async {
    await host(t, kpiValue: kpi(delivered: 10), reduceMotion: true);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Tháng trước'));
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('chạm dòng việc mở /tasks/:id (cả hai loại dòng)', (t) async {
    final feed = [
      entry(
        id: 'a',
        kind: FeedKind.pianoDone,
        user: 'Hoàng',
        title: 'Đánh bóng vỏ đàn',
        plan: 'Sửa chữa đàn',
        at: today(8, 45),
      ),
      entry(
        id: 'b',
        kind: FeedKind.subtaskCompleted,
        user: 'Minh',
        title: 'Thay búa La 4',
        plan: 'Sửa chữa đàn',
        at: today(9, 20),
      ),
    ];

    await host(t, feed: feed);
    await t.pumpAndSettle();
    await t.tap(find.text('HOÀNG ĐÃ XONG'));
    await t.pumpAndSettle();
    expect(find.text('chi tiết t1'), findsOneWidget);

    await host(t, feed: feed);
    await t.pumpAndSettle();
    await t.tap(find.text('Minh · Thay búa La 4 – Steinway D'));
    await t.pumpAndSettle();
    expect(find.text('chi tiết t1'), findsOneWidget);
  });
}
