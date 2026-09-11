import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/mention.dart';

/// Logic thuần của nhắc tên bằng `@`: tìm đoạn đang gõ, gợi ý, chèn, và đọc
/// lại id từ chữ lúc gửi.
///
/// Tách khỏi widget để kiểm từng ca biên bằng chuỗi, không cần dựng ô nhập:
/// dấu tiếng Việt, tên hai chữ, `@` trong địa chỉ email, xoá tên rồi gửi.
void main() {
  const people = {'u-1': 'Hằng Ni', 'u-2': 'Luận', 'u-3': 'Minh Anh'};

  group('fold: so khớp không dấu, không hoa thường', () {
    test('bỏ dấu và chữ đ', () {
      expect(Mentions.fold('Hằng Ni'), 'hang ni');
      expect(Mentions.fold('Đặng Lưu'), 'dang luu');
      expect(Mentions.fold('LUẬN'), 'luan');
    });
  });

  group('queryAt: đoạn "@…" ngay trước con trỏ', () {
    test('sau @ ở đầu hoặc sau khoảng trắng', () {
      expect(Mentions.queryAt('@', 1), '');
      expect(Mentions.queryAt('nhờ @Lu', 7), 'Lu');
      expect(Mentions.queryAt('nhờ @Hằng N xem', 11), 'Hằng N');
    });

    test('KHÔNG bắt @ trong địa chỉ email hay giữa chữ', () {
      expect(Mentions.queryAt('mail a@b', 8), isNull);
      expect(Mentions.queryAt('giá 5k/@', 8), isNull);
    });

    test('không có @ trước con trỏ thì null', () {
      expect(Mentions.queryAt('chưa đạt', 8), isNull);
      // Con trỏ đứng TRƯỚC dấu @ thì đoạn đó chưa "đang gõ".
      expect(Mentions.queryAt('@Luận', 0), isNull);
    });

    test('xuống dòng cắt đoạn', () {
      expect(Mentions.queryAt('@Lu\nận', 6), isNull);
    });
  });

  group('suggest: khớp đầu từ, không dấu', () {
    test('rỗng thì ra tất cả, giữ thứ tự', () {
      expect(Mentions.suggest(people, '').map((e) => e.key), [
        'u-1',
        'u-2',
        'u-3',
      ]);
    });

    test('khớp đầu tên và đầu MỖI từ trong tên', () {
      expect(Mentions.suggest(people, 'l').map((e) => e.value), ['Luận']);
      expect(Mentions.suggest(people, 'ni').map((e) => e.value), ['Hằng Ni']);
      expect(Mentions.suggest(people, 'anh').map((e) => e.value), ['Minh Anh']);
    });

    test('gõ có dấu hay không dấu đều ra', () {
      expect(Mentions.suggest(people, 'hằng').length, 1);
      expect(Mentions.suggest(people, 'hang').length, 1);
    });

    test('không khớp thì rỗng', () {
      expect(Mentions.suggest(people, 'xyz'), isEmpty);
    });
  });

  group('insert: thay "@đoạn" bằng "@Tên "', () {
    test('thay đúng đoạn đang gõ, con trỏ đứng sau khoảng trắng', () {
      final r = Mentions.insert('nhờ @Lu xem', 7, 'Luận');

      expect(r.text, 'nhờ @Luận  xem');
      expect(r.cursor, 'nhờ @Luận '.length);
    });

    test('không có @ đang gõ thì chèn "@Tên " tại con trỏ', () {
      final r = Mentions.insert('nhờ ', 4, 'Luận');

      expect(r.text, 'nhờ @Luận ');
      expect(r.cursor, r.text.length);
    });

    test('chèn giữa chữ thì tự đệm khoảng trắng phía trước', () {
      final r = Mentions.insert('nhờxem', 3, 'Luận');

      expect(r.text, 'nhờ @Luận xem');
    });
  });

  group('idsIn: id lấy từ CHỮ lúc gửi', () {
    test('có @Tên trong chữ thì có id', () {
      expect(Mentions.idsIn('nhờ @Luận xem lại', people), ['u-2']);
      expect(Mentions.idsIn('@Hằng Ni và @Luận', people), ['u-1', 'u-2']);
    });

    test('xoá tên khỏi chữ là hết nhắc', () {
      expect(Mentions.idsIn('nhờ xem lại', people), isEmpty);
    });

    test('tên là TIỀN TỐ của tên khác không bị nhận nhầm', () {
      // "Minh" không phải "Minh Anh"; "@Minh" không nhắc ai cả.
      expect(Mentions.idsIn('@Minh ơi', people), isEmpty);
      // Nhưng "@Minh Anh" thì đúng là u-3.
      expect(Mentions.idsIn('@Minh Anh ơi', people), ['u-3']);
    });

    test('mỗi người một lần dù nhắc hai lần', () {
      expect(Mentions.idsIn('@Luận rồi @Luận', people), ['u-2']);
    });
  });

  group('highlight: cắt thân bình luận thành đoạn thường và đoạn @Tên', () {
    test('tô đúng tên được nhắc, để nguyên phần còn lại', () {
      final parts = Mentions.split('QC trượt, @Luận xem lại', ['Luận']);

      expect(parts.map((p) => (p.text, p.isMention)).toList(), [
        ('QC trượt, ', false),
        ('@Luận', true),
        (' xem lại', false),
      ]);
    });

    test('không tô @ lạ không nằm trong danh sách được nhắc', () {
      final parts = Mentions.split('gửi a@b nhé', ['Luận']);

      expect(parts.single.isMention, isFalse);
    });
  });
}
