import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/widgets/kpi_card.dart';

/// "Tháng trước xưởng xong bao nhiêu cây."
///
/// §B4: cuối tháng chủ xưởng đọc con số để trao thưởng. Nhưng ngày mùng 1 con
/// số đã về 0, và tháng vừa khép lại không còn xem được ở đâu — nên nó phải
/// đọc đúng trong ngày cuối cùng, hoặc chép tay ra chỗ khác. API nhận
/// `?month=` từ lâu; app thì chưa từng gửi.
void main() {
  WorkshopKpi kpi({NextTier? next, int daysLeft = 0}) => WorkshopKpi(
    delivered: 30,
    reachedBonus: 0,
    daysLeft: daysLeft,
    tiers: const [BonusTier(count: 35, bonus: 3)],
    isConfigured: true,
    nextTier: next ?? const NextTier(count: 35, bonus: 3, remaining: 5),
  );

  Future<void> show(
    WidgetTester tester, {
    required DateTime month,
    required bool past,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: KpiCard(
            kpi: kpi(),
            month: month,
            onPrevMonth: () {},
            onNextMonth: past ? () {} : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('thẻ nói rõ đang trả lời cho tháng nào', (tester) async {
    // Từ khi lùi được về tháng trước, một con số không mang mốc thời gian là
    // một con số dễ đọc nhầm — và người đọc nó là người sắp trả thưởng.
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: KpiCard(
            kpi: kpi(),
            month: DateTime(2026, 8),
            onPrevMonth: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tháng 8/2026'), findsOneWidget);
  });

  testWidgets('KHÔNG đi tới tương lai được', (tester) async {
    // Một tháng chưa tới luôn có delivered = 0, và số 0 đó trông y hệt "tháng
    // này chưa ai xong cây nào".
    await show(tester, month: DateTime(2026, 9), past: false);

    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(IconButton),
      ),
    );

    expect(
      next.onPressed,
      isNull,
      reason: 'Mũi tên tới phải MỜ, không biến mất.',
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('tháng đã khép thì không khuyên "còn bao xa"', (tester) async {
    // "Còn 5 việc tới mốc 35" đọc như một lời động viên cho một tháng đã hết.
    await show(tester, month: DateTime(2026, 8), past: true);

    expect(find.textContaining('Thiếu 5 việc so với mốc 35'), findsOneWidget);
    expect(find.textContaining('Còn 5 việc tới mốc'), findsNothing);
  });

  testWidgets('tháng đang chạy vẫn nói "còn bao xa"', (tester) async {
    await show(tester, month: DateTime(2026, 9), past: false);

    expect(find.textContaining('Còn 5 việc tới mốc 35'), findsOneWidget);
  });

  test('gửi tháng dạng YYYY-MM-01, không gửi ngày giờ của máy', () async {
    // 2026-10-01T00:00 giờ Việt Nam là 2026-09-30 theo UTC. Gửi cả ngày giờ
    // là để cả thẻ KPI trả lời cho tháng bên cạnh — im lặng, vì con số vẫn ra
    // một con số.
    final recorder = _RecordingAdapter();
    final api = PlansApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await api.kpi(month: DateTime(2026, 8, 17));

    final request = recorder.singleRequest;
    expect(request.uri.path, '/api/v1/tasks/kpi');
    expect(request.uri.queryParameters['month'], '2026-08-01');
  });

  test('không khai tháng thì KHÔNG gửi tham số nào', () async {
    // Server tự lấy tháng đang chạy theo giờ XƯỞNG. Gửi tháng do máy người
    // dùng tính là đưa múi giờ của điện thoại vào một con số về tiền.
    final recorder = _RecordingAdapter();
    final api = PlansApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await api.kpi();

    expect(
      recorder.singleRequest.uri.queryParameters.containsKey('month'),
      isFalse,
    );
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
      jsonEncode({'success': true, 'data': <String, dynamic>{}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
