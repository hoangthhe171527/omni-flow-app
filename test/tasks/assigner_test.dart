import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Ai là NGƯỜI GIAO VIỆC, suy từ quyền chứ không từ tên vai trò.
///
/// `session.dart` cấm enum vai trò phía client vì vai trò do từng tenant tự
/// cấu hình — một xưởng có thể gọi vai đó là "quản đốc", xưởng khác gọi là
/// "tổ trưởng". Quyền thì không đổi tên.
void main() {
  TaskAccess accessWith(Set<String> slugs) =>
      TaskAccess.of(AccessPolicy(slugs));

  test('người quản lý mọi dự án là người giao việc', () {
    final access = accessWith({
      'tasks.read',
      'tasks.write',
      'tasks.projects.manage.all',
    });

    expect(access.isAssigner, isTrue);
  });

  test('thợ chỉ có đọc-ghi việc thì KHÔNG phải người giao việc', () {
    final access = accessWith({'tasks.read', 'tasks.write'});

    expect(
      access.isAssigner,
      isFalse,
      reason:
          'Cả bốn vai hệ thống đều giữ tasks.write. Nếu tasks.write đủ để '
          'thành người giao việc thì phép phân vai này vô nghĩa.',
    );
  });

  test('người chỉ đọc cũng không phải người giao việc', () {
    expect(accessWith({'tasks.read'}).isAssigner, isFalse);
  });

  test('phiên rỗng không phải người giao việc', () {
    expect(TaskAccess.of(const AccessPolicy.empty()).isAssigner, isFalse);
  });

  // Bảng này khớp với SystemRolePresets.php bên API. Nếu preset đổi mà bảng
  // này không đổi, phép phân vai lệch âm thầm — không có lỗi, chỉ có người
  // dùng thấy sai màn hình.
  group('khớp với bốn vai hệ thống của API', () {
    const worker = {'tasks.read', 'tasks.write'};
    const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

    for (final (role, slugs, expected) in [
      ('admin', assigner, true),
      ('manager', assigner, true),
      ('sales', worker, false),
      ('support', worker, false),
    ]) {
      test('$role: giao việc = $expected', () {
        expect(accessWith(slugs).isAssigner, expected);
      });
    }
  });

  test('người giao việc vẫn là người nhận việc', () {
    final access = accessWith({
      'tasks.read',
      'tasks.write',
      'tasks.projects.manage.all',
    });

    expect(
      access.canComplete,
      isTrue,
      reason:
          'Quản đốc cũng tick công đoạn. "Người giao việc" là quyền THÊM, '
          'không phải một vai thay thế.',
    );
  });
}
