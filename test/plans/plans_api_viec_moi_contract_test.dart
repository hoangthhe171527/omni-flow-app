import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/tokens/omni_covers.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';

/// Hợp đồng sửa / sao chép kế hoạch và tìm team / kế hoạch.
///
/// Đối chiếu `omni-flow-api` origin/main:
///  * `UpdateProjectRequest` — name, description, cover, color, team_id,
///    status in:active,done,archived, member_ids[], member_roles{}, custom_fields[];
///    `UpdateProjectDTO::$provided`: khoá gửi kèm null là XOÁ trường đó, nên
///    PlanPatch không bao giờ gửi khoá chưa đặt;
///  * `CopyProjectRequest` — name, as_template, copy_tasks, start_date (date);
///  * `ProjectController@index` nhận `search`; `TeamController@index` nhận `search`.
void main() {
  late _Recorder rec;
  late PlansApi api;

  setUp(() {
    rec = _Recorder();
    api = PlansApi(ApiClient(Dio()..httpClientAdapter = rec));
  });

  Map<String, dynamic> bodyOf(RequestOptions o) =>
      (o.data is String ? jsonDecode(o.data as String) : o.data)
          as Map<String, dynamic>;

  group('PUT /projects/{id}', () {
    test('updatePlan(PlanPatch(name)) gửi ĐÚNG {name}', () async {
      await api.updatePlan('p1', PlanPatch(name: 'X'));
      expect(rec.single.method, 'PUT');
      expect(rec.single.uri.path, '/api/v1/projects/p1');
      expect(bodyOf(rec.single), {'name': 'X'});
    });

    test('PlanPatch(teamId) gửi {team_id}', () async {
      await api.updatePlan('p1', PlanPatch(teamId: 't2'));
      expect(bodyOf(rec.single), {'team_id': 't2'});
    });

    test('PlanPatch(clearTeam) gửi {team_id: null} — rời team', () async {
      await api.updatePlan('p1', PlanPatch(clearTeam: true));
      final body = bodyOf(rec.single);
      expect(body, {'team_id': null});
      expect(body.containsKey('team_id'), isTrue);
      expect(PlanPatch(clearTeam: true).isEmpty, isFalse);
    });

    test('teamId và clearTeam cùng lúc là lỗi lập trình', () {
      expect(
        () => PlanPatch(teamId: 't2', clearTeam: true),
        throwsAssertionError,
      );
    });

    test('PlanPatch(status: done) gửi {status: "done"}', () async {
      await api.updatePlan('p1', PlanPatch(status: PlanStatus.done));
      expect(bodyOf(rec.single), {'status': 'done'});
    });

    test('mô tả và nền đi đúng khoá', () async {
      await api.updatePlan(
        'p1',
        PlanPatch(description: 'Đàn cơ tháng 10', cover: OmniCovers.names[2]),
      );
      expect(bodyOf(rec.single), {
        'description': 'Đàn cơ tháng 10',
        'cover': OmniCovers.names[2],
      });
    });

    test('cover lạ bị app từ chối (assert)', () {
      expect(() => PlanPatch(cover: 'https://x/y.png'), throwsAssertionError);
      expect(() => PlanPatch(cover: 'khong-co'), throwsAssertionError);
    });

    test('member_ids và member_roles đi cùng nhau', () async {
      await api.updatePlan(
        'p1',
        PlanPatch(
          members: {
            'u1': PlanRole.owner,
            'u2': PlanRole.manager,
            'u3': PlanRole.member,
          },
        ),
      );
      final body = bodyOf(rec.single);
      expect(body.keys.toSet(), {'member_ids', 'member_roles'});
      expect(body['member_ids'], ['u1', 'u2', 'u3']);
      expect(body['member_roles'], {
        'u1': 'owner',
        'u2': 'manager',
        'u3': 'member',
      });
    });

    test('trường tuỳ chỉnh gửi đúng hình dạng CreateProjectRequest', () async {
      await api.updatePlan(
        'p1',
        PlanPatch(
          customFields: [
            CustomFieldDef(
              id: 'f1',
              name: 'Màu',
              type: CustomFieldType.select,
              options: ['Đen', 'Trắng'],
            ),
            CustomFieldDef(id: 'f2', name: 'Số máy'),
          ],
        ),
      );
      expect(bodyOf(rec.single), {
        'custom_fields': [
          {
            'id': 'f1',
            'name': 'Màu',
            'type': 'select',
            'options': ['Đen', 'Trắng'],
          },
          {'id': 'f2', 'name': 'Số máy', 'type': 'text'},
        ],
      });
    });

    test('PlanPatch rỗng không có khoá nào', () {
      expect(PlanPatch().toJson(), isEmpty);
      expect(PlanPatch().isEmpty, isTrue);
    });

    test('đọc kế hoạch server trả về', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {
          'id': 'p1',
          'name': 'X',
          'stats': {'total': 4},
        },
      });
      final plan = await api.updatePlan('p1', PlanPatch(name: 'X'));
      expect(plan.name, 'X');
      expect(plan.taskCount, 4);
    });
  });

  group('POST /projects/{id}/copy', () {
    test('khoá đúng như CopyProjectRequest', () async {
      await api.copyPlan(
        'p1',
        name: 'Đàn cơ (bản sao)',
        startDate: DateTime(2026, 11, 1, 9),
      );
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/projects/p1/copy');
      expect(bodyOf(rec.single), {
        'name': 'Đàn cơ (bản sao)',
        'copy_tasks': true,
        'as_template': false,
        'start_date': '2026-11-01',
      });
    });

    test(
      'không chép việc, làm mẫu; không ngày thì không có khoá start_date',
      () async {
        await api.copyPlan(
          'p1',
          name: 'Mẫu',
          copyTasks: false,
          asTemplate: true,
        );
        expect(bodyOf(rec.single), {
          'name': 'Mẫu',
          'copy_tasks': false,
          'as_template': true,
        });
      },
    );
  });

  group('tìm', () {
    test('GET /teams?search=', () async {
      rec.body = '{"success":true,"data":[{"id":"t1","name":"Tổ kỹ thuật"}]}';
      final teams = await api.teams(search: 'kỹ');
      expect(rec.single.uri.path, '/api/v1/teams');
      expect(rec.single.uri.queryParameters['search'], 'kỹ');
      expect(teams.single.name, 'Tổ kỹ thuật');
    });

    test('GET /projects?search=', () async {
      rec.body = '{"success":true,"data":[{"id":"p1","name":"Bảo hành"}]}';
      final plans = await api.plans(search: 'bảo');
      expect(rec.single.uri.path, '/api/v1/projects');
      expect(rec.single.uri.queryParameters['search'], 'bảo');
      expect(plans.single.name, 'Bảo hành');
    });

    test('không tìm thì không gửi khoá search', () async {
      rec.body = '{"success":true,"data":[]}';
      await api.teams();
      await api.plans(search: '  ');
      for (final o in rec.requests) {
        expect(o.uri.queryParameters.containsKey('search'), isFalse);
      }
    });
  });

  group('teamsWithPlansSearchProvider', () {
    ProviderContainer containerWith(_SearchApi fake) {
      final c = ProviderContainer(
        overrides: [
          plansApiProvider.overrideWithValue(fake),
          planRealtimeSignalProvider.overrideWith(_SilentPlans.new),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('có chữ: gửi search cho cả teams và plans, rồi ghép', () async {
      final fake = _SearchApi();
      final c = containerWith(fake);
      final grouped = await c.read(teamsWithPlansSearchProvider('bảo').future);
      expect(fake.teamSearches, ['bảo']);
      expect(fake.planSearches, ['bảo']);
      expect(grouped.single.team.id, 't1');
      expect(grouped.single.plans.single.id, 'p1');
    });

    test('rỗng: đúng cây không lọc (không gửi search)', () async {
      final fake = _SearchApi();
      final c = containerWith(fake);
      await c.read(teamsWithPlansSearchProvider('  ').future);
      expect(fake.teamSearches, [null]);
      expect(fake.planSearches, [null]);
    });
  });

  group('Plan', () {
    final json = <String, dynamic>{
      'id': 'p1',
      'name': 'Đàn cơ',
      'description': 'Mô tả',
      'cover': 'plum-1',
      'status': 'done',
      'owner_id': 'u1',
      'member_ids': ['u2'],
      'member_roles': {'u2': 'manager'},
      'custom_fields': [
        {
          'id': 'f1',
          'name': 'Màu',
          'type': 'select',
          'options': ['Đen'],
        },
      ],
      'sections': [
        {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
      ],
      'stats': {'total': 9, 'done': 2, 'overdue': 1},
    };

    test('fromJson đọc custom_fields', () {
      final plan = Plan.fromJson(json);
      expect(plan.customFields.single.id, 'f1');
      expect(plan.customFields.single.type, CustomFieldType.select);
      expect(plan.planStatus, PlanStatus.done);
    });

    test('thiếu custom_fields → rỗng', () {
      expect(Plan.fromJson(const {'id': 'p1'}).customFields, isEmpty);
    });

    test('copyWith giữ mọi trường', () {
      final plan = Plan.fromJson(json);
      final copy = plan.copyWith();
      expect(copy.id, plan.id);
      expect(copy.name, plan.name);
      expect(copy.description, plan.description);
      expect(copy.color, plan.color);
      expect(copy.cover, plan.cover);
      expect(copy.status, plan.status);
      expect(copy.teamId, plan.teamId);
      expect(copy.teamName, plan.teamName);
      expect(copy.ownerId, plan.ownerId);
      expect(copy.sections.length, plan.sections.length);
      expect(copy.memberIds, plan.memberIds);
      expect(copy.memberRoles, plan.memberRoles);
      expect(copy.customFields.length, 1);
      expect(copy.startDate, plan.startDate);
      expect(copy.endDate, plan.endDate);
      expect(copy.taskCount, 9);
      expect(copy.doneCount, 2);
      expect(copy.overdueCount, 1);
    });

    test('copyWith đổi tên, mô tả, nền, trạng thái', () {
      final copy = Plan.fromJson(json).copyWith(
        name: 'Mới',
        description: 'D',
        cover: 'teal-2',
        status: 'active',
      );
      expect(copy.name, 'Mới');
      expect(copy.description, 'D');
      expect(copy.cover, 'teal-2');
      expect(copy.status, 'active');
      expect(copy.customFields.length, 1);
    });
  });
}

class _SilentPlans extends PlanRealtimeSignal {
  @override
  int build() => 0;
}

class _SearchApi implements PlansApi {
  final teamSearches = <String?>[];
  final planSearches = <String?>[];

  @override
  Future<List<Team>> teams({String? search}) async {
    teamSearches.add(search);
    return const [Team(id: 't1', name: 'Tổ bảo hành')];
  }

  @override
  Future<List<Plan>> plans({String? teamId, String? search}) async {
    planSearches.add(search);
    return const [Plan(id: 'p1', name: 'Bảo hành', teamId: 't1')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
