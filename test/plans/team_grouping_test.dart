import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';

/// Một dự án không được biến mất khỏi màn hình chỉ vì tổ của nó không nằm
/// trong danh sách vừa tải.
///
/// Đây là lỗi người dùng báo: "tạo dự án trên điện thoại lại là tạo team trên
/// web, dữ liệu có vẻ lệch nhau". Nguyên nhân ở API — `team_id` là con trỏ tự
/// do, app tra tên trong `GET /teams` còn web tra trong `GET /org-units`, hai
/// bảng khác nhau — nhưng hậu quả nhìn thấy được nằm ở đúng hàm gộp này: dự
/// án rơi hết vào rổ "chưa xếp tổ".
///
/// API giờ giải sẵn `team_name`, nên app dựng được đúng khối cho một tổ nó
/// không tra ra. Bài này canh chính điều đó — và canh cả trường hợp còn lại:
/// tổ đã lưu trữ, hoặc danh sách tổ tải thiếu.
void main() {
  Plan plan(String id, {String? teamId, String? teamName}) => Plan.fromJson({
    'id': id,
    'name': 'Dự án $id',
    'team_id': ?teamId,
    'team_name': ?teamName,
  });

  Future<List<TeamWithPlans>> group({
    required List<Team> teams,
    required List<Plan> plans,
  }) async {
    final container = ProviderContainer(
      overrides: [
        plansApiProvider.overrideWithValue(_StubPlansApi(teams, plans)),
      ],
    );
    addTearDown(container.dispose);

    return container.read(teamsWithPlansProvider.future);
  }

  test(
    'dự án của một tổ KHÔNG có trong danh sách vẫn giữ đúng tên tổ',
    () async {
      // Chính xác kịch bản đã hỏng: tổ do web tạo, app không tra ra id đó.
      final groups = await group(
        teams: const [Team(id: 't-app', name: 'Tổ app')],
        plans: [plan('p1', teamId: 't-web', teamName: 'Tổ web')],
      );

      final names = groups.map((g) => g.team.name).toList();
      expect(
        names,
        contains('Tổ web'),
        reason:
            'Trước đây dự án này rơi vào "chưa xếp tổ" — cùng một dự án, hai '
            'màn hình nói hai chuyện khác nhau.',
      );
      expect(names, isNot(contains('Chưa xếp tổ')));

      final block = groups.firstWhere((g) => g.team.name == 'Tổ web');
      expect(block.plans.map((p) => p.id), ['p1']);
    },
  );

  test('dự án THẬT SỰ chưa xếp tổ vẫn có chỗ riêng, không bị giấu', () async {
    // Phần lớn dữ liệu cũ ở trạng thái này. Giấu chúng là làm công việc đang
    // chạy biến mất khỏi app.
    final groups = await group(
      teams: const [Team(id: 't1', name: 'Tổ một')],
      plans: [
        plan('p1'),
        plan('p2', teamId: 't1'),
      ],
    );

    final orphan = groups.firstWhere((g) => g.team.id == '');
    expect(orphan.team.name, 'Chưa xếp tổ');
    expect(orphan.plans.map((p) => p.id), ['p1']);
  });

  test(
    'tổ không tra ra tên thì nói là không còn tồn tại, không im lặng',
    () async {
      // `team_name` vắng mặt nghĩa là API cũng không giải được — tổ đã bị xoá.
      // Dự án vẫn phải hiện ra, kèm một câu giải thích vì sao nó ở đây.
      final groups = await group(
        teams: const [],
        plans: [plan('p1', teamId: 'da-bi-xoa')],
      );

      final block = groups.firstWhere((g) => g.team.id == 'da-bi-xoa');
      expect(block.team.name, 'Tổ không còn tồn tại');
      expect(block.plans.map((p) => p.id), ['p1']);
    },
  );

  test(
    'tổ rỗng vẫn là một khối — đó là thông tin, không phải chỗ trống',
    () async {
      // Quản đốc cần thấy tổ nào chưa có dự án nào.
      final groups = await group(
        teams: const [Team(id: 't1', name: 'Tổ mới lập')],
        plans: const [],
      );

      expect(groups, hasLength(1));
      expect(groups.first.plans, isEmpty);
    },
  );

  test('nhiều dự án cùng một tổ lạ thì gộp thành MỘT khối', () async {
    // Mỗi dự án một khối cùng tên là một danh sách đọc như dữ liệu hỏng.
    final groups = await group(
      teams: const [],
      plans: [
        plan('p1', teamId: 't-web', teamName: 'Tổ web'),
        plan('p2', teamId: 't-web', teamName: 'Tổ web'),
      ],
    );

    expect(groups, hasLength(1));
    expect(groups.first.plans.map((p) => p.id), ['p1', 'p2']);
  });
}

class _StubPlansApi implements PlansApi {
  _StubPlansApi(this._teams, this._plans);

  final List<Team> _teams;
  final List<Plan> _plans;

  @override
  Future<List<Team>> teams() async => _teams;

  @override
  Future<List<Plan>> plans({String? teamId}) async => _plans;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
