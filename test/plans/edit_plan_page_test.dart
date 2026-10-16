import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plan_cover_upload.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/edit_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/cover_picker.dart';

/// Sửa tên, mô tả và ảnh nền: JSON và multipart là hai contract độc lập.
void main() {
  late _FakePlansApi api;
  late _FakePlanCoverApi coverApi;

  Future<void> pump(WidgetTester tester, Map<String, dynamic> json) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakePlansApi(Plan.fromJson(json));
    coverApi = _FakePlanCoverApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(api),
          planCoverApiProvider.overrideWithValue(coverApi),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const EditPlanPage(planId: 'p1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  const base = {
    'id': 'p1',
    'name': 'Bảo hành',
    'description': 'Việc bảo hành đàn',
    'cover': 'plum-1',
  };

  testWidgets('sửa tên chỉ gửi đúng {name}', (tester) async {
    await pump(tester, base);

    await tester.enterText(
      find.widgetWithText(TextField, 'Bảo hành'),
      'Bảo hành 2026',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.patches.single.toJson(), {'name': 'Bảo hành 2026'});
    expect(coverApi.uploads, isEmpty);
  });

  testWidgets('chọn ảnh mới tải multipart qua endpoint cover', (tester) async {
    await pump(tester, base);

    tester
        .widget<CoverPicker>(find.byType(CoverPicker))
        .onPicked('/tmp/anh-nen.jpg');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.patches, isEmpty);
    expect(coverApi.uploads, [('p1', '/tmp/anh-nen.jpg')]);
  });

  testWidgets('bỏ ảnh URL hiện tại gọi DELETE cover', (tester) async {
    await pump(tester, {
      ...base,
      'cover': '/api/v1/projects/media/tenant/p1.webp',
    });

    tester.widget<CoverPicker>(find.byType(CoverPicker)).onRemove!();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(coverApi.removals, ['p1']);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

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

  testWidgets('token màu cũ dùng nền hệ thống và không tạo thay đổi giả', (
    tester,
  ) async {
    await pump(tester, base);

    final picker = tester.widget<CoverPicker>(find.byType(CoverPicker));
    expect(picker.remoteUrl, isNull);
    expect(find.text('Nền hệ thống'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('upload lỗi giữ ảnh đã chọn để người dùng thử lại', (
    tester,
  ) async {
    await pump(tester, base);
    coverApi.failure = const NetworkException('Mạng không ổn định');

    tester
        .widget<CoverPicker>(find.byType(CoverPicker))
        .onPicked('/tmp/anh-loi.jpg');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mạng không ổn định'), findsWidgets);
    expect(
      tester.widget<CoverPicker>(find.byType(CoverPicker)).localPath,
      '/tmp/anh-loi.jpg',
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

class _FakePlanCoverApi implements PlanCoverApi {
  final uploads = <(String, String)>[];
  final removals = <String>[];
  AppException? failure;

  @override
  Future<String> upload(String planId, String filePath) async {
    if (failure case final error?) throw error;
    uploads.add((planId, filePath));
    return '/api/v1/projects/media/tenant/new.webp';
  }

  @override
  Future<void> remove(String planId) async {
    if (failure case final error?) throw error;
    removals.add(planId);
  }
}
