/// QR nhận tiền chuẩn VietQR (EMVCo của NAPAS), spec nhan-su-kpi/01 §2.5.
/// Dựng ở máy từ BIN + số tài khoản; không gửi số tài khoản đi đâu. Cùng
/// thuật toán với web `src/modules/hr/domain/vietqr.ts`.
library;

String _tlv(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// CRC-16/CCITT-FALSE: đa thức 0x1021, khởi tạo 0xFFFF.
/// `crc16('123456789') == '29B1'`.
String crc16(String input) {
  var crc = 0xffff;
  for (final unit in input.codeUnits) {
    crc ^= unit << 8;
    for (var j = 0; j < 8; j++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xffff
          : (crc << 1) & 0xffff;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Chuỗi VietQR tĩnh (không số tiền). null khi BIN hoặc số tài khoản sai.
String? vietQrPayload(String? bin, String? account) {
  if (bin == null || !RegExp(r'^\d{6}$').hasMatch(bin)) return null;
  if (account == null || !RegExp(r'^\d{6,19}$').hasMatch(account)) return null;
  final merchant =
      _tlv('00', 'A000000727') +
      _tlv('01', _tlv('00', bin) + _tlv('01', account)) +
      _tlv('02', 'QRIBFTTA');
  final body =
      '${_tlv('00', '01')}${_tlv('01', '11')}${_tlv('38', merchant)}'
      '${_tlv('53', '704')}${_tlv('58', 'VN')}6304';
  return body + crc16(body);
}
