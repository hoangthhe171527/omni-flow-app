import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/team/team.dart';

void main() {
  TeamMember m(String id, String name) =>
      TeamMember(membershipId: 'm$id', userId: id, name: name);

  ProviderContainer make(List<String> ids) {
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

  test('chỉ thành viên dự án, theo thứ tự danh sách workspace', () async {
    final c = make(['u3', 'u1']);
    final list = await c.read(projectMembersProvider('p1').future);
    expect(list.map((e) => e.userId), ['u1', 'u3']);
  });

  test('dự án cũ không có member_ids → toàn bộ workspace', () async {
    final c = make(const []);
    final list = await c.read(projectMembersProvider('p1').future);
    expect(list.map((e) => e.userId), ['u1', 'u2', 'u3']);
  });
}

class _FakeApi implements TasksApi {
  _FakeApi(this.ids);
  final List<String> ids;
  @override
  Future<List<String>> projectMemberIds(String projectId) async => ids;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
