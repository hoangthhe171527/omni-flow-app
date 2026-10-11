import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';

/// Hợp đồng Nhóm 2 phía kế hoạch (Task 10), đối chiếu `omni-flow-api` nhánh
/// `feat/viec-moi-api`:
///  * `ProjectController::present` — MỌI phản hồi kế hoạch có `is_favorite`
///    (bool theo người xem), không có `favorite_by`; API cũ không có khoá;
///  * `POST|DELETE /projects/{id}/favorite` ($read) →
///    `{success, data: {project_id, is_favorite}}`;
///  * `POST /projects/{id}/transfer-owner` ($write), `TransferProjectOwner
///    Request`: `owner_id` (bắt buộc, ≤64), `previous_owner_role?`
///    in:manager,member,viewer → kế hoạch qua `present()`.
void main() {
  List<Map<String, dynamic>> rows(String name) =>
      ((jsonDecode(File('test/contract/fixtures/$name').readAsStringSync())
                  as Map<String, dynamic>)['data']
              as List)
          .cast<Map<String, dynamic>>();

  group('đọc (Plan.fromJson)', () {
    test('API mới: is_favorite true/false', () {
      final plans = rows('projects_index_group2.json').map(Plan.fromJson);
      expect(plans.map((p) => p.isFavorite), [true, false]);
    });

    test('API cũ (projects_index.json): không có khoá → null', () {
      final plan = Plan.fromJson(rows('projects_index.json').single);
      expect(plan.isFavorite, isNull);
    });

    test('copyWith giữ is_favorite và đổi được nó', () {
      final plan = Plan.fromJson(rows('projects_index_group2.json').first);
      expect(plan.copyWith(name: 'Y').isFavorite, isTrue);
      expect(plan.copyWith(isFavorite: false).isFavorite, isFalse);
      final old = Plan.fromJson(rows('projects_index.json').single);
      expect(old.copyWith(name: 'Y').isFavorite, isNull);
    });
  });

  group('gửi (PlansApi)', () {
    late _Recorder rec;
    late PlansApi api;

    setUp(() {
      rec = _Recorder();
      api = PlansApi(ApiClient(Dio()..httpClientAdapter = rec));
    });

    Map<String, dynamic> bodyOf(RequestOptions o) =>
        (o.data is String ? jsonDecode(o.data as String) : o.data)
            as Map<String, dynamic>;

    test('thích: POST /projects/{id}/favorite, đọc data.is_favorite', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {'project_id': 'p1', 'is_favorite': true},
      });
      expect(await api.setFavorite('p1', true), isTrue);
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/projects/p1/favorite');
      expect(rec.single.data, anyOf(isNull, isEmpty));
    });

    test('bỏ thích: DELETE /projects/{id}/favorite', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {'project_id': 'p1', 'is_favorite': false},
      });
      expect(await api.setFavorite('p1', false), isFalse);
      expect(rec.single.method, 'DELETE');
      expect(rec.single.uri.path, '/api/v1/projects/p1/favorite');
    });

    test('chuyển chủ: POST /projects/{id}/transfer-owner {owner_id}', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {
          'id': 'p1',
          'name': 'Dan co',
          'owner_id': 'u2',
          'member_roles': {'u2': 'owner', 'u1': 'manager'},
          'is_favorite': false,
        },
      });
      final plan = await api.transferOwner('p1', ownerId: 'u2');
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/projects/p1/transfer-owner');
      // Không gửi `previous_owner_role` khi không chọn: server mặc định manager.
      expect(bodyOf(rec.single), {'owner_id': 'u2'});
      expect(plan.ownerId, 'u2');
      expect(plan.roleOf('u1'), PlanRole.manager);
    });

    test('chuyển chủ kèm vai chủ cũ: previous_owner_role là tên vai', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {'id': 'p1', 'name': 'x', 'owner_id': 'u2'},
      });
      await api.transferOwner(
        'p1',
        ownerId: 'u2',
        previousOwnerRole: PlanRole.viewer,
      );
      expect(bodyOf(rec.single), {
        'owner_id': 'u2',
        'previous_owner_role': 'viewer',
      });
    });

    test('vai chủ cũ không được là owner (server chỉ nhận ba vai)', () {
      expect(
        () => api.transferOwner(
          'p1',
          ownerId: 'u2',
          previousOwnerRole: PlanRole.owner,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  String body = '{"success":true,"data":{"id":"p1","name":"x"}}';

  RequestOptions get single {
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
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
