import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/completion_row.dart';
import 'package:omni_app/modules/plans/presentation/widgets/feed_skeleton.dart';
import 'package:omni_app/modules/plans/presentation/widgets/piano_done_row.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Màn Dòng việc trả lời "HÔM NAY ai xong cái gì".
///
/// Bản trước gom theo cây đàn và trộn mọi loại thay đổi — tạo việc, đổi hạn,
/// đổi người — nên việc xong lẫn trong tiếng ồn, và chỗ dễ thấy nhất của ngày
/// thì bị một khối cảnh báo cấu hình chiếm.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {
    'tasks.read',
    'tasks.write',
    'tasks.projects.manage.all',
  };

  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final today = iso(DateTime.now());
  final yesterday = iso(DateTime.now().subtract(const Duration(days: 1)));

  FeedEntry entry({
    String id = 'a1',
    FeedKind kind = FeedKind.subtaskCompleted,
    String? detail = 'Body ngoài',
    String taskTitle = 'KAWAI HAT-5',
    String? userName = 'Hằng Ni',
    String? planName = 'Phục chế T9',
    List<String> photos = const [],
    String? day,
  }) => FeedEntry(
    id: id,
    kind: kind,
    taskId: 't1',
    taskTitle: taskTitle,
    at: DateTime(2026, 9, 10, 9, 35),
    userName: userName,
    detail: detail,
    planName: planName,
    photos: photos,
    day: day ?? today,
  );

  Future<void> show(
    WidgetTester tester, {
    List<FeedEntry> feed = const [],
    bool truncated = false,
    Set<String> permissions = worker,
    bool kpiConfigured = true,
    int previousDelivered = 22,
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          // Mốc so sánh của thẻ KPI đi đường riêng; không đè thì nó gọi API
          // thật ngay trong test.
          kpiPreviousDeliveredProvider.overrideWith(
            (ref) async => previousDelivered,
          ),
          workshopFeedProvider.overrideWith(
            (ref) async => (entries: feed, truncated: truncated),
          ),
          workshopKpiProvider.overrideWith(
            (ref) async => WorkshopKpi(
              delivered: 28,
              reachedBonus: 0,
              daysLeft: 10,
              tiers: const [BonusTier(count: 35, bonus: 3)],
              isConfigured: kpiConfigured,
              rework: 0,
              nextTier: const NextTier(count: 35, bonus: 3, remaining: 7),
            ),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(permissions)),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TimelinePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('gom theo ngày và đếm hai loại riêng', (tester) async {
    await show(
      tester,
      feed: [
        entry(id: 'a1'),
        entry(id: 'a2', detail: 'Lên dây'),
        entry(id: 'a3', kind: FeedKind.pianoDone),
      ],
    );

    // Hai con số RIÊNG. Gộp thành "3 việc xong" sẽ đá nhau với thẻ KPI, thứ
    // chỉ đếm cây.
    expect(
      find.text('HÔM NAY · 2 công đoạn · 1 cây xong'),
      findsOneWidget,
    );
  });

  testWidgets('mỗi ngày một tiêu đề riêng', (tester) async {
    await show(
      tester,
      feed: [entry(id: 'a1'), entry(id: 'a2', day: yesterday)],
    );

    expect(find.textContaining('HÔM NAY'), findsOneWidget);
    expect(find.textContaining('HÔM QUA'), findsOneWidget);
  });

  testWidgets('ảnh bằng chứng hiện NGAY trên dòng việc xong', (tester) async {
    // §B2: ảnh CHÍNH LÀ bằng chứng của công đoạn. Bắt mở từng cây đàn ra để
    // xem là bỏ mất lý do người ta lướt màn này.
    await show(
      tester,
      feed: [
        entry(photos: const ['/m/1.jpg', '/m/2.jpg']),
      ],
    );

    // Đếm theo KHOÁ chứ không theo `Image`, và KHÔNG bỏ qua offstage.
    //
    // Trong test không có mạng, nên `Image.network` hỏng và `errorBuilder` trả
    // về một ô rỗng — ô ảnh vẫn được DỰNG nhưng có kích thước 0, và finder mặc
    // định coi nó là offstage. Câu hỏi ở đây là "màn hình có chừa chỗ cho đủ
    // hai tấm ảnh không", không phải "ảnh có tải được trong test không".
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('photo:'),
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('không có ảnh thì không chừa dải trống', (tester) async {
    await show(tester, feed: [entry()]);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('photo:'),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('dòng cây đàn xong khác hẳn dòng công đoạn', (tester) async {
    await show(
      tester,
      feed: [entry(id: 'a1'), entry(id: 'a2', kind: FeedKind.pianoDone)],
    );

    expect(find.byType(PianoDoneRow), findsOneWidget);
    expect(find.byType(CompletionRow), findsOneWidget);
  });

  testWidgets('câu nói rõ AI và LÀM GÌ', (tester) async {
    await show(tester, feed: [entry()]);

    expect(find.text('Hằng Ni đã xong Body ngoài'), findsOneWidget);
  });

  testWidgets('rỗng thì nói đúng cái đang rỗng', (tester) async {
    await show(tester, feed: const []);

    // KHÔNG phải "chưa có hoạt động nào": có thể có rất nhiều hoạt động mà
    // không có việc nào được đánh dấu xong. Nói nhầm thì người đọc đi tìm sai
    // chỗ.
    expect(
      find.textContaining('Chưa có việc nào được đánh dấu xong'),
      findsOneWidget,
    );
  });

  testWidgets('cắt bớt thì NÓI RA', (tester) async {
    await show(tester, feed: [entry()], truncated: true);

    expect(find.text('Chỉ hiện 7 ngày gần nhất.'), findsOneWidget);
  });

  testWidgets('không cắt thì không doạ', (tester) async {
    await show(tester, feed: [entry()]);

    expect(find.text('Chỉ hiện 7 ngày gần nhất.'), findsNothing);
  });

  testWidgets('thợ KHÔNG thấy thẻ KPI', (tester) async {
    // §1: thưởng theo TEAM. Bày mốc thưởng ra trước mặt từng người là đổi cách
    // xưởng làm việc.
    await show(tester, feed: [entry()]);

    expect(find.text('28'), findsNothing);
  });

  testWidgets('người giao việc thấy thẻ KPI', (tester) async {
    await show(tester, feed: [entry()], permissions: assigner);

    expect(find.text('28'), findsOneWidget);
  });

  testWidgets('KPI chưa cấu hình không chiếm chỗ của dòng việc', (
    tester,
  ) async {
    await show(
      tester,
      feed: [entry()],
      permissions: assigner,
      kpiConfigured: false,
    );

    expect(
      find.textContaining('nên chưa đếm được việc nào hoàn thành'),
      findsNothing,
    );
    expect(find.text('Đánh dấu nhóm việc đích'), findsOneWidget);
    // Dòng việc vẫn ở đó, không bị đẩy xuống dưới màn hình.
    expect(find.text('Hằng Ni đã xong Body ngoài'), findsOneWidget);
  });

  testWidgets('giờ hiện TUYỆT ĐỐI, không phải "2 giờ trước"', (tester) async {
    // Quản đốc đối chiếu dòng này với ca làm và với lời thợ nói.
    await show(tester, feed: [entry()]);

    expect(find.text('09:35'), findsOneWidget);
  });

  testWidgets('ảnh gửi lẻ vẫn hiện, không bị nuốt', (tester) async {
    await show(
      tester,
      feed: [
        entry(id: 'a1', kind: FeedKind.attachmentAdded, detail: 'mau.jpg'),
      ],
    );

    expect(find.text('Hằng Ni đã gửi mau.jpg'), findsOneWidget);
  });

  testWidgets('tải lần đầu hiện KHUNG XƯƠNG dòng việc, không phải vòng xoay', (
    tester,
  ) async {
    // Đây là màn đầu tiên mở lên mỗi sáng. Một vòng xoay giữa màn trắng nói
    // "chưa có gì" — khung xương nói "sắp có, và trông thế này". Cùng thời
    // gian chờ, cảm giác khác hẳn, và khi dữ liệu tới thì không nhảy bố cục.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workshopFeedProvider.overrideWith(
            (ref) => Completer<WorkshopFeed>().future,
          ),
          workshopKpiProvider.overrideWith(
            (ref) => Completer<WorkshopKpi>().future,
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(const AccessPolicy(worker)),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TimelinePage(),
        ),
      ),
    );
    // KHÔNG pumpAndSettle: khung xương nhấp nháy mãi cho tới khi có dữ liệu.
    await tester.pump();

    expect(find.byType(FeedSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byType(OmniSkeletonBox, skipOffstage: false),
      findsAtLeastNWidgets(4),
      reason: 'khung xương phải trông như vài dòng việc, không phải một khối',
    );
  });

  testWidgets('ảnh hỏng vẫn để lại ô 88dp có biểu tượng, không phải lỗ trống', (
    tester,
  ) async {
    // Trong test không có mạng nên ảnh nào cũng hỏng — đúng tình huống ngoài
    // xưởng khi sóng yếu. Ô rỗng 0dp làm dải ảnh co lại rồi giãn ra khi ảnh
    // tới, và người đọc không biết là có ảnh đang chờ.
    await show(tester, feed: [entry(photos: const ['/m/1.jpg'])]);

    final tile = find.byKey(const ValueKey('photo:/m/1.jpg'));
    expect(tester.getSize(tile), const Size(88, 88));
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.broken_image_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('thẻ KPI so con số với tháng trước', (tester) async {
    // "28" một mình không nói nhiều hay ít. Mốc tự nhiên nhất là tháng trước.
    await show(
      tester,
      feed: [entry()],
      permissions: assigner,
      previousDelivered: 22,
      extra: [kpiMonthProvider.overrideWith((ref) => DateTime(2026, 9))],
    );

    expect(find.text('28'), findsOneWidget);
    expect(find.text('+6 so với tháng 8'), findsOneWidget);
  });
}
