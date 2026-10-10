import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/notifications/presentation/notifications_page.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

class _FakeApi implements NotificationsApi {
  _FakeApi({required this.unread, this.emptyWhenUnreadOnly = false});

  final int unread;
  final bool emptyWhenUnreadOnly;

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final now = DateTime.now();
    final items = unreadOnly && emptyWhenUnreadOnly
        ? <AppNotification>[]
        : [
            AppNotification(
              id: 'n1',
              kind: NotificationKind.taskAssigned,
              title: 'tn1',
              body: 'bn1',
              createdAt: now,
              entityType: 'task',
              entityId: 't1',
            ),
            AppNotification(
              id: 'n2',
              kind: NotificationKind.inboxMessage,
              title: 'tn2',
              body: 'bn2',
              createdAt: now.subtract(const Duration(days: 1)),
              entityType: 'conversation',
              entityId: 'c1',
            ),
            AppNotification(
              id: 'n3',
              kind: NotificationKind.other,
              title: 'tn3',
              body: 'bn3',
              createdAt: now.subtract(const Duration(days: 1)),
              readAt: now,
            ),
          ];
    return Paged(
      items: items,
      pagination: ApiPagination(
        currentPage: 1,
        perPage: perPage,
        total: items.length,
        lastPage: 1,
      ),
    );
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<int> unreadCount() async => unread;
}

void main() {
  final tasks = <String>[];
  final convs = <String>[];

  setUp(() {
    tasks.clear();
    convs.clear();
  });

  Future<void> pump(
    WidgetTester t, {
    int unread = 2,
    bool emptyWhenUnreadOnly = false,
    bool reducedMotion = false,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsApiProvider.overrideWithValue(
            _FakeApi(unread: unread, emptyWhenUnreadOnly: emptyWhenUnreadOnly),
          ),
          sessionProvider.overrideWithValue(const Session.unauthenticated()),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: NotificationsPage(
            onOpenTask: tasks.add,
            onOpenConversation: convs.add,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('nhóm Hôm nay / Trước đó và thanh chọn có số server', (t) async {
    await pump(t);
    expect(find.text('HÔM NAY'), findsNothing);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Trước đó'), findsOneWidget);
    expect(find.text('Chưa đọc · 2'), findsOneWidget);
  });

  testWidgets(
    'bấm tin nhắn mở hội thoại, bấm việc mở việc, loại lạ không đi đâu',
    (t) async {
      await pump(t);
      await t.tap(find.text('tn2'));
      await t.tap(find.text('tn1'));
      await t.tap(find.text('tn3'));
      await t.pump();
      expect(convs, ['c1']);
      expect(tasks, ['t1']);
    },
  );

  testWidgets('dòng là nút có nhãn "Chưa đọc, …" và nhận onTap ngữ nghĩa', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(t);
    final node = t.getSemantics(find.bySemanticsLabel('Chưa đọc, tn2'));
    expect(node, isSemantics(isButton: true, hasTapAction: true));
    expect(find.bySemanticsLabel('tn3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Chưa đọc trống → "Bạn đã đọc hết thông báo"', (t) async {
    await pump(t, emptyWhenUnreadOnly: true);
    await t.tap(find.text('Chưa đọc · 2'));
    await t.pumpAndSettle();
    expect(find.text('Bạn đã đọc hết thông báo'), findsOneWidget);
  });

  testWidgets('Đọc hết bị khoá khi N = 0', (t) async {
    await pump(t, unread: 0);
    final b = t.widget<TextButton>(find.widgetWithText(TextButton, 'Đọc hết'));
    expect(b.onPressed, isNull);
  });

  testWidgets('giảm chuyển động: không còn khung hoạt ảnh sau một pump', (
    t,
  ) async {
    await pump(t, reducedMotion: true);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('có chuyển động: mỗi nhóm dùng hiệu ứng rise', (t) async {
    await pump(t);
    expect(find.byType(TweenAnimationBuilder<double>), findsNWidgets(2));
  });
}
