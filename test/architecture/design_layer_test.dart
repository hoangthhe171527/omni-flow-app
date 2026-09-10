import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `design/` là vốn từ dùng chung, không phải một module.
///
/// Nó được phép phụ thuộc vào `core/` và không gì khác. Import ngược lên
/// `modules/` là chỗ mọi thứ bắt đầu rối: một widget nền tảng kéo theo một
/// phiên đăng nhập và một lượt gọi mạng, rồi module tiếp theo không dùng được
/// nó nữa mà không kéo theo cả cái đuôi đó.
///
/// Bài này ra đời khi `OmniAppBar` suýt import thẳng `AccountMenuButton` từ
/// `modules/settings`. Lời giải đúng là một CHỖ CẮM (`OmniAccountSlot`):
/// design sở hữu vị trí, app cắm nội dung vào.
void main() {
  test('design không import modules, app hay security', () {
    final offenders = <String>[];

    final files = Directory('lib/design')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();

      for (final line in lines) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ')) continue;

        final forbidden = [
          '/modules/',
          'modules/',
          '/app/',
          '/security/',
          'security/',
        ].any(trimmed.contains);

        if (forbidden) {
          offenders.add('${file.path.replaceAll(r'\', '/')}: $trimmed');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'design/ chỉ được phụ thuộc core/. Cần một thứ từ module thì mở một '
          'chỗ cắm (xem OmniAccountSlot) chứ đừng import ngược.\n'
          '${offenders.join('\n')}',
    );
  });
}
