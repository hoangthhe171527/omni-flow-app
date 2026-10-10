import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/team/team.dart';

void main() {
  TeamMember m(String id, String name) =>
      TeamMember(membershipId: 'm$id', userId: id, name: name);

  ProviderContainer make(Future<List<String>> Function() ids) {
    final c = ProviderContainer(
      overrides: [
        teamMembersProvider.overrideWith(
          (_) async => [m('u1', 'Hoàng'), m('u2', 'Minh'), m('u3', 'Tuấn')],
        ),
        tasksApiProvider.overrideWithValue(_FakeApi(ids)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<String>> idsOf(ProviderContainer c) async => (await c.read(
    projectMembersProvider('p1').future,
  )).map((e) => e.userId).toList();

  test('chỉ thành viên dự án, theo thứ tự danh sách workspace', () async {
    final c = make(() async => ['u3', 'u1']);
    expect(await idsOf(c), ['u1', 'u3']);
  });

  test('dự án cũ không có member_ids → toàn bộ workspace', () async {
    final c = make(() async => const []);
    expect(await idsOf(c), ['u1', 'u2', 'u3']);
  });

  test(
    'member_ids không khớp ai trong workspace → toàn bộ workspace',
    () async {
      final c = make(() async => ['ghost1', 'ghost2']);
      expect(await idsOf(c), ['u1', 'u2', 'u3']);
    },
  );

  test('GET /projects/{id} trả 404 → toàn bộ workspace', () async {
    final c = make(() async => throw const NotFoundException('x'));
    expect(await idsOf(c), ['u1', 'u2', 'u3']);
  });

  test('GET /projects/{id} trả 403 → toàn bộ workspace', () async {
    final c = make(() async => throw const ForbiddenException('x'));
    expect(await idsOf(c), ['u1', 'u2', 'u3']);
  });

  test('lỗi mạng KHÔNG bị nuốt: để chỗ gọi hiện "Thử lại"', () async {
    final c = make(() async => throw const NetworkException('x'));
    await expectLater(
      c.read(projectMembersProvider('p1').future),
      throwsA(isA<NetworkException>()),
    );
  });
}

class _FakeApi implements TasksApi {
  _FakeApi(this.ids);
  final Future<List<String>> Function() ids;
  @override
  Future<List<String>> projectMemberIds(String projectId) => ids();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
