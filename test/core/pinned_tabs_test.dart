import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';

/// Pin được lọc lại LÚC ĐỌC. Quyền có thể bị thu hồi và module có thể bị gỡ,
/// cả hai đều xảy ra sau khi người dùng đã ghim — và một tab dẫn tới màn báo
/// "không có quyền" tệ hơn là không có tab.
void main() {
  test('pin trỏ tới mục không còn quyền bị bỏ', () {
    expect(resolvePins(saved: ['a', 'b'], allowed: ['a', 'c']), ['a']);
  });

  test('pin trỏ tới route đã xoá bị bỏ', () {
    expect(resolvePins(saved: ['đã-gỡ'], allowed: ['a']), isEmpty);
  });

  test('quá 4 thì cắt còn 4', () {
    expect(
      resolvePins(
        saved: ['a', 'b', 'c', 'd', 'e'],
        allowed: ['a', 'b', 'c', 'd', 'e'],
      ),
      ['a', 'b', 'c', 'd'],
    );
  });

  test('không pin thì trả về rỗng, để chỗ gọi tự lấy mặc định', () {
    // Rỗng nghĩa là "chưa chọn", không phải "chọn không có gì". Phân biệt được
    // hai cái đó là điều khiến người chưa bao giờ mở màn chọn tab vẫn có tab.
    expect(resolvePins(saved: const [], allowed: ['a']), isEmpty);
  });

  test('thứ tự do hệ thống, không do thứ tự người dùng bấm', () {
    // Người dùng chọn CÁI NÀO, không phải XẾP RA SAO. Bỏ phần xếp đi là bỏ
    // được kéo-thả, mà kéo-thả thì luật accessibility bắt phải có cách thay
    // thế không cần kéo.
    expect(resolvePins(saved: ['c', 'a'], allowed: ['a', 'b', 'c']), [
      'a',
      'c',
    ]);
  });

  test('mất hết quyền thì rơi về mặc định chứ không phải thanh tab trống', () {
    expect(resolvePins(saved: ['a', 'b'], allowed: const []), isEmpty);
  });

  test('trần pin bằng trần tab', () {
    // Hai con số này lệch nhau là người dùng ghim được 5 mục rồi chỉ thấy 4,
    // không hiểu vì sao.
    expect(maxPinnedTabs, 4);
  });
}
