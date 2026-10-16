import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// App và web phải nhận diện CÙNG bộ token nền cũ.
///
/// Token này không còn được vẽ thành gradient: cả hai client phải cùng coi nó
/// là dữ liệu legacy và rơi về surface hệ thống. Lệch một token sẽ khiến chỉ
/// một bên cố tải nó như URL ảnh.
///
/// Bài này đặt ở PHÍA APP chứ không phía web: kiểm của web chạy trong container
/// và không với tới kho `omni-flow-app`, còn `flutter test` chạy trên máy thật
/// nơi hai kho nằm cạnh nhau.
void main() {
  test('bộ token legacy khớp với bảng bên web', () {
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

    final names = RegExp(
      // Web hiện khai báo token làm khoá của object; vẫn chấp nhận dạng
      // phần tử mảng cũ để bài kiểm không phụ thuộc cách viết bảng.
      r'''^\s*"([a-z]+-\d+)"\s*[:,]''',
      multiLine: true,
    ).allMatches(web.readAsStringSync()).map((m) => m.group(1)!).toList();

    expect(
      names,
      isNotEmpty,
      reason: 'Không đọc được tên nào từ bảng bên web — mẫu khớp đã lỗi thời?',
    );
    expect(
      names.toSet(),
      OmniCovers.names.toSet(),
      reason:
          'Danh sách token legacy của app và web đã lệch nhau. Phải cập nhật '
          'CẢ HAI để cùng fallback về nền hệ thống.',
    );
  });
}
