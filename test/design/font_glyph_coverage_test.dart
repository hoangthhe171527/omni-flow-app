import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Mọi ký tự ngoài ASCII trong mã UI phải có glyph trong Inter, font của app.
///
/// Font không có glyph thì máy tự rơi về font dự phòng của hệ điều hành —
/// mỗi máy một kiểu, và có máy ra ô trống. "→" từng lọt vào thẻ việc theo
/// đúng đường đó. Biểu tượng cảm xúc được miễn: chúng LUÔN cần font emoji của
/// hệ thống, và bảng chọn emoji cố ý dùng nó.
void main() {
  test('không ký tự nào trong lib/ thiếu glyph trong font của app', () {
    final have = _cmap('assets/fonts/Inter-Regular.ttf');
    final missing = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        final comment = line.indexOf('//');
        final code = comment < 0 ? line : line.substring(0, comment);
        for (final rune in code.runes) {
          if (rune < 0x80 || have.contains(rune) || _isEmoji(rune)) continue;
          missing.add(
            '${entity.path.replaceAll(r'\', '/')}:${i + 1} '
            'U+${rune.toRadixString(16).toUpperCase()} '
            '${String.fromCharCode(rune)}',
          );
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Ký tự không có trong Inter:\n${missing.join('\n')}\n'
          'Dùng icon Material (vd. Icons.arrow_forward_rounded) hoặc ký tự có '
          'sẵn trong font (›, ·, —).',
    );
  });

  test('bộ đọc cmap đọc đúng: chữ Việt có, emoji không', () {
    final have = _cmap('assets/fonts/Inter-Regular.ttf');

    expect(have.containsAll('ệữđ₫·›—…'.runes), isTrue);
    // Emoji luôn cần font emoji của hệ thống — không font chữ nào có.
    expect(have.contains(0x1F600), isFalse);
  });
}

bool _isEmoji(int rune) =>
    rune >= 0x1F000 ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    (rune >= 0x2B00 && rune <= 0x2BFF) ||
    (rune >= 0x2300 && rune <= 0x23FF) ||
    rune == 0xFE0F;

/// Tập mã ký tự có glyph, đọc từ bảng `cmap` (định dạng 4 và 12).
Set<int> _cmap(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  int? cmap;
  for (var i = 0; i < b.getUint16(4); i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(
      List.generate(4, (k) => b.getUint8(record + k)),
    );
    if (tag == 'cmap') cmap = b.getUint32(record + 8);
  }
  final base = cmap!;
  final out = <int>{};

  for (var i = 0; i < b.getUint16(base + 2); i++) {
    final sub = base + b.getUint32(base + 4 + i * 8 + 4);
    switch (b.getUint16(sub)) {
      case 4:
        final segX2 = b.getUint16(sub + 6);
        final ends = sub + 14;
        final starts = ends + segX2 + 2;
        for (var s = 0; s < segX2 ~/ 2; s++) {
          final end = b.getUint16(ends + s * 2);
          for (var c = b.getUint16(starts + s * 2); c <= end; c++) {
            if (c == 0xFFFF) break;
            out.add(c);
          }
        }
      case 12:
        for (var g = 0; g < b.getUint32(sub + 12); g++) {
          final start = b.getUint32(sub + 16 + g * 12);
          final end = b.getUint32(sub + 20 + g * 12);
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
    }
  }

  return out;
}
