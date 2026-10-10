/// Bỏ dấu để "kenh" tìm ra "Kết nối kênh".
///
/// Người dùng gõ trên bàn phím điện thoại, giữa lúc làm việc, và sẽ không bật
/// bộ gõ tiếng Việt lên chỉ để tìm một màn hình.
String foldDiacritics(String input) {
  // Hai chuỗi này phải khớp từng ký tự một. Lệch một là mọi chữ sau đó ánh xạ
  // sai — âm thầm, không lỗi, chỉ là tìm không ra. Nhóm theo nguyên âm để đếm
  // được bằng mắt: a×17, e×11, i×5, o×17, u×11, y×5, đ×1 = 67.
  const marks =
      'àáạảãâầấậẩẫăằắặẳẵ' // a
      'èéẹẻẽêềếệểễ' // e
      'ìíịỉĩ' // i
      'òóọỏõôồốộổỗơờớợởỡ' // o
      'ùúụủũưừứựửữ' // u
      'ỳýỵỷỹ' // y
      'đ';
  const plain =
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyy'
      'd';
  assert(
    marks.length == plain.length,
    'bảng bỏ dấu lệch: ${marks.length} vs ${plain.length}',
  );

  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = marks.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }

  return buffer.toString();
}

/// Một mục có khớp từ khoá không.
///
/// Khớp cả dòng phụ: người dùng nhớ "zalo" chứ không nhớ tính năng tên là
/// "Kết nối kênh".
bool matchesQuery({
  required String label,
  required String? subtitle,
  required String query,
}) {
  final needle = foldDiacritics(query.trim());
  if (needle.isEmpty) return true;

  return foldDiacritics(label).contains(needle) ||
      foldDiacritics(subtitle ?? '').contains(needle);
}
