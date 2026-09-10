import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Bảng nền phải đủ tối cho chữ trắng, và không được ném lỗi vì một cái tên lạ.
void main() {
  test('có đúng tám nền', () {
    expect(OmniCovers.names, hasLength(8));
  });

  test('tên không trùng nhau', () {
    expect(OmniCovers.names.toSet(), hasLength(8));
  });

  test('mọi tên đều dịch được thành gradient', () {
    for (final name in OmniCovers.names) {
      expect(OmniCovers.gradientOf(name).colors, isNotEmpty);
    }
  });

  test('tên lạ rơi về nền mặc định, KHÔNG ném lỗi', () {
    // Web và app giữ hai bảng riêng. Lệch một tên mà app ném lỗi thì một dự án
    // tạo ở bên kia sẽ làm sập màn danh sách ở bên này.
    expect(
      OmniCovers.gradientOf('mot-ten-khong-ton-tai').colors,
      OmniCovers.gradientOf(OmniCovers.fallback).colors,
    );
  });

  test('null cũng rơi về nền mặc định', () {
    // MỌI dự án tạo trước tính năng này đều có `cover == null`.
    expect(
      OmniCovers.gradientOf(null).colors,
      OmniCovers.gradientOf(OmniCovers.fallback).colors,
    );
  });

  test('nền nào cũng đủ tối để chữ trắng đọc được', () {
    // Tên dự án viết ĐÈ lên nền bằng chữ trắng. Một nền sáng làm chữ biến mất,
    // và người chọn không biết trước điều đó lúc bấm.
    //
    // Bài này đỏ thì CHỈNH MÀU, đừng nới ngưỡng — ngưỡng chính là thứ tính
    // năng hứa.
    for (final name in OmniCovers.names) {
      for (final color in OmniCovers.gradientOf(name).colors) {
        expect(
          color.computeLuminance(),
          lessThan(0.4),
          reason: '$name có một màu quá sáng cho chữ trắng',
        );
      }
    }
  });

  test('nền mặc định nằm trong bảng', () {
    // `fallback` trỏ vào một tên không tồn tại thì `gradientOf` sẽ ném lỗi ở
    // đúng nhánh dựng ra để KHÔNG ném lỗi.
    expect(OmniCovers.names, contains(OmniCovers.fallback));
  });
}
