import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/pin_tabs_page.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

class _FakeModule extends OmniModule {
  const _FakeModule(this._entries);

  final List<ModuleNavEntry> _entries;

  @override
  String get id => 'fake';

  @override
  String get title => 'Fake';

  @override
  List<ModuleRoute> routes() => const [];

  @override
  List<ModuleNavEntry> navEntries() => _entries;
}

ModuleNavEntry _entry(String label) => ModuleNavEntry(
  moduleId: label,
  label: label,
  routeName: 'route.$label',
  icon: Icons.circle_outlined,
  selectedIcon: Icons.circle,
  area: NavArea.work,
  weight: NavWeight.primary,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entries = ['Một', 'Hai', 'Ba', 'Bốn', 'Năm'].map(_entry).toList();

  Future<void> pump(WidgetTester tester, List<String> pinned) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modulesProvider.overrideWithValue([_FakeModule(entries)]),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy({}),
            ),
          ),
          pinnedTabsProvider.overrideWith(() => _StubPins(pinned)),
        ],
        child: const MaterialApp(home: PinTabsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('không có thao tác kéo nào', (tester) async {
    // Luật accessibility: thao tác kéo bắt buộc phải có cách thay thế. Chọn
    // bằng checkbox là ĐÃ đáp ứng sẵn, lại ít code hơn kéo-thả.
    await pump(tester, const []);

    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byType(Draggable<Object>), findsNothing);
  });

  testWidgets('mọi mục primary đều chọn được khi chưa đủ 4', (tester) async {
    await pump(tester, const []);

    final tiles = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );

    expect(tiles.length, 5);
    expect(tiles.every((t) => t.onChanged != null), isTrue);
  });

  testWidgets('đủ 4 thì ô chưa chọn tắt hẳn VÀ nói vì sao', (tester) async {
    // Một checkbox bấm không ăn mà không giải thích là lỗi giao diện — người
    // dùng không đọc được ý định của ta, họ chỉ thấy nút hỏng.
    await pump(tester, ['route.Một', 'route.Hai', 'route.Ba', 'route.Bốn']);

    final blocked = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Năm'),
    );

    expect(blocked.onChanged, isNull);
    expect(find.textContaining('Đã đủ 4 tab'), findsOneWidget);
  });

  testWidgets('mục đã chọn vẫn bỏ chọn được khi đã đủ 4', (tester) async {
    // Nếu không, người dùng kẹt cứng: đủ 4 rồi thì không đổi được gì nữa.
    await pump(tester, ['route.Một', 'route.Hai', 'route.Ba', 'route.Bốn']);

    final checked = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Một'),
    );

    expect(checked.value, isTrue);
    expect(checked.onChanged, isNotNull);
  });

  testWidgets('chưa ghim gì thì không hiện nút đặt lại', (tester) async {
    // Không có gì để đặt lại thì nút đó chỉ là một câu hỏi không lời đáp.
    await pump(tester, const []);

    expect(find.text('Đặt lại về mặc định'), findsNothing);
  });

  testWidgets('đã ghim thì có nút đặt lại', (tester) async {
    await pump(tester, ['route.Một']);

    expect(find.text('Đặt lại về mặc định'), findsOneWidget);
  });
}

class _StubPins extends PinnedTabs {
  _StubPins(this._pinned);

  final List<String> _pinned;

  @override
  Future<List<String>> build() async => _pinned;
}
