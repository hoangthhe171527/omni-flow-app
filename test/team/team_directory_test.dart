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
        overrides: [teamDirectoryProvider.overrideWith((ref) async => members)],
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

  // Review I2: trần 60 trang (6.000 người) phải giữ dù server báo nhiều hơn,
  // và các lượt đọc chạy song song có giới hạn, không tuần tự 120 vòng mạng.
  test('dừng ở trần 60 trang; tối đa 4 lượt cùng lúc', () async {
    final counting = _CountingAdapter(lastPage: 100);
    final members = await TeamApi(
      ApiClient(Dio()..httpClientAdapter = counting),
    ).members();

    expect(counting.membershipPages.toSet(), {
      for (var p = 1; p <= TeamApi.maxPages; p++) p,
    });
    expect(counting.membershipPages, hasLength(TeamApi.maxPages));
    expect(members, hasLength(TeamApi.maxPages));
    expect(counting.maxInFlight, lessThanOrEqualTo(TeamApi.parallelism));
    expect(counting.maxInFlight, greaterThan(1));
  });

  // Review I1: một người có hai membership (dòng cũ đã nghỉ, dòng mới) →
  // một dòng: dòng đang làm, không có thì dòng mới nhất.
  test(
    'hai membership của một người: ưu tiên dòng đang làm, rồi dòng mới',
    () async {
      adapter = _DirectoryAdapter(
        pages: [
          [
            {
              'id': 'm-new-off',
              'user_id': 'u1',
              'status': 'inactive',
              'created_at': '2026-09-01T00:00:00.000000Z',
            },
            {
              'id': 'm-old-on',
              'user_id': 'u1',
              'status': 'active',
              'created_at': '2025-01-01T00:00:00.000000Z',
            },
            {
              'id': 'm-old-off',
              'user_id': 'u2',
              'status': 'inactive',
              'created_at': '2024-01-01T00:00:00.000000Z',
            },
            {
              'id': 'm-new-off2',
              'user_id': 'u2',
              'status': 'inactive',
              'created_at': '2026-01-01T00:00:00.000000Z',
            },
          ],
        ],
      );
      final members = await TeamApi(
        ApiClient(Dio()..httpClientAdapter = adapter),
      ).members();

      expect(members.map((m) => m.membershipId), ['m-old-on', 'm-new-off2']);
    },
  );
}

/// `/memberships` có [lastPage] trang, mỗi trang một người; đo số lượt đang
/// bay cùng lúc.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter({required this.lastPage});

  final int lastPage;
  final membershipPages = <int>[];
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    _inFlight--;

    final query = options.uri.queryParameters;
    final Map<String, dynamic> body;
    if (options.uri.path.endsWith('/memberships')) {
      final page = int.parse(query['page'] ?? '1');
      membershipPages.add(page);
      body = {
        'success': true,
        'data': [
          {'id': 'm$page', 'user_id': 'u$page', 'status': 'active'},
        ],
        'pagination': {
          'current_page': page,
          'last_page': lastPage,
          'per_page': 100,
          'total': lastPage,
        },
      };
    } else {
      body = {'success': true, 'data': <Object>[]};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
