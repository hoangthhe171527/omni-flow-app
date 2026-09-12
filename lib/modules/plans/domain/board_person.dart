/// Ai đang được lọc trên bảng.
///
/// Ba trạng thái, không phải hai: [everyone] là không lọc, [unassigned] là
/// những cây CHƯA AI NHẬN, và một id người là một người cụ thể. Trạng thái
/// giữa mới là thứ §3 cần — xưởng chạy kiểu pull, nên "công đoạn nào đang
/// trống" là câu hỏi người thợ hỏi mỗi lần rảnh tay, và trước nay chỉ trả lời
/// được bằng cách lướt hết bảng đọc từng thẻ.
///
/// Là giá trị (có `==`): nó nằm trong khoá của `boardBucketsProvider`, và hai
/// lần chọn cùng một người phải trỏ về cùng một rổ đã tính.
sealed class BoardPerson {
  const BoardPerson();

  static const everyone = _Everyone();
  static const unassigned = _Unassigned();

  const factory BoardPerson.person(String userId, String name) = _Person;
}

final class _Everyone extends BoardPerson {
  const _Everyone();
}

final class _Unassigned extends BoardPerson {
  const _Unassigned();
}

final class _Person extends BoardPerson {
  const _Person(this.userId, this.name);

  final String userId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is _Person && other.userId == userId && other.name == name;

  @override
  int get hashCode => Object.hash(userId, name);
}

extension BoardPersonX on BoardPerson {
  /// Nhãn trên chip đang lọc. null khi không lọc gì.
  String? get chipLabel => switch (this) {
    _Everyone() => null,
    _Unassigned() => 'Chưa giao ai',
    _Person(:final name) => name,
  };

  /// Id người đang lọc; null với hai trạng thái không phải một người.
  String? get userId => switch (this) {
    _Person(:final userId) => userId,
    _ => null,
  };

  bool get isEveryone => this is _Everyone;

  bool get isUnassigned => this is _Unassigned;

  /// Cây đàn này có thuộc bộ lọc không.
  bool matches(List<String> assigneeIds) => switch (this) {
    _Everyone() => true,
    _Unassigned() => assigneeIds.isEmpty,
    _Person(:final userId) => assigneeIds.contains(userId),
  };
}
