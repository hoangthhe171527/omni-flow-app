import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chữ Việt UTF-8 bị đọc nhầm thành Windows-1252 rồi lưu lại ("mojibake"):
/// "Tải lại ảnh" thành `Táº£i láº¡i áº£nh`. Lỗi này lọt vào tooltip thật mà không
/// test nào bắt (MS-I24 Đợt 6b). Quét mọi tệp Dart trong lib/.
///
/// Mẫu là cặp byte UTF-8 của chữ Việt khi đọc theo cp1252:
/// - `Ã` + ký tự thay cho byte 0x80–0xBF (à, á, â, ã, è, é, ê, ì, í, ò, ó, ô,
///   õ, ù, ú, ý…). `ĐÃ XONG` hợp lệ vì sau `Ã` là khoảng trắng / chữ hoa.
/// - `áº` / `á»` (ạ, ả, ấ, ố, ờ, ự…), `Ä‘` / `Ä'` (đ), `Ä\u0090` (Đ),
///   `Æ°` (ư), `Æ¡` (ơ), `Æ¯` (Ư), `Ä©`/`Å©` (ĩ, ũ), `Äƒ` (ă).
final _mojibake = RegExp(
  '(Ã[\u0080-¿ŒœŠšŸŽžƒ'
  'ˆ˜–—‘-„†-•…‰'
  '‹›€™])'
  '|á[º»¸¹]'
  "|Ä[‘'\u0090©ƒ]"
  '|Æ[°¡¯]'
  '|Å©',
);

void main() {
  test('mẫu bắt đúng chuỗi hỏng, bỏ qua chữ Việt đúng', () {
    expect(_mojibake.hasMatch('Táº£i láº¡i áº£nh'), isTrue);
    expect(_mojibake.hasMatch('Ä‘Ã£ gá»­i'), isTrue);
    expect(_mojibake.hasMatch('ngÆ°á»i'), isTrue);
    expect(_mojibake.hasMatch('Tải lại ảnh'), isFalse);
    expect(_mojibake.hasMatch('ĐÃ XONG · MÃ giai đoạn · đã gửi'), isFalse);
  });

  test('không tệp nào trong lib/ chứa chữ Việt hỏng mã hoá', () {
    final hits = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _mojibake.firstMatch(lines[i]);
        if (match != null) {
          hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
