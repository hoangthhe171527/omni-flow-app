import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/tasks.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Sheet Nhãn màu (`TaskDetail.dc.html` `isLabels`): dải 48 tô màu nhãn, bút
/// sửa 44×48, dòng "Nhãn mới…" nét đứt — bút và dòng mới chỉ khi có
/// `system_options.write`.
void main() {
  late _FakeTasksApi api;

  const labels = [
    TaskLabel(id: 'o1', code: 'khan_cap', label: 'Khẩn cấp', color: '#B42318'),
    TaskLabel(id: 'o2', code: 'bao_hanh', label: 'Bảo hành', color: '#6D28D9'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    Set<String> perms = const {'system_options.read', 'system_options.write'},
    Set<String>? selected,
    ValueChanged<String>? onToggle,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakeTasksApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          taskLabelsProvider.overrideWith((ref) async => labels),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(perms)),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: LabelsSheet(selected: selected, onToggle: onToggle),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dải nhãn 48, bo 8, màu nhãn, chữ trắng w600 15', (tester) async {
    await pump(tester);

    expect(find.text('Nhãn màu'), findsOneWidget);
    expect(find.text('Xong'), findsOneWidget);
    final row = find.byKey(const Key('label-row-khan_cap'));
    expect(tester.getSize(row).height, 48);
    final deco =
        tester
                .widget<Ink>(
                  find.descendant(of: row, matching: find.byType(Ink)),
                )
                .decoration!
            as BoxDecoration;
    expect(deco.color, const Color(0xFFB42318));
    expect(deco.borderRadius, BorderRadius.circular(8));
    final text = tester.widget<Text>(find.text('Khẩn cấp'));
    expect(text.style?.color, Colors.white);
    expect(text.style?.fontSize, 15);
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(
      tester.getSize(find.bySemanticsLabel('Sửa nhãn Khẩn cấp')),
      const Size(44, 48),
    );
    expect(find.text('Nhãn dùng chung cho cả công ty'), findsOneWidget);
  });

  testWidgets('(h) thiếu quyền sửa nhãn: không bút, không "Nhãn mới…"', (
    tester,
  ) async {
    await pump(tester, perms: const {'system_options.read'});

    expect(find.text('Khẩn cấp'), findsOneWidget);
    expect(find.bySemanticsLabel('Sửa nhãn Khẩn cấp'), findsNothing);
    expect(find.text('Nhãn mới…'), findsNothing);
    expect(find.byTooltip('Thêm nhãn'), findsNothing);
  });

  testWidgets('chỉ xem (từ kế hoạch): chạm dải không bật/tắt, không ✓', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Khẩn cấp'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('mở từ việc: có ✓ khi bật, chạm gọi onToggle', (tester) async {
    final toggled = <String>[];
    await pump(tester, selected: {'bao_hanh'}, onToggle: toggled.add);

    expect(
      find.descendant(
        of: find.byKey(const Key('label-row-bao_hanh')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Khẩn cấp'));
    await tester.pump();
    expect(toggled, ['khan_cap']);
    expect(
      find.descendant(
        of: find.byKey(const Key('label-row-khan_cap')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tạo nhãn mới với màu chọn nhanh', (tester) async {
    await pump(tester);

    expect(find.text('Nhãn mới…'), findsOneWidget);
    await tester.enterText(
      find.bySemanticsLabel('Tên nhãn mới'),
      'Chờ linh kiện',
    );
    await tester.tap(find.bySemanticsLabel('Màu #2563EB'));
    await tester.pump();
    await tester.tap(find.byTooltip('Thêm nhãn'));
    await tester.pumpAndSettle();

    expect(api.created, [('Chờ linh kiện', '#2563EB')]);
  });

  testWidgets('sửa nhãn gửi tên và màu theo id', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Sửa nhãn Khẩn cấp'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label-name')), 'Gấp');
    await tester.tap(find.bySemanticsLabel('Màu #0A7D76').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(api.updated, [('o1', 'Gấp', '#0A7D76')]);
  });
}

class _FakeTasksApi implements TasksApi {
  final created = <(String, String?)>[];
  final updated = <(String, String, String?)>[];

  @override
  Future<TaskLabel> createLabel({required String label, String? color}) async {
    created.add((label, color));
    return TaskLabel(id: 'n', code: 'n', label: label, color: color);
  }

  @override
  Future<TaskLabel> updateLabel(
    String id, {
    required String label,
    String? color,
  }) async {
    updated.add((id, label, color));
    return TaskLabel(id: id, code: 'x', label: label, color: color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
