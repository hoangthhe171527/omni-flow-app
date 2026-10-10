/// Điểm độ mạnh mật khẩu, 0–4: mỗi tiêu chí đạt được một điểm.
///
/// Tiêu chí: từ 8 ký tự; có cả chữ hoa lẫn chữ thường; có chữ số; có ký tự
/// đặc biệt. Chỉ là gợi ý cho người dùng — luật thật là `min:8` của API.
int passwordScore(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp('[a-z]').hasMatch(password) &&
      RegExp('[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp('[0-9]').hasMatch(password)) score++;
  if (RegExp('[^A-Za-z0-9]').hasMatch(password)) score++;
  return score;
}

String passwordLabel(int score) => switch (score) {
  <= 1 => 'Yếu',
  2 => 'Tạm',
  3 => 'Khá',
  _ => 'Mạnh',
};

/// Định dạng email đủ chặt cho ô nhập; server vẫn là nơi xác nhận cuối.
bool looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
