import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/edit_plan_page.dart';

/// Sửa tên, mô tả, nền: chỉ gửi khoá đã đổi.
void main() {
  late _FakePlansApi api;

  Future<void> pump(WidgetTester tester, Map<String, dynamic> json) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakePlansApi(Plan.fromJson(json));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plansApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const EditPlanPage(planId: 'p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const base = {
    'id': 'p1',
    'name': 'Bảo hành',
    'description': 'Việc bảo hành đàn',
    'cover': 'plum-1',
  };

  testWidgets('(b) sửa tên gửi đúng {name}', (tester) async {
    await pump(tester, base);

    await tester.enterText(
      find.widgetWithText(TextField, 'Bảo hành'),
      'Bảo hành 2026',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'name': 'Bảo hành 2026'});
  });

  testWidgets('(c) đổi nền gửi đúng {cover: indigo-1}', (tester) async {
    await pump(tester, base);

    await tester.tap(find.byKey(const ValueKey('cover:indigo-1')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'cover': 'indigo-1'});
  });

  testWidgets('xoá mô tả gửi chuỗi rỗng; chưa đổi gì thì Lưu tắt', (
    tester,
  ) async {
    await pump(tester, base);
    final save = find.widgetWithText(FilledButton, 'Lưu');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Việc bảo hành đàn'),
      '  ',
    );
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'description': ''});
  });

  testWidgets('tên rỗng thì không lưu được', (tester) async {
    await pump(tester, base);
    await tester.enterText(find.widgetWithText(TextField, 'Bảo hành'), ' ');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('kế hoạch chưa có nền: chọn lại nền mặc định không gửi gì', (
    tester,
  ) async {
    await pump(tester, {'id': 'p1', 'name': 'Cũ'});
    await tester.tap(find.byKey(const ValueKey('cover:teal-1')));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('ô nền là vùng chạm 44', (tester) async {
    await pump(tester, base);
    expect(
      tester.getSize(find.byKey(const ValueKey('cover:indigo-1'))),
      const Size(44, 44),
    );
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
