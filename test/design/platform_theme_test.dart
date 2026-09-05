import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  group('theme thích ứng nền tảng', () {
    test('iOS canh giữa tiêu đề, Android canh trái', () {
      // iPhone canh giữa tiêu đề; Android canh trái. Trước đây app ép canh
      // trái cho cả hai.
      expect(
        OmniTheme.light(TargetPlatform.iOS).appBarTheme.centerTitle,
        isTrue,
      );
      expect(
        OmniTheme.light(TargetPlatform.android).appBarTheme.centerTitle,
        isFalse,
      );
    });

    test('iOS không có gợn sóng', () {
      // InkSparkle là gợn sóng của Android 12. Ép nó lên iPhone là thứ người
      // dùng iOS nhận ra ngay — còn rõ hơn cả chuyện chuyển cảnh.
      expect(
        OmniTheme.light(TargetPlatform.iOS).splashFactory,
        same(NoSplash.splashFactory),
      );
      expect(
        OmniTheme.light(TargetPlatform.android).splashFactory,
        same(InkSparkle.splashFactory),
      );
    });

    test('macOS tính là Apple', () {
      expect(
        OmniTheme.light(TargetPlatform.macOS).appBarTheme.centerTitle,
        isTrue,
      );
    });

    test('chế độ tối cũng theo nền tảng', () {
      expect(
        OmniTheme.dark(TargetPlatform.iOS).appBarTheme.centerTitle,
        isTrue,
      );
      expect(
        OmniTheme.dark(TargetPlatform.android).appBarTheme.centerTitle,
        isFalse,
      );
    });

    test('ThemeData mang theo nền tảng cho widget con đọc', () {
      // isApple(context) đọc từ đây. Nếu quên đặt, mọi widget con sẽ hỏi
      // defaultTargetPlatform và test không ép được nền tảng nữa.
      expect(OmniTheme.light(TargetPlatform.iOS).platform, TargetPlatform.iOS);
      expect(
        OmniTheme.dark(TargetPlatform.android).platform,
        TargetPlatform.android,
      );
    });

    test('gọi không tham số vẫn chạy', () {
      // Mọi chỗ gọi sẵn có — omni_app.dart, tool/ui_preview.dart, test cũ —
      // không phải sửa.
      expect(OmniTheme.light(), isA<ThemeData>());
      expect(OmniTheme.dark(), isA<ThemeData>());
    });

    test('chuyển cảnh vẫn để mặc định của Flutter', () {
      // CỐ Ý không đụng vào. Mặc định của Flutter đã dùng
      // CupertinoPageTransitionsBuilder cho iOS, tức trượt ngang KÈM cử chỉ
      // vuốt-quay-lại. Đặt pageTransitionsTheme vào đây là làm hỏng thứ đang
      // đúng — test này tồn tại để người sau không "sửa" nó.
      expect(
        OmniTheme.light(TargetPlatform.iOS).pageTransitionsTheme,
        const PageTransitionsTheme(),
      );
    });
  });
}
