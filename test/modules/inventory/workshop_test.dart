import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/unit_sheet.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fake_http_adapter.dart';
import 'fake_inventory_api.dart';

/// Kho nối Xưởng phía Kho: đọc `workshop[]` đúng khoá của API
/// (`UnitWork::forUnits`), quy tắc "đang có việc tân trang mở", câu báo sau
/// khi đưa vào xưởng, body của `POST /tasks/from-units`, và nhóm "Xưởng" trong
/// sheet chi tiết cây.
void main() {
  Map<String, dynamic> work({
    String role = 'refurbish',
    String state = 'doing',
    int done = 8,
    int total = 10,
    String? step = 'Lên dây',
  }) => {
    'task_id': 't1',
    'title': 'YAMAHA U1E 1176498',
    'project_id': 'p1',
    'project_name': 'Tân trang đàn piano cơ',
    'role': role,
    'state': state,
    'done': done,
    'total': total,
    'step': step,
    'assignee_names': ['Thanh Hòa', 'Ngọc Trâm'],
    'completed_at': state == 'done' ? '2026-11-09T10:00:00Z' : null,
  };

  InventoryUnit unit(Object? workshop, {bool withKey = true}) =>
      InventoryUnit.fromJson({
        'id': 'u1',
        'lot_id': 'l61',
        'lot_code': 'Ep 61',
        'maker': 'YAMAHA',
        'model': 'U1E',
        'serial': '1176498',
        'place': 'in_stock',
        'condition': 'refurbishing',
        'list_price': 38500000,
        if (withKey) 'workshop': workshop,
      });

  group('đọc workshop', () {
    test('đủ khoá: mọi trường đọc đúng tên', () {
      final w = unit([work()]).workshop!.single;

      expect(w.taskId, 't1');
      expect(w.title, 'YAMAHA U1E 1176498');
      expect(w.projectId, 'p1');
      expect(w.projectName, 'Tân trang đàn piano cơ');
      expect(w.role, 'refurbish');
      expect(w.state, 'doing');
      expect(w.done, 8);
      expect(w.total, 10);
      expect(w.step, 'Lên dây');
      expect(w.assigneeNames, ['Thanh Hòa', 'Ngọc Trâm']);
      expect(w.completedAt, isNull);
      expect(w.roleLabel, 'Tân trang');
      expect(w.subtitle, 'Lên dây · Thanh Hòa, Ngọc Trâm');
      expect(w.progressLabel, '8/10');
      expect(w.progress, 0.8);
    });

    test('API cũ không có khoá: null, khác với mảng rỗng', () {
      expect(unit(null, withKey: false).workshop, isNull);
      expect(unit(null, withKey: false).workshopLabel, isNull);
      expect(unit(const <dynamic>[]).workshop, isEmpty);
      expect(unit(const <dynamic>[]).workshopLabel, 'Chưa vào xưởng');
    });

    test('kiểu lạ không ném', () {
      final w = unit([
        {'task_id': 9, 'done': '3', 'total': null, 'assignee_names': 'x'},
        'rác',
      ]).workshop!.single;

      expect(w.taskId, '9');
      expect(w.done, 3);
      expect(w.total, 0);
      expect(w.assigneeNames, isEmpty);
      expect(w.role, 'refurbish');
      expect(w.state, 'todo');
      expect(w.progressLabel, '');
    });

    test('việc xong: Đã hoàn thiện / Xong, vạch đầy', () {
      final w = unit([work(state: 'done', step: null)]).workshop!.single;

      expect(w.subtitle, 'Đã hoàn thiện');
      expect(w.progressLabel, 'Xong');
      expect(w.progress, 1);
    });
  });

  group('đang có việc tân trang mở', () {
    test('chỉ việc tân trang chưa xong mới chặn', () {
      expect(unit([work()]).hasOpenRefurbish, isTrue);
      expect(unit([work(state: 'todo', done: 0)]).hasOpenRefurbish, isTrue);
      expect(unit([work(state: 'done')]).hasOpenRefurbish, isFalse);
      expect(unit([work(role: 'warranty')]).hasOpenRefurbish, isFalse);
      expect(unit(const <dynamic>[]).hasOpenRefurbish, isFalse);
      expect(unit(null, withKey: false).hasOpenRefurbish, isFalse);
      // Việc cũ đã xong + việc mới đang mở.
      expect(unit([work(), work(state: 'done')]).hasOpenRefurbish, isTrue);
    });

    test('chữ ngắn trên dòng cây', () {
      expect(unit([work()]).workshopLabel, '8/10');
      expect(unit([work(total: 0, done: 0)]).workshopLabel, 'Ở xưởng');
      expect(unit([work(state: 'done')]).workshopLabel, 'Xong');
      expect(unit([work(role: 'warranty')]).workshopLabel, 'Chưa vào xưởng');
    });
  });

  test('câu báo sau khi đưa vào xưởng', () {
    expect(
      sendToWorkshopMessage((created: 3, skipped: const [])),
      'Đã tạo 3 việc xưởng.',
    );
    expect(
      sendToWorkshopMessage((created: 2, skipped: const ['u9'])),
      'Đã tạo 2 việc xưởng, bỏ qua 1 cây đang có việc tân trang.',
    );
    expect(
      sendToWorkshopMessage((created: 0, skipped: const ['u8', 'u9'])),
      'Không tạo việc nào: 2 cây đang có việc tân trang.',
    );
  });

  test('sendToWorkshop gửi đúng body và đọc meta', () async {
    final adapter = FakeAdapter(
      201,
      '{"success":true,"data":[{"id":"t1","title":"x"}],'
      '"meta":{"created":1,"skipped":["u2"]}}',
    );
    final api = InventoryApi(ApiClient(Dio()..httpClientAdapter = adapter));

    final res = await api.sendToWorkshop(
      projectId: 'p1',
      unitIds: ['u1', 'u2'],
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/tasks/from-units');
    expect(request.data, {
      'project_id': 'p1',
      'unit_ids': ['u1', 'u2'],
    });
    expect(res.created, 1);
    expect(res.skipped, ['u2']);
  });

  group('sheet chi tiết cây — nhóm Xưởng', () {
    Future<List<String>> pump(
      WidgetTester t,
      InventoryUnit u, {
      List<String> grants = const ['tasks.read'],
    }) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final opened = <String>[];
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryApiProvider.overrideWithValue(
              FakeInventoryApi(units: [u]),
            ),
            inventoryPermsProvider.overrideWithValue(
              const InventoryPerms(read: true),
            ),
            inventoryTodayProvider.overrideWithValue(DateTime(2026, 11, 10)),
            accessProvider.overrideWithValue(AccessPolicy(grants.toSet())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UnitSheet(
                unit: u,
                onChanged: (_) {},
                onOpenTask: opened.add,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return opened;
    }

    testWidgets(
      'mỗi việc một dòng: vai, công đoạn + người làm, tiến độ, mở việc',
      (t) async {
        final opened = await pump(
          t,
          unit([
            work(),
            {...work(role: 'warranty', state: 'done'), 'task_id': 't0'},
          ]),
        );

        expect(find.text('Xưởng'), findsOneWidget);
        expect(find.text('Tân trang'), findsOneWidget);
        expect(find.text('Lên dây · Thanh Hòa, Ngọc Trâm'), findsOneWidget);
        expect(find.text('8/10'), findsOneWidget);
        expect(find.text('Bảo hành'), findsOneWidget);
        expect(find.text('Đã hoàn thiện'), findsOneWidget);
        expect(find.text('Xong'), findsOneWidget);
        expect(find.byType(OmniProgressBar), findsNWidgets(2));
        expect(find.text('Chưa vào xưởng'), findsNothing);

        await t.tap(find.byKey(const ValueKey('inv-unit-work-t1')));
        await t.pump();
        expect(opened, ['t1']);
      },
    );

    testWidgets('chưa vào xưởng: một dòng mờ', (t) async {
      await pump(t, unit(const <dynamic>[]));

      expect(find.text('Xưởng'), findsOneWidget);
      expect(find.text('Chưa vào xưởng'), findsOneWidget);
      expect(find.byType(OmniProgressBar), findsNothing);
    });

    testWidgets('API cũ (không có khoá workshop): không có nhóm', (t) async {
      await pump(t, unit(null, withKey: false));

      expect(find.text('Xưởng'), findsNothing);
      expect(find.text('Chưa vào xưởng'), findsNothing);
    });

    testWidgets('thiếu quyền xem việc: dòng chỉ để đọc', (t) async {
      final opened = await pump(t, unit([work()]), grants: const []);

      await t.tap(find.byKey(const ValueKey('inv-unit-work-t1')));
      await t.pump();
      expect(opened, isEmpty);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });
}
