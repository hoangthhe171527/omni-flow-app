import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/issue_widgets.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/task_menu_sheet.dart';

import '../support/fake_http_adapter.dart';

/// Cờ vấn đề trên việc (TNP_DON_HANG_THEO_CAY §4.3, API #111).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('đọc cờ', () {
    test('API cũ thiếu khoá / null / thiếu note → không có cờ', () {
      expect(Task.fromJson(const {'id': 't'}).issue, isNull);
      expect(Task.fromJson(const {'id': 't', 'issue': null}).issue, isNull);
      expect(TaskIssue.parse(const {'comment_id': 'c'}), isNull);
    });

    test('đọc ghi chú, người báo, giờ; bỏ ảnh không có url', () {
      final t = Task.fromJson(const {
        'id': 't',
        'issue': {
          'comment_id': 'c1',
          'note': 'Nứt bảng',
          'photos': [
            {'id': 'a', 'url': 'https://x/a.jpg'},
            {'id': 'b', 'url': null},
          ],
          'by': 'u1',
          'by_name': 'Bảo',
          'at': '2026-11-11T14:20:00+07:00',
        },
        'comments': [
          {'id': 'c1', 'body': 'Nứt bảng', 'kind': 'issue'},
          {'id': 'c2', 'body': 'Đã xử lý', 'kind': 'issue_resolved'},
          {'id': 'c3', 'body': 'x', 'kind': 'lạ'},
        ],
      });
      expect(t.issue?.note, 'Nứt bảng');
      expect(t.issue?.byName, 'Bảo');
      expect(t.issue?.photoUrls, ['https://x/a.jpg']);
      expect(t.issue?.at, isNotNull);
      expect(t.comments.map((c) => c.kind), ['issue', 'issue_resolved', null]);
    });
  });

  test('menu ⋯: "Đã xử lý" chỉ khi được tắt cờ, kể cả việc khoá', () {
    List<TaskMenuAction> all({bool resolve = false, bool locked = false}) => [
      for (final g in taskMenuGroups(
        canLabels: false,
        isAssigner: false,
        archived: false,
        locked: locked,
        canResolveIssue: resolve,
      ))
        ...g,
    ];
    expect(all(), isNot(contains(TaskMenuAction.resolveIssue)));
    expect(all(resolve: true), contains(TaskMenuAction.resolveIssue));
    expect(
      all(resolve: true, locked: true),
      contains(TaskMenuAction.resolveIssue),
    );
  });

  group('API', () {
    test('báo vấn đề: POST /tasks/{id}/issue multipart note', () async {
      final adapter = FakeAdapter(201, envelope({'id': 't1', 'title': 'x'}));
      final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));
      await api.reportIssue('t1', '  Nứt bảng  ');
      final r = adapter.requests.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '/api/v1/tasks/t1/issue');
      final form = r.data as FormData;
      expect(form.fields.single.key, 'note');
      expect(form.fields.single.value, 'Nứt bảng');
    });

    test('tắt cờ: POST /tasks/{id}/issue/resolve', () async {
      final adapter = FakeAdapter(200, envelope({'id': 't1', 'title': 'x'}));
      final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));
      await api.resolveIssue('t1');
      expect(
        adapter.requests.single.uri.path,
        '/api/v1/tasks/t1/issue/resolve',
      );
    });
  });

  testWidgets('tấm Báo vấn đề: Gửi tắt khi trống, trả ghi chú đã nhập', (
    t,
  ) async {
    IssueDraft? got;
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showReportIssueSheet(context),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    final send = find.byKey(const Key('issue-send'));
    expect(t.widget<FilledButton>(send).onPressed, isNull);
    await t.enterText(find.byKey(const Key('issue-note')), 'Nứt bảng');
    await t.pumpAndSettle();
    await t.tap(send);
    await t.pumpAndSettle();

    expect(got?.note, 'Nứt bảng');
    expect(got?.photos, isEmpty);
  });
}
