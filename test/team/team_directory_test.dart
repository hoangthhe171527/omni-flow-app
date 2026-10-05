import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/assign_task_sheet.dart';
import 'package:omni_app/modules/team/data/team_api.dart';
import 'package:omni_app/modules/team/team.dart';

/// Danh bạ của app (APP-I10, NT-I14, MS-I34).
///
/// - Từng đọc MỘT trang `/memberships?per_page=100` và MỘT trang
///   `/identity/users?per_page=100` không cùng tập: người thứ 101 không có
///   trong bộ chọn, và người có trong trang memberships mà không trong trang
///   users thì mang tên "Thành viên". Nay đọc hết trang, tra tên bằng
///   `/identity/users?ids=` theo lô 100 — như `teamApi.listDirectory` của web.
/// - Lời mời chưa nhận (`accepted: false`) không phải thành viên: hiện "Đang
///   chờ", không có trong bộ chọn người.
void main() {
  Map<String, dynamic> membership(int i, {bool? accepted}) => {
    'id': 'm$i',
    'user_id': 'u$i',
    'status': 'active',
    'job_title': 'Thợ',
    'accepted': ?accepted,
  };

  late _DirectoryAdapter adapter;
  late TeamApi api;

  setUp(() {
    adapter = _DirectoryAdapter(
      pages: [
        [for (var i = 1; i <= 100; i++) membership(i)],
        [
          for (var i = 101; i <= 104; i++) membership(i),
          membership(105, accepted: false),
        ],
      ],
    );
    api = TeamApi(ApiClient(Dio()..httpClientAdapter = adapter));
  });

  test(
    'đọc hết trang, tên theo đúng tập id, lời mời chưa nhận là Đang chờ',
    () async {
      final members = await api.members();

      expect(members, hasLength(105));
      final byId = {for (final m in members) m.userId: m};
      expect(byId['u101']!.name, 'Người 101');
      expect(byId['u1']!.name, 'Người 1');

      expect(byId['u105']!.isPending, isTrue);
      expect(byId['u105']!.isSelectable, isFalse);
      expect(byId['u1']!.isPending, isFalse);
      expect(byId['u1']!.isSelectable, isTrue);

      expect(adapter.membershipPages, [1, 2]);
      expect(adapter.userLookups, hasLength(2));
      for (final ids in adapter.userLookups) {
        expect(ids.length, lessThanOrEqualTo(100));
      }
      expect(adapter.userLookups.expand((ids) => ids).toSet(), {
        for (var i = 1; i <= 105; i++) 'u$i',
      });
    },
  );

  test('tra tên lỗi → vẫn trả thành viên với tên dự phòng', () async {
    adapter.failUsers = true;
    final members = await api.members();

    expect(members, hasLength(105));
    expect(members.first.name, 'Thợ');
  });

  testWidgets('bộ chọn người giao việc không có lời mời chưa nhận', (
    tester,
  ) async {
    final members = [
      TeamMember.fromJson(membership(1), {'id': 'u1', 'full_name': 'Lan'}),
      TeamMember.fromJson(membership(105, accepted: false), {
        'id': 'u105',
        'full_name': 'Khách mời',
      }),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [teamMembersProvider.overrideWith((ref) async => members)],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showAssignTaskSheet(context: context, currentIds: const []),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Khách mời'), findsNothing);
  });
}

class _DirectoryAdapter implements HttpClientAdapter {
  _DirectoryAdapter({required this.pages});

  final List<List<Map<String, dynamic>>> pages;
  final membershipPages = <int>[];
  final userLookups = <List<String>>[];
  bool failUsers = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final query = options.uri.queryParameters;
    if (path.endsWith('/memberships')) {
      final page = int.parse(query['page'] ?? '1');
      membershipPages.add(page);
      return _json({
        'success': true,
        'data': pages[page - 1],
        'pagination': {
          'current_page': page,
          'last_page': pages.length,
          'per_page': 100,
          'total': pages.fold<int>(0, (n, p) => n + p.length),
        },
      });
    }
    if (path.endsWith('/identity/users')) {
      final ids = (query['ids'] ?? '').split(',')
        ..removeWhere((id) => id.isEmpty);
      userLookups.add(ids);
      if (failUsers) {
        return _json({'success': false, 'message': 'Lỗi máy chủ'}, 500);
      }
      return _json({
        'success': true,
        'data': [
          for (final id in ids)
            {'id': id, 'full_name': 'Người ${id.substring(1)}'},
        ],
      });
    }
    return _json({'success': false, 'message': 'không có'}, 404);
  }

  ResponseBody _json(Map<String, dynamic> body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
