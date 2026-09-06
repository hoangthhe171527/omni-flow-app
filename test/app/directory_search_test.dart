import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/directory_page.dart';

/// Người dùng gõ trên bàn phím điện thoại, giữa lúc làm việc, và sẽ không bật
/// bộ gõ tiếng Việt lên chỉ để tìm một màn hình.
void main() {
  group('bỏ dấu', () {
    test('bảng ánh xạ hai chiều dài bằng nhau', () {
      // Lệch một ký tự là mọi chữ sau đó ánh xạ sai — âm thầm, không lỗi, chỉ
      // là tìm không ra. Kiểm bằng chính hàm: 'đ' là ký tự cuối bảng, nên nếu
      // bảng lệch thì nó ra sai.
      expect(foldDiacritics('đ'), 'd');
      expect(foldDiacritics('ỹ'), 'y');
    });

    test('bỏ dấu và hạ chữ thường', () {
      expect(foldDiacritics('Kết nối kênh'), 'ket noi kenh');
      expect(foldDiacritics('CƠ HỘI'), 'co hoi');
      expect(foldDiacritics('Việc của tôi'), 'viec cua toi');
    });

    test('chữ không dấu giữ nguyên', () {
      expect(foldDiacritics('Zalo Facebook'), 'zalo facebook');
    });
  });

  group('khớp từ khoá', () {
    test('khớp nhãn, không phân biệt hoa thường và dấu', () {
      expect(
        matchesQuery(label: 'Kết nối kênh', subtitle: null, query: 'kênh'),
        isTrue,
      );
      expect(
        matchesQuery(label: 'Kết nối kênh', subtitle: null, query: 'KENH'),
        isTrue,
      );
      expect(
        matchesQuery(label: 'Kết nối kênh', subtitle: null, query: 'noi'),
        isTrue,
      );
    });

    test('khớp cả dòng phụ', () {
      // Người dùng nhớ "zalo" chứ không nhớ tính năng tên là "Kết nối kênh".
      expect(
        matchesQuery(
          label: 'Kết nối kênh',
          subtitle: 'Nối Zalo, Facebook, TikTok vào hộp thư',
          query: 'zalo',
        ),
        isTrue,
      );
    });

    test('từ khoá rỗng thì mọi mục đều khớp', () {
      expect(matchesQuery(label: 'x', subtitle: null, query: ''), isTrue);
      expect(matchesQuery(label: 'x', subtitle: null, query: '   '), isTrue);
    });

    test('không khớp thì loại', () {
      expect(
        matchesQuery(label: 'Hộp thư', subtitle: null, query: 'kho'),
        isFalse,
      );
    });

    test('dòng phụ rỗng không làm hỏng phép khớp', () {
      expect(
        matchesQuery(label: 'Hộp thư', subtitle: null, query: 'hop'),
        isTrue,
      );
    });
  });
}
