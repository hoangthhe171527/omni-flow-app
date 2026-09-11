/// Nhắc tên bằng `@` trong ô soạn trao đổi — phần thuần chuỗi.
///
/// Người thợ quen Zalo/Slack cứ gõ `@` rồi chờ gợi ý; bản trước là một dãy
/// chip đứng riêng, và chọn chip là một trạng thái NGẦM không hiện trong câu.
/// Ở đây `@Tên` nằm trong chính câu, và danh sách id gửi đi được đọc lại từ
/// câu đó lúc gửi: xoá chữ là hết nhắc, không có gì để lệch giữa cái nhìn thấy
/// và cái gửi đi.
///
/// Hợp đồng với server không đổi: `body` là chữ như đã gõ (kể cả `@Tên`),
/// `mentioned_user_ids` là id — web cũng gửi đúng hai thứ đó.
abstract final class Mentions {
  static const _plain = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final _foldTable = <int, String>{
    for (final e in _plain.entries)
      for (final r in e.value.runes) r: e.key,
  };

  static final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Chữ thường, không dấu, `đ` → `d`. Để "hang" khớp "Hằng".
  static String fold(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      b.write(_foldTable[r] ?? String.fromCharCode(r));
    }

    return b.toString();
  }

  /// Vị trí dấu `@` mở đầu đoạn đang gõ trước [cursor], hoặc -1.
  ///
  /// `@` phải đứng đầu chuỗi hoặc sau khoảng trắng — `a@b` trong một địa chỉ
  /// email không phải là nhắc ai. Đoạn không được vắt qua xuống dòng.
  static int _openAt(String text, int cursor) {
    if (cursor <= 0 || cursor > text.length) return -1;
    final prefix = text.substring(0, cursor);
    final at = prefix.lastIndexOf('@');
    if (at < 0) return -1;
    if (at > 0 && !_isSpace(prefix[at - 1])) return -1;
    if (prefix.substring(at + 1).contains('\n')) return -1;

    return at;
  }

  /// Đoạn chữ sau `@` đang gõ ngay trước [cursor], hoặc null nếu không có.
  static String? queryAt(String text, int cursor) {
    final at = _openAt(text, cursor);

    return at < 0 ? null : text.substring(at + 1, cursor);
  }

  /// Ứng viên khớp [query]: đầu tên hoặc đầu bất kỳ từ nào, không dấu.
  ///
  /// Rỗng nếu [query] đã là một tên trọn vẹn kèm khoảng trắng phía sau —
  /// tức là vừa chọn xong, không còn gì để gợi ý.
  static List<MapEntry<String, String>> suggest(
    Map<String, String> candidates,
    String query,
  ) {
    final q = fold(query.trim());
    if (q.isEmpty) return candidates.entries.toList();

    final done =
        query.endsWith(' ') && candidates.values.any((n) => fold(n) == q);
    if (done) return const [];

    return [
      for (final e in candidates.entries)
        if (fold(e.value).startsWith(q) ||
            fold(e.value).split(' ').any((w) => w.startsWith(q)))
          e,
    ];
  }

  /// Thay đoạn `@…` đang gõ bằng `@[name] `, hoặc chèn tại con trỏ nếu chưa
  /// có đoạn nào. Trả về chữ mới và vị trí con trỏ (ngay sau khoảng trắng).
  static ({String text, int cursor}) insert(
    String text,
    int cursor,
    String name,
  ) {
    final safe = cursor.clamp(0, text.length);
    var start = _openAt(text, safe);
    var lead = '';
    if (start < 0) {
      start = safe;
      if (start > 0 && !_isSpace(text[start - 1])) lead = ' ';
    }
    final token = '$lead@$name ';
    final out = text.replaceRange(start, safe, token);

    return (text: out, cursor: start + token.length);
  }

  /// Id của những người mà `@Tên` còn nằm trong [body], theo thứ tự ứng viên,
  /// mỗi người một lần. Đọc từ CHỮ, không từ trạng thái nào khác.
  static List<String> idsIn(String body, Map<String, String> candidates) => [
    for (final e in candidates.entries)
      if (_mentions(body, e.value)) e.key,
  ];

  static bool _mentions(String body, String name) {
    final token = '@$name';
    var from = 0;
    while (true) {
      final i = body.indexOf(token, from);
      if (i < 0) return false;
      if (_boundary(body, i + token.length)) return true;
      from = i + 1;
    }
  }

  /// Cắt thân bình luận thành đoạn thường và đoạn `@Tên` để tô màu.
  ///
  /// Chỉ tô tên có trong [names] (danh sách server trả về) — một `@` lạ trong
  /// câu không được tô như thể nó nhắc ai.
  static List<MentionPart> split(String body, List<String> names) {
    if (names.isEmpty || !body.contains('@')) {
      return [MentionPart(body, isMention: false)];
    }
    // Tên dài trước, để "@Minh Anh" không bị "@Minh" cướp mất.
    final sorted = [...names]..sort((a, b) => b.length.compareTo(a.length));

    final parts = <MentionPart>[];
    final plain = StringBuffer();
    var i = 0;
    while (i < body.length) {
      String? hit;
      if (body[i] == '@') {
        for (final n in sorted) {
          final token = '@$n';
          if (body.startsWith(token, i) && _boundary(body, i + token.length)) {
            hit = token;
            break;
          }
        }
      }
      if (hit == null) {
        plain.write(body[i]);
        i++;
        continue;
      }
      if (plain.isNotEmpty) {
        parts.add(MentionPart(plain.toString(), isMention: false));
        plain.clear();
      }
      parts.add(MentionPart(hit, isMention: true));
      i += hit.length;
    }
    if (plain.isNotEmpty || parts.isEmpty) {
      parts.add(MentionPart(plain.toString(), isMention: false));
    }

    return parts;
  }

  static bool _boundary(String s, int end) =>
      end >= s.length || !_word.hasMatch(s[end]);

  static bool _isSpace(String c) => c.trim().isEmpty;
}

/// Một đoạn của thân bình luận: chữ thường hoặc một `@Tên`.
class MentionPart {
  const MentionPart(this.text, {required this.isMention});

  final String text;
  final bool isMention;
}
