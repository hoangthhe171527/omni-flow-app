import 'dart:math';

import '../../../core/utils/json.dart';

/// Một vai chọn được khi thêm nhân viên trên app.
class RoleOption {
  const RoleOption({required this.slug, required this.label});

  final String slug;
  final String label;
}

/// Vai mặc định khi người thêm không chọn — cùng mặc định với server
/// (`MembershipInviteController::assignInitialRole`).
const defaultRoleSlug = 'worker';

/// Tên tiếng Việt cho các vai dựng sẵn. Seed trên server lẫn tiếng Anh
/// ("Sales Manager"), còn người cầm máy ở xưởng cần đọc được ngay.
const _presetLabels = {
  'worker': 'Thợ',
  'manager': 'Quản lý',
  'sales': 'Kinh doanh',
  'support': 'Chăm sóc khách hàng',
  'accountant': 'Kế toán',
};

/// Vai chọn được từ `GET /authorization/roles`.
///
/// Bỏ `admin`: server gán vai ban đầu mà KHÔNG kiểm người thêm có quyền cấp vai
/// đó không, nên để nó ở đây là cho một quản lý tự tạo ra tài khoản quản trị.
/// Cấp quyền quản trị làm ở màn phân quyền trên web. `worker` luôn đứng đầu
/// (mặc định); vai tự tạo giữ tên gốc.
List<RoleOption> roleOptionsFrom(List<Map<String, dynamic>> rows) {
  final options = <RoleOption>[];
  for (final row in rows) {
    final slug = row.strOr('slug', '').trim();
    if (slug.isEmpty || slug == 'admin') continue;
    final label = _presetLabels[slug] ?? row.strOr('name', slug).trim();
    options.add(RoleOption(slug: slug, label: label.isEmpty ? slug : label));
  }
  options.sort((a, b) {
    if (a.slug == defaultRoleSlug) return -1;
    if (b.slug == defaultRoleSlug) return 1;
    return 0;
  });
  return options;
}

/// Mật khẩu tạm đọc được thành tiếng qua điện thoại: bỏ các ký tự dễ nhầm
/// (0/O, 1/l/I), có chữ hoa, chữ thường, số và ký tự đặc biệt — đủ 10 ký tự,
/// trên mức tối thiểu 8 của server.
String generateTempPassword([Random? random]) {
  final rng = random ?? Random.secure();
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const upper = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  const digits = '23456789';
  String pick(String from) => from[rng.nextInt(from.length)];

  final buffer = StringBuffer(pick(upper));
  for (var i = 0; i < 4; i++) {
    buffer.write(pick(lower));
  }
  for (var i = 0; i < 4; i++) {
    buffer.write(pick(digits));
  }
  buffer.write('!');
  return buffer.toString();
}

/// Kết quả `POST /memberships/add-user`.
///
/// [userCreated] false = email đã có tài khoản sẵn (ở workspace khác): server
/// chỉ gắn họ vào workspace này và KHÔNG đổi mật khẩu — nên app không được
/// đưa mật khẩu tạm cho họ.
class AddedMember {
  const AddedMember({required this.userCreated});

  final bool userCreated;
}
