import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_fields_page.dart';

/// Trường tuỳ chỉnh: gửi cả mảng `custom_fields`, phần tử cũ giữ nguyên.
void main() {
  late _FakePlansApi api;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakePlansApi(
      Plan.fromJson(const {
        'id': 'p1',
        'name': 'Bảo hành',
        'custom_fields': [
          {'id': 'f1', 'name': 'Số máy', 'type': 'text'},
          {
            'id': 'f2',
            'name': 'Loại đàn',
            'type': 'select',
            'options': ['Cơ', 'Điện'],
          },
        ],
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plansApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanFieldsPage(planId: 'p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('liệt kê tên và kiểu', (tester) async {
    await pump(tester);
    expect(find.text('Số máy'), findsOneWidget);
    expect(find.text('Chữ'), findsOneWidget);
    expect(find.text('Chọn · 2 lựa chọn'), findsOneWidget);
  });

  testWidgets('(e) thêm "Hãng" kiểu chữ: phần tử cũ giữ nguyên', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Thêm trường'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), 'Hãng');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xong'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final sent = api.patches.single.toJson();
    expect(sent.keys, ['custom_fields']);
    final fields = sent['custom_fields'] as List;
    expect(fields, hasLength(3));
    expect(fields[0], {'id': 'f1', 'name': 'Số máy', 'type': 'text'});
    expect(fields[1], {
      'id': 'f2',
      'name': 'Loại đàn',
      'type': 'select',
      'options': ['Cơ', 'Điện'],
    });
    final added = fields[2] as Map;
    expect(added['name'], 'Hãng');
    expect(added['type'], 'text');
    expect((added['id'] as String).length, inInclusiveRange(1, 64));
    expect(added['id'], isNot(anyOf('f1', 'f2')));
  });

  testWidgets('thêm trường kiểu chọn gửi options, bỏ dòng trống', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Thêm trường'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), 'Màu');
    await tester.pump();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field-options')),
      'Đen\n\nTrắng ',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xong'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final fields = api.patches.single.toJson()['custom_fields'] as List;
    expect((fields.last as Map)['type'], 'select');
    expect((fields.last as Map)['options'], ['Đen', 'Trắng']);
  });

  testWidgets('lựa chọn dài quá 128 ký tự: báo lỗi, không cho Xong', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Thêm trường'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), 'Màu');
    await tester.pump();
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field-options')),
      'Đen\n${'a' * 129}',
    );
    await tester.pump();

    expect(
      find.text('Mỗi lựa chọn tối đa 128 ký tự (dòng 2).'),
      findsOneWidget,
    );
    final done = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Xong'),
    );
    expect(done.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('field-options')),
      'Đen\n${'a' * 128}',
    );
    await tester.pump();
    expect(find.textContaining('tối đa 128'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xong'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('xoá trường hỏi lại rồi gửi mảng thiếu nó', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Xoá trường Số máy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xoá trường'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final fields = api.patches.single.toJson()['custom_fields'] as List;
    expect(fields.map((f) => (f as Map)['id']), ['f2']);
  });

  testWidgets('sửa tên một trường giữ id', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Số máy'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), 'Số seri');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Xong'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final fields = api.patches.single.toJson()['custom_fields'] as List;
    expect(fields.first, {'id': 'f1', 'name': 'Số seri', 'type': 'text'});
  });
}

class _FakePlansApi implements PlansApi {
  _FakePlansApi(this._plan);

  final Plan _plan;
  final patches = <PlanPatch>[];

  @override
  Future<Plan> plan(String id) async => _plan;

  @override
  Future<Plan> updatePlan(String planId, PlanPatch patch) async {
    patches.add(patch);
    return _plan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
