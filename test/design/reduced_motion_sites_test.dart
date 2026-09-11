import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/settings/presentation/widgets/account_menu_button.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Ba chỗ còn tự chạy hiệu ứng bất kể cài đặt "giảm chuyển động".
///
/// `OmniMotion` đã có và bảng dự án đã nghe nó (`reduced_motion_test.dart`),
/// nhưng ba chỗ thêm sau vẫn ghi cứng thời lượng: dòng vừa tới trên Dòng việc
/// trượt lên, avatar chéo mờ khi đổi ảnh, và khung xương nhấp nháy mãi. Đây là
/// cài đặt trợ năng thật — có người chóng mặt vì chuyển cảnh — và hệ điều hành
/// đã hỏi họ rồi; app chỉ việc nghe.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget reduced(Widget child, {required bool disabled}) => MediaQuery(
    data: MediaQueryData(disableAnimations: disabled),
    child: child,
  );

  group('khung xương', () {
    Color? colourOf(WidgetTester tester) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(OmniSkeletonBox),
          matching: find.byType(Container),
        ),
      );

      return (box.decoration as BoxDecoration?)?.color;
    }

    Widget host({required bool disabled}) => reduced(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const Scaffold(body: OmniSkeletonBox(height: 40)),
      ),
      disabled: disabled,
    );

    testWidgets('bình thường thì nhấp nháy', (tester) async {
      await tester.pumpWidget(host(disabled: false));
      final before = colourOf(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(colourOf(tester), isNot(before));
    });

    testWidgets('khi tắt hiệu ứng thì đứng yên', (tester) async {
      // Nhấp nháy là chuyển động: một mảng sáng tối đều đặn khắp màn hình,
      // đúng thứ cài đặt này nhắm tới.
      await tester.pumpWidget(host(disabled: true));
      final before = colourOf(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(colourOf(tester), before);
    });
  });

  group('avatar ở góc phải', () {
    final session = Session(
      status: SessionStatus.authenticated,
      user: const SessionUser(
        id: 'u-1',
        fullName: 'Hằng Ni',
        email: 'hangni@tnp.vn',
      ),
      tenant: const SessionTenant(id: 't-1', name: 'Xưởng piano TNP'),
    );

    Widget host({required bool disabled}) => ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session)],
      child: reduced(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const Scaffold(body: AccountMenuButton()),
        ),
        disabled: disabled,
      ),
    );

    testWidgets('bình thường thì chéo mờ theo thang chung', (tester) async {
      await tester.pumpWidget(host(disabled: false));

      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, OmniDuration.base);
    });

    testWidgets('khi tắt hiệu ứng thì đổi ảnh tức thì', (tester) async {
      await tester.pumpWidget(host(disabled: true));

      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, Duration.zero);
    });
  });

  group('dòng vừa tới trên Dòng việc', () {
    FeedEntry entry(String id, String detail) => FeedEntry(
      id: id,
      kind: FeedKind.subtaskCompleted,
      taskId: 't1',
      taskTitle: 'KAWAI HAT-5',
      at: DateTime(2026, 9, 10, 9, 35),
      userName: 'Hằng Ni',
      detail: detail,
      day:
          '${DateTime.now().year}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}',
    );

    /// Danh sách do test điều khiển; đổi nó là "một dòng vừa tới qua realtime".
    final rows = StateProvider<List<FeedEntry>>((ref) => [entry('a1', 'Body')]);

    Widget host({required bool disabled}) => ProviderScope(
      overrides: [
        workshopFeedProvider.overrideWith(
          (ref) async => (entries: ref.watch(rows), truncated: false),
        ),
        kpiPreviousDeliveredProvider.overrideWith((ref) async => 0),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(const AccessPolicy({'tasks.read', 'tasks.write'})),
        ),
      ],
      child: reduced(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TimelinePage(),
        ),
        disabled: disabled,
      ),
    );

    /// Thả dòng thứ hai vào và vẽ khung hình đầu tiên có nó.
    Future<void> arrive(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TimelinePage)),
      );
      container.read(rows.notifier).state = [
        entry('a2', 'Lên dây'),
        entry('a1', 'Body'),
      ];
      await tester.pump();
      await tester.pump();
    }

    Finder faded() => find.ancestor(
      of: find.text('Hằng Ni đã xong Lên dây'),
      matching: find.byType(Opacity),
    );

    testWidgets('bình thường thì mờ dần vào', (tester) async {
      await tester.pumpWidget(host(disabled: false));
      await tester.pumpAndSettle();

      await arrive(tester);

      expect(find.text('Hằng Ni đã xong Lên dây'), findsOneWidget);
      expect(faded(), findsOneWidget);
    });

    testWidgets('khi tắt hiệu ứng thì hiện ngay, không mờ không trượt', (
      tester,
    ) async {
      await tester.pumpWidget(host(disabled: true));
      await tester.pumpAndSettle();

      await arrive(tester);

      expect(find.text('Hằng Ni đã xong Lên dây'), findsOneWidget);
      expect(faded(), findsNothing);
    });
  });
}
