import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/auth/data/auth_api.dart';

/// `/auth/me` trả `appearance.background`; app phải đọc được, và API cũ chưa
/// có khoá thì không văng.
void main() {
  test('đọc appearance.background', () {
    final u = sessionUserFromJson({
      'id': 'u1',
      'full_name': 'Hằng Ni',
      'email': 'h@x',
      'avatar': 'https://x/a.png',
      'appearance': {'background': 'walnut'},
    });

    expect(u.background, 'walnut');
    expect(u.avatarUrl, 'https://x/a.png');
    expect(u.fullName, 'Hằng Ni');
  });

  test('null hoặc thiếu khoá → null', () {
    expect(
      sessionUserFromJson({
        'id': 'u1',
        'email': 'h@x',
        'appearance': {'background': null},
      }).background,
      isNull,
    );
    expect(
      sessionUserFromJson({'id': 'u1', 'email': 'h@x'}).background,
      isNull,
    );
  });
}
