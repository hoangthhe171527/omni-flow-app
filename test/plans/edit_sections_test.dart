import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/edit_sections_page.dart';

/// Sửa nhóm việc của một dự án ĐÃ CÓ.
///
/// Trước đây nhóm việc chỉ khai được lúc tạo, nên một cái tên gõ nhầm hay một
/// quy trình đổi đi là phải tạo lại cả dự án — mà công việc thì đã nằm
/// trong đó rồi.
void main() {
  const planId = 'p1';

  late _RecordingAdapter adapter;

  final plan = Plan.fromJson({
    'id': planId,
    'name': 'Đàn cơ',
    'sections': [
      {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
      {'id': 's2', 'name': 'Chờ QC', 'order': 1, 'requires_checklist': true},
      {'id': 's3', 'name': 'Hoàn thiện', 'order': 2, 'counts_for_kpi': true},
    ],
  });

  Widget host() {
    adapter = _RecordingAdapter();

    return ProviderScope(
      overrides: [
        plansApiProvider.overrideWithValue(
          PlansApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        planProvider(planId).overrideWith((ref) async => plan),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const EditSectionsPage(planId: planId),
      ),
    );
  }

  List<Map<String, dynamic>> sentSections() {
    final body = Map<String, dynamic>.from(adapter.singleRequest.data as Map);

    return (body['sections'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('đổi tên GIỮ NGUYÊN id của nhóm', (tester) async {
    // `section_id` trên từng công việc trỏ vào chính những id này. Sinh id mới
    // cho một nhóm chỉ đổi tên sẽ làm mọi công việc trong nhóm rơi về cột đầu.
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'Tiếp nhận');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(sentSections().first, containsPair('id', 's1'));
    expect(sentSections().first, containsPair('name', 'Tiếp nhận'));
  });

  testWidgets('cổng QC và cờ KPI đi theo nguyên vẹn', (tester) async {
    // API thay CẢ MẢNG `sections`, nên đánh rơi hai cờ này là xoá lặng lẽ hai
    // quy tắc mà cơ chế trả thưởng dựa vào — và không có gì báo lỗi.
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'Tiếp nhận');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final sent = sentSections();
    expect(sent[1], containsPair('requires_checklist', true));
    expect(sent[2], containsPair('counts_for_kpi', true));
  });

  testWidgets('nhóm mới KHÔNG dùng lại id của nhóm vừa xoá', (tester) async {
    // Công việc cũ vẫn trỏ vào id đó, và chúng sẽ lặng lẽ hiện ra trong nhóm
    // mới như thể ai đó vừa xếp chúng vào.
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.close_rounded).first); // bỏ s1
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm nhóm việc'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Đóng gói');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final ids = sentSections().map((s) => s['id']).toList();
    expect(ids, isNot(contains('s1')));
    expect(ids.toSet().length, ids.length, reason: 'không id nào trùng');
  });

  testWidgets('nhóm không tên thì không lưu được', (tester) async {
    // Một cột không tên trên bảng thì không ai biết nó là bước nào.
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();

    final save = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(save.onPressed, isNull);
  });

  testWidgets('nhóm cuối cùng không xoá được', (tester) async {
    // Dự án phải còn ít nhất một cột, nếu không bảng không còn chỗ nào để
    // hiện việc.
    await pumpApp(tester);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
    }

    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.close_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(remove.onPressed, isNull);
  });

  testWidgets('nhóm mang quy tắc thì nói ra, để người sửa biết đang đụng gì', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('cần xong hết việc con'), findsOneWidget);
    expect(find.text('đếm vào KPI tháng'), findsOneWidget);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  RequestOptions get singleRequest {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      '{"success":true,"data":{"id":"p1","name":"Đàn cơ","sections":[]}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
