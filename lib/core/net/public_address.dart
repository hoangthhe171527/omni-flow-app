/// Host nào app được TỰ gửi request tới thay người dùng (xem trước link, tải
/// media do khách gửi) — tức là không phải mạng nội bộ của máy nhân viên.
///
/// Thuần Dart, không `dart:io`: chạy được cả trên web. Kiểm theo CHỮ của host
/// sau khi chuẩn hoá mọi cách viết IP mà trình phân giải của hệ điều hành chấp
/// nhận (`2130706433`, `127.1`, `0x7f.0.0.1`, `0177.0.0.1`, IPv6, IPv4 nhúng
/// trong IPv6). Tên miền thường thì cần thêm bước phân giải DNS — xem
/// `host_lookup.dart`.
library;

/// `true` nếu [host] (dạng `Uri.host`) KHÔNG rõ ràng trỏ vào mạng nội bộ: tên
/// miền công khai, hoặc IP công khai. Tên miền vẫn có thể phân giải ra IP nội
/// bộ — việc đó do người gọi kiểm thêm khi có DNS.
bool isPublicHostLiteral(String host) {
  var h = host.trim().toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  // `localhost.` = `localhost`: dấu chấm cuối là tên tuyệt đối.
  while (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  if (h.isEmpty) return false;

  final ip = parseIpLiteral(h);
  if (ip != null) return isPublicAddress(ip);
  // Trông như IP (toàn số/hex) mà không parse được: trình phân giải mỗi nền
  // tảng hiểu một kiểu — không đoán, chặn.
  if (_looksNumeric(h)) return false;

  if (!h.contains('.')) return false; // `router`, `intranet`: tên nội bộ.
  if (h.contains('%')) return false; // zone id, ký tự lạ.
  for (final suffix in _internalSuffixes) {
    if (h == suffix || h.endsWith('.$suffix')) return false;
  }
  return true;
}

const _internalSuffixes = [
  'localhost',
  'local',
  'localdomain',
  'internal',
  'intranet',
  'lan',
  'home',
  'corp',
  'home.arpa',
  'in-addr.arpa',
  'ip6.arpa',
];

bool _looksNumeric(String h) =>
    RegExp(r'^(0x[0-9a-f]*|[0-9]+)(\.(0x[0-9a-f]*|[0-9]*))*$').hasMatch(h);

/// Byte của địa chỉ (4 cho IPv4, 16 cho IPv6), hoặc `null` nếu [host] không
/// phải IP. IPv4 theo cách đọc của `inet_aton`/WHATWG: 1–4 phần, mỗi phần thập
/// phân, hex `0x` hay bát phân `0`; phần cuối lấp các byte còn lại.
List<int>? parseIpLiteral(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  if (h.contains(':')) {
    final zone = h.indexOf('%');
    final bare = zone < 0 ? h : h.substring(0, zone);
    try {
      return Uri.parseIPv6Address(bare);
    } on FormatException {
      return null;
    }
  }
  return _parseIpv4(h);
}

List<int>? _parseIpv4(String h) {
  final parts = h.split('.');
  if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
  if (parts.isEmpty || parts.length > 4) return null;
  final values = <int>[];
  for (final part in parts) {
    final v = _parseIpv4Part(part);
    if (v == null) return null;
    values.add(v);
  }
  for (var i = 0; i < values.length - 1; i++) {
    if (values[i] > 255) return null;
  }
  final remaining = 5 - values.length; // byte mà phần cuối phải lấp
  final last = values.last;
  if (last >= (BigInt.one << (8 * remaining)).toInt()) return null;
  final bytes = <int>[...values.take(values.length - 1)];
  for (var i = remaining - 1; i >= 0; i--) {
    bytes.add((last >> (8 * i)) & 0xff);
  }
  return bytes;
}

int? _parseIpv4Part(String part) {
  if (part.isEmpty) return null;
  if (part.startsWith('0x')) {
    final hex = part.substring(2);
    if (hex.isEmpty) return 0;
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex) || hex.length > 8) return null;
    return int.parse(hex, radix: 16);
  }
  if (part.length > 1 && part.startsWith('0')) {
    if (!RegExp(r'^[0-7]+$').hasMatch(part) || part.length > 12) return null;
    return int.parse(part, radix: 8);
  }
  if (!RegExp(r'^[0-9]+$').hasMatch(part) || part.length > 10) return null;
  return int.parse(part);
}

/// Địa chỉ định tuyến công khai được — không loopback, private, link-local,
/// CGNAT, metadata đám mây, multicast, dải dành riêng.
bool isPublicAddress(List<int> bytes) {
  if (bytes.length == 4) return _isPublicV4(bytes);
  if (bytes.length != 16) return false;

  // IPv4 nhúng: ::ffff:a.b.c.d (mapped), ::a.b.c.d (compat), 64:ff9b::/96
  // (NAT64) — xét phần IPv4 bên trong.
  final first10Zero = bytes.take(10).every((b) => b == 0);
  if (first10Zero && bytes[10] == 0xff && bytes[11] == 0xff) {
    return _isPublicV4(bytes.sublist(12));
  }
  if (bytes.take(12).every((b) => b == 0)) {
    return false; // ::, ::1, ::a.b.c.d (đã bỏ)
  }
  if (bytes[0] == 0x00 &&
      bytes[1] == 0x64 &&
      bytes[2] == 0xff &&
      bytes[3] == 0x9b &&
      bytes.sublist(4, 12).every((b) => b == 0)) {
    return _isPublicV4(bytes.sublist(12));
  }
  // 6to4 2002::/16 mang IPv4 ở byte 2–5.
  if (bytes[0] == 0x20 && bytes[1] == 0x02) {
    return _isPublicV4(bytes.sublist(2, 6));
  }
  // 2001:db8::/32 tài liệu; 2001::/32 Teredo — không nên tự gọi.
  if (bytes[0] == 0x20 && bytes[1] == 0x01) {
    if (bytes[2] == 0x0d && bytes[3] == 0xb8) return false;
    if (bytes[2] == 0x00 && bytes[3] == 0x00) return false;
  }
  // Chỉ global unicast 2000::/3. Loại fc00::/7 (ULA), fe80::/10, ff00::/8…
  return (bytes[0] & 0xe0) == 0x20;
}

bool _isPublicV4(List<int> b) {
  final a0 = b[0], a1 = b[1], a2 = b[2];
  if (a0 == 0) return false; // 0.0.0.0/8 — "máy này"
  if (a0 == 10) return false;
  if (a0 == 100 && a1 >= 64 && a1 <= 127) return false; // CGNAT
  if (a0 == 127) return false;
  if (a0 == 169 && a1 == 254) return false; // link-local, metadata đám mây
  if (a0 == 172 && a1 >= 16 && a1 <= 31) return false;
  if (a0 == 192 && a1 == 0 && (a2 == 0 || a2 == 2)) return false;
  if (a0 == 192 && a1 == 88 && a2 == 99) return false;
  if (a0 == 192 && a1 == 168) return false;
  if (a0 == 198 && (a1 == 18 || a1 == 19)) return false; // benchmark
  if (a0 == 198 && a1 == 51 && a2 == 100) return false;
  if (a0 == 203 && a1 == 0 && a2 == 113) return false;
  if (a0 >= 224) return false; // multicast, dành riêng, broadcast
  return true;
}

/// URL `http`/`https` có host công khai theo chữ (xem [isPublicHostLiteral]).
bool isPublicHttpUrl(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    isPublicHostLiteral(uri.host);
