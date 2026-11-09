import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/domain/packing_list.dart';

/// Đọc packing list dán từ Excel — cùng quy tắc với web `packing-list.ts`.
void main() {
  const sample = [
    'STT\tLOẠI\tMAKER\tMODEL\tSERIAL NO\tCOLOR\tGiá nhập (¥)\tGIÁ BÁN\tKHÁCH HÀNG',
    '1\tPiano Upright cũ\tyamaha\tU3H\t2204585.0\tĐen\t135000\t35500000\t',
    '2\tPiano Upright cũ\tYAMAHA\tU3H\t2371154\tĐen\t135.000\t35.500.000\tAnh Bình · Q.10',
    '',
    '3\tPiano Upright cũ\tKAWAI\tKU-5\tK123877\tNâu\t\t29000000\t',
    '4\tTrống điện\tROLAND\t\t\t\t18000\t\t',
  ];

  test('nhận cột theo tiêu đề, bỏ dòng trống', () {
    final pl = parsePackingList(sample.join('\r\n'));

    expect(pl.rows, hasLength(4));
    expect(pl.columns[PastedColumn.category], 'LOẠI');
    expect(pl.columns[PastedColumn.maker], 'MAKER');
    expect(pl.columns[PastedColumn.model], 'MODEL');
    expect(pl.columns[PastedColumn.serial], 'SERIAL NO');
    expect(pl.columns[PastedColumn.yenPrice], 'Giá nhập (¥)');
    expect(pl.columns[PastedColumn.listPrice], 'GIÁ BÁN');
    expect(pl.columns[PastedColumn.customer], 'KHÁCH HÀNG');
    // "COLOR" không khớp "màu" — giống web.
    expect(pl.columns[PastedColumn.color], isNull);

    final r = pl.rows[1];
    expect(r.maker, 'YAMAHA');
    expect(r.model, 'U3H');
    expect(r.category, 'Piano Upright cũ');
    expect(r.yenPrice, 135000);
    expect(r.listPrice, 35500000);
    expect(r.customer, 'Anh Bình · Q.10');
    expect(r.issues, isEmpty);
  });

  test('serial dạng số Excel bỏ ".0" và được đánh dấu', () {
    final r = parsePackingList(sample.join('\n')).rows.first;
    expect(r.serial, '2204585');
    expect(r.maker, 'YAMAHA');
    expect(r.issues, {PastedIssue.serialFixed});
  });

  test('thiếu ¥ và thiếu model', () {
    final pl = parsePackingList(sample.join('\n'));
    expect(pl.rows[2].issues, {PastedIssue.noYen});
    expect(pl.rows[2].yenPrice, isNull);
    expect(pl.rows[3].issues, {PastedIssue.noModel});
    expect(pl.count(PastedIssue.noYen), 1);
    expect(pl.count(PastedIssue.noModel), 1);
    expect(pl.valid, hasLength(3));
  });

  test('toInput bỏ ¥ khi không có quyền giá', () {
    final r = parsePackingList(sample.join('\n')).rows[1];
    expect(r.toInput(withYen: true).toPayload()['yen_price'], 135000);
    expect(
      r.toInput(withYen: false).toPayload().containsKey('yen_price'),
      isFalse,
    );
    expect(r.toInput(withYen: true).toPayload()['serial'], '2371154');
  });

  test('chỉ một dòng (không có dữ liệu) thì rỗng', () {
    final pl = parsePackingList(sample.first);
    expect(pl.rows, isEmpty);
    expect(pl.columns, isEmpty);
  });

  test('tiêu đề tiếng Việt: Hãng, Màu, Niêm yết', () {
    final pl = parsePackingList(
      'Hãng\tModel\tSerial\tMàu\tNiêm yết\tYen\nCasio\tAP-470\tI 3758\tBK\t11000000\t40000',
    );
    final r = pl.rows.single;
    expect(r.maker, 'CASIO');
    expect(r.color, 'BK');
    expect(r.serial, 'I 3758');
    expect(r.listPrice, 11000000);
    expect(r.yenPrice, 40000);
    expect(pl.columns[PastedColumn.category], isNull);
  });
}
