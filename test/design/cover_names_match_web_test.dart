import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// App và web phải dùng CÙNG bộ tên nền.
///
/// Hai bảng gradient riêng là cố ý — app dựng bằng Flutter, web bằng CSS. Thứ
/// PHẢI đồng bộ là TÊN. Lệch một tên thì một phần số dự án hiện sai nền ở một
/// trong hai client, và không có gì báo lỗi: `gradientOf`/`coverGradient` đều
/// rơi về nền mặc định, nên nó trông như một lựa chọn chứ không như một lỗi.
///
/// Bài này đặt ở PHÍA APP chứ không phía web: kiểm của web chạy trong container
/// và không với tới kho `omni-flow-app`, còn `flutter test` chạy trên máy thật
/// nơi hai kho nằm cạnh nhau.
void main() {
  test('bộ tên nền khớp với bảng bên web', () {
    final web = File('../omni-flow/src/lib/project-cover.ts');

    if (!web.existsSync()) {
      // Bỏ qua KHÁC HẲN xanh — cùng quy ước với `test/live`. Một bài xanh vì
      // không tìm thấy tệp là một bài nói dối.
      markTestSkipped(
        'Không thấy ../omni-flow/src/lib/project-cover.ts — chỉ chạy được khi '
        'hai kho nằm cạnh nhau.',
      );

      return;
    }

    final names = RegExp(r'''^\s*"([a-z]+-\d+)":''', multiLine: true)
        .allMatches(web.readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();

    expect(
      names,
      isNotEmpty,
      reason: 'Không đọc được tên nào từ bảng bên web — mẫu khớp đã lỗi thời?',
    );
    expect(
      names.toSet(),
      OmniCovers.names.toSet(),
      reason:
          'Bảng nền của app và web đã lệch nhau. Thêm nền mới thì phải thêm ở '
          'CẢ HAI: omni_covers.dart và omni-flow/src/lib/project-cover.ts.',
    );
  });
}
