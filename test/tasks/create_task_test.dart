import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/create_task_page.dart';
import 'package:omni_app/modules/team/team.dart';

/// Tạo việc từ điện thoại.
///
/// Trước đây `TasksApi` không có `create` gì cả: bước đầu tiên của mọi quy
/// trình đều bắt buộc mở máy tính, kể cả khi người tạo đang đứng ngay cạnh thứ
/// cần ghi lại.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _RecordingAdapter adapter;

  const sections = [
    TaskSection(id: 's1', name: 'Cần làm'),
    TaskSection(id: 's2', name: 'Đang làm'),
  ];

  Widget host({
    String? planId = 'p1',
    String? sectionId = 's2',
    List<TaskSection> withSections = sections,
  }) {
    adapter = _RecordingAdapter();

    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(
          TasksApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        teamMembersProvider.overrideWith(
          (ref) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
          ],
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: CreateTaskPage(
          planId: planId,
          sectionId: sectionId,
          sections: withSections,
        ),
      ),
    );
  }

  Map<String, dynamic> sentBody() =>
      Map<String, dynamic>.from(adapter.singleRequest.data as Map);

  group('chỉ tên là bắt buộc', () {
    testWidgets('chưa gõ tên thì không lưu được', (tester) async {
      // Nút bật sáng khi chưa có gì để gửi là mời người dùng bấm vào một lỗi.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('có tên là tạo được, không cần điền gì thêm', (tester) async {
      // Người tạo việc thường đang giữa ca làm và chỉ kịp gõ cái tên. Bắt điền
      // đủ năm ô mới cho lưu là cách nhanh nhất để họ quay lại dùng giấy.
      await tester.pumpWidget(
        host(planId: null, sectionId: null, withSections: const []),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Thay dây đàn');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody(), {'title': 'Thay dây đàn'});
    });

    testWidgets('cắt khoảng trắng thừa ở tên', (tester) async {
      await tester.pumpWidget(
        host(planId: null, sectionId: null, withSections: const []),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   Lên dây   ');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody()['title'], 'Lên dây');
    });
  });

  group('điền sẵn từ bảng', () {
    testWidgets('mang theo dự án và ĐÚNG cột đang đứng', (tester) async {
      // Cả điểm của việc đặt nút tạo trên bảng: việc mới ra đời đúng chỗ mà
      // không phải hỏi thêm câu nào.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Đang làm'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'YAMAHA U3');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody()['project_id'], 'p1');
      expect(sentBody()['section_id'], 's2');
    });

    testWidgets('đổi được sang nhóm việc khác', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đang làm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cần làm').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'YAMAHA U3');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody()['section_id'], 's1');
    });

    testWidgets('không có nhóm việc nào thì không hiện dòng đó', (
      tester,
    ) async {
      await tester.pumpWidget(host(withSections: const []));
      await tester.pumpAndSettle();

      expect(find.text('Nhóm việc'), findsNothing);
    });
  });

  group('người làm', () {
    testWidgets('gán được ngay lúc tạo', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa gán ai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hằng Ni'));
      await tester.pump();
      await tester.tap(find.text('Giao cho 1 người'));
      await tester.pumpAndSettle();

      expect(find.text('Hằng Ni'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'YAMAHA U3');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody()['assignee_ids'], ['u1']);
    });

    testWidgets('không gán ai thì KHÔNG gửi trường đó', (tester) async {
      // Gửi một mảng rỗng và không gửi gì là hai chuyện khác nhau với API; chỉ
      // gửi thứ người dùng thật sự đặt.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'YAMAHA U3');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody().containsKey('assignee_ids'), isFalse);
    });
  });

  group('hạn', () {
    testWidgets('chưa đặt thì không gửi trường hạn', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'YAMAHA U3');
      await tester.pump();
      await tester.tap(find.text('Tạo việc'));
      await tester.pumpAndSettle();

      expect(sentBody().containsKey('due_date'), isFalse);
    });

    testWidgets('chọn xong thì gỡ lại được', (tester) async {
      // Đặt nhầm hạn rồi không gỡ được là một cái bẫy: "chưa hẹn" là một trạng
      // thái có nghĩa, khác hẳn một ngày đại khái nào đó.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa đặt hạn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa đặt hạn'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Chưa đặt hạn'), findsOneWidget);
    });
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
      '{"success":true,"data":{"id":"t-new","title":"x"}}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
