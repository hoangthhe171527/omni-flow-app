import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';

/// Phân tích tài liệu Mongo không có lược đồ.
///
/// Mọi kế hoạch đang tồn tại trong cơ sở dữ liệu đều được tạo TRƯỚC khi có
/// tầng Team, nên `team_id` của chúng là null và nhiều trường khác vắng mặt
/// hẳn. Nếu bộ phân tích ném lỗi ở một trong những trường hợp đó thì màn
/// Teams trống trơn với người dùng thật, dù nó đầy dữ liệu với dữ liệu mẫu.
void main() {
  group('Team', () {
    test('đọc được một tài liệu đầy đủ', () {
      final team = Team.fromJson({
        'id': 't1',
        'name': 'Xưởng TNP',
        'description': 'Tổ phục chế',
        'color': '#0F6E63',
        'member_ids': ['u1', 'u2'],
      });

      expect(team.id, 't1');
      expect(team.name, 'Xưởng TNP');
      expect(team.memberIds, ['u1', 'u2']);
    });

    test('thiếu danh sách người thì là rỗng, không phải null', () {
      final team = Team.fromJson({'id': 't1', 'name': 'X'});

      expect(team.memberIds, isEmpty);
    });
  });

  group('Plan', () {
    test('kế hoạch cũ không có team_id vẫn đọc được', () {
      final plan = Plan.fromJson({'id': 'p1', 'name': 'Đàn cơ'});

      expect(
        plan.teamId,
        isNull,
        reason:
            'Mọi kế hoạch tạo trước tầng Team đều như vậy. Ném lỗi ở đây là '
            'làm màn Teams trống với người dùng thật.',
      );
      expect(plan.sections, isEmpty);
    });

    test('nhóm việc giữ đúng thứ tự order', () {
      final plan = Plan.fromJson({
        'id': 'p1',
        'name': 'Đàn cơ',
        'sections': [
          {'id': 's3', 'name': 'Chờ QC', 'order': 2},
          {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
          {'id': 's2', 'name': 'Đang phục chế', 'order': 1},
        ],
      });

      expect(plan.sections.map((s) => s.id), ['s1', 's2', 's3']);
    });

    test('nhóm việc không có order thì giữ thứ tự API trả về', () {
      final plan = Plan.fromJson({
        'id': 'p1',
        'name': 'X',
        'sections': [
          {'id': 'b', 'name': 'B'},
          {'id': 'a', 'name': 'A'},
        ],
      });

      expect(
        plan.sections.map((s) => s.id),
        ['b', 'a'],
        reason:
            'Không order thì API đã sắp sẵn. Tự sắp lại theo tên là bịa ra '
            'một thứ tự mà xưởng không hề chọn.',
      );
    });

    test('nhóm việc thiếu tên vẫn có nhãn đọc được', () {
      final plan = Plan.fromJson({
        'id': 'p1',
        'name': 'X',
        'sections': [
          {'id': 's1'},
        ],
      });

      expect(plan.sections.single.name, isNotEmpty);
    });

    group('vai trong kế hoạch', () {
      test('bốn vai của API đọc đúng', () {
        final plan = Plan.fromJson({
          'id': 'p1',
          'name': 'X',
          'member_roles': {
            'u1': 'owner',
            'u2': 'manager',
            'u3': 'member',
            'u4': 'viewer',
          },
        });

        expect(plan.roleOf('u1'), PlanRole.owner);
        expect(plan.roleOf('u2'), PlanRole.manager);
        expect(plan.roleOf('u3'), PlanRole.member);
        expect(plan.roleOf('u4'), PlanRole.viewer);
      });

      test('vai lạ rơi về viewer, không ném lỗi', () {
        final plan = Plan.fromJson({
          'id': 'p1',
          'name': 'X',
          'member_roles': {'u1': 'quan_doc'},
        });

        expect(
          plan.roleOf('u1'),
          PlanRole.viewer,
          reason:
              'Hướng ít quyền nhất. Một client cũ đọc phải vai mới không được '
              'tự cho mình thêm quyền.',
        );
      });

      test('người không có trong bảng vai là viewer', () {
        final plan = Plan.fromJson({'id': 'p1', 'name': 'X'});

        expect(plan.roleOf('ai-đó'), PlanRole.viewer);
      });

      test('chỉ owner và manager mới quản kế hoạch', () {
        expect(PlanRole.owner.canManagePlan, isTrue);
        expect(PlanRole.manager.canManagePlan, isTrue);
        expect(PlanRole.member.canManagePlan, isFalse);
        expect(PlanRole.viewer.canManagePlan, isFalse);
      });
    });

    // Chép nguyên văn một phản hồi thật từ
    // `GET /api/v1/projects?team_id=…`, không phải một hình dạng tôi tưởng
    // tượng ra. Bản đầu của bộ phân tích đoán `tasks_count`/`done_count`/
    // `overdue_count` và mọi kế hoạch hiện "Chưa có việc nào" dù có 5 cây
    // đàn — một cái tên đoán ra không báo lỗi, nó chỉ trả 0 mãi mãi.
    group('số liệu, theo đúng hình dạng API thật gửi', () {
      final real = {
        'id': '01a07263-6f8f-70f5-b62e-3e5fc8ca4a8a',
        'name': 'Dan co',
        'color': 'indigo',
        'status': 'active',
        'team_id': '01a07263-3e78-73db-ac8c-9df0b809e33b',
        'sections': [
          {'name': 'Nhap xuong', 'order': 0, 'id': 's1'},
          {'name': 'Dang phuc che', 'order': 1, 'id': 's2'},
          {'name': 'Cho QC', 'order': 2, 'id': 's3'},
        ],
        'member_ids': ['01a071b9-6528-7384-8013-5b68f7651994'],
        'is_template': false,
        'owner_id': '01a071b9-6528-7384-8013-5b68f7651994',
        'member_roles': {'01a071b9-6528-7384-8013-5b68f7651994': 'owner'},
        'stats': {'total': 5, 'done': 0, 'overdue': 3, 'progress': 0},
      };

      test('đọc được ba con số trong stats', () {
        final plan = Plan.fromJson(real);

        expect(plan.taskCount, 5);
        expect(plan.doneCount, 0);
        expect(plan.overdueCount, 3);
      });

      test('vai owner đọc đúng từ member_roles', () {
        final plan = Plan.fromJson(real);

        expect(
          plan.roleOf('01a071b9-6528-7384-8013-5b68f7651994'),
          PlanRole.owner,
        );
      });

      test('kế hoạch chưa có stats thì là 0, không ném lỗi', () {
        final plan = Plan.fromJson({'id': 'p', 'name': 'X'});

        expect(plan.taskCount, 0);
        expect(plan.progress, 0);
      });
    });

    test('ngày đọc được cả khi API gửi chuỗi rỗng', () {
      final plan = Plan.fromJson({
        'id': 'p1',
        'name': 'X',
        'start_date': '',
        'end_date': '2026-12-31',
      });

      expect(plan.startDate, isNull);
      expect(plan.endDate?.year, 2026);
    });
  });
}
