import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/data/team_api.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';
import 'package:omni_app/modules/team/presentation/team_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Quản đốc liên kết Zalo cho từng thợ.
///
/// Đây là thao tác làm cho bot xưởng biết ai vừa nhắn trong nhóm (§G4). Bot cố
/// ý KHÔNG tự đoán: máy chạy nó nằm ở xưởng không ai trông và đang cầm sẵn
/// cookie của một tài khoản Zalo, nên nó phải dựa vào một liên kết mà người có
/// thẩm quyền tự tay tạo.
void main() {
  late _RecordingAdapter adapter;

  const manager = {'membership.members.read', 'membership.members.update'};
  const plain = {'membership.members.read'};

  final members = [
    TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
    TeamMember(
      membershipId: 'm2',
      userId: 'u2',
      name: 'Bảo Khánh',
      zaloUserId: '79000012345',
    ),
  ];

  Widget host({Set<String> permissions = manager}) {
    adapter = _RecordingAdapter();

    return ProviderScope(
      overrides: [
        teamApiProvider.overrideWithValue(
          TeamApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        teamMembersProvider.overrideWith((ref) async => members),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy(permissions),
          ),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TeamPage(),
      ),
    );
  }

  testWidgets('nói rõ ai đã liên kết, ai chưa', (tester) async {
    // Không có dòng này thì quản đốc phải mở từng người ra mới biết còn thiếu
    // ai — và bot thì im lặng từ chối đúng những người chưa liên kết.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Chưa liên kết Zalo'), findsOneWidget);
    expect(find.text('Zalo: 79000012345'), findsOneWidget);
  });

  testWidgets('liên kết được', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '79000099999');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(adapter.singleRequest.method, 'PUT');
    expect(adapter.singleRequest.uri.path, '/api/v1/memberships/m1');
    expect(adapter.singleRequest.data, {'zalo_user_id': '79000099999'});
  });

  testWidgets('để trống là GỠ liên kết, không phải huỷ', (tester) async {
    // Người nghỉ việc phải gỡ được, nếu không id Zalo cũ vẫn ghi công cho họ.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bảo Khánh'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(adapter.singleRequest.data, {'zalo_user_id': ''});
  });

  testWidgets('lưu lại đúng giá trị cũ thì KHÔNG gọi API', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bảo Khánh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(adapter.requests, isEmpty);
  });

  testWidgets('không có quyền thì không thấy và không sửa được', (
    tester,
  ) async {
    // Bot dựa vào liên kết này để quyết ai được ghi công. Ai cũng đặt được thì
    // nó thôi là một khẳng định có thẩm quyền.
    await tester.pumpWidget(host(permissions: plain));
    await tester.pumpAndSettle();

    expect(find.text('Chưa liên kết Zalo'), findsNothing);

    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Liên kết Zalo —'), findsNothing);
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
      '{"success":true,"data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
