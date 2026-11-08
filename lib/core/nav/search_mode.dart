import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Đang ở chế độ tìm của thanh trên (ô tìm đang được chạm vào).
///
/// `OmniTopBar` bật khi ô tìm có focus và tắt khi rời; thanh tab dưới đọc cờ
/// này để trượt xuống ẩn — giống Thư viện ứng dụng iOS: lúc tìm chỉ còn ô tìm
/// và kết quả (`viomni-apple-uiux.html`, duyệt 07/11).
final searchModeProvider = StateProvider<bool>((ref) => false);
