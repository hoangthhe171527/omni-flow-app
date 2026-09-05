import 'package:flutter/material.dart';

/// Nền tảng đọc từ Theme, không đọc `dart:io`.
///
/// Ba lý do, theo thứ tự quan trọng: `dart:io` ném lỗi trên web; ghi đè
/// `platform:` trong `ThemeData` là cách duy nhất test ép được nền tảng mà
/// không phải giả lập cả hệ điều hành; và nó cho phép xem thử giao diện iOS
/// trên máy Android khi cần.
///
/// Đây là nơi DUY NHẤT trong app biết câu trả lời. Một test kiến trúc chặn
/// module tự hỏi — xem `test/architecture/platform_boundary_test.dart`.
bool isApple(BuildContext context) =>
    isApplePlatform(Theme.of(context).platform);

/// Bản không cần context, cho chỗ đang dựng chính `ThemeData`.
bool isApplePlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};
