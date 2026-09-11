import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// App và web phải dùng CÙNG bộ tên nền — cùng lý do và cùng cách với
/// `cover_names_match_web_test.dart`: hai bảng màu riêng là cố ý, thứ phải
/// đồng bộ là TÊN, và lệch một tên thì một client vẽ phẳng mà không báo gì.
void main() {
  test('bộ tên nền khớp với src/lib/backdrops.ts bên web', () {
    final web = File('../omni-flow/src/lib/backdrops.ts');
    if (!web.existsSync()) {
      // Bỏ qua KHÁC HẲN xanh — một bài xanh vì không tìm thấy tệp là một bài
      // nói dối.
      markTestSkipped(
        'Không thấy ../omni-flow/src/lib/backdrops.ts — chỉ chạy khi hai kho '
        'nằm cạnh nhau.',
      );

      return;
    }

    // Bảng bên web viết mỗi tên là một khoá thụt hai khoảng trắng: `  walnut: {`
    final names = RegExp(
      r'^\s{2}([a-z]+):\s*\{',
      multiLine: true,
    ).allMatches(web.readAsStringSync()).map((m) => m.group(1)!).toSet();

    expect(
      names,
      isNotEmpty,
      reason: 'Không đọc được tên nào từ bảng bên web — mẫu khớp lỗi thời?',
    );
    expect(
      names,
      OmniBackdrops.names.toSet(),
      reason:
          'Bảng nền của app và web đã lệch nhau. Thêm nền thì thêm ở CẢ HAI: '
          'omni_backdrops.dart và omni-flow/src/lib/backdrops.ts.',
    );
  });
}
