import '../error/app_exception.dart';

/// Một ĐOẠN đường API dựng từ id (`/tasks/${pathSegment(id)}/claim`).
///
/// Id đến từ route (`/inbox/:id` trên web là link người ngoài soạn được), từ
/// push, từ JSON. go_router giải mã `%2F`, `%23`, `%3F` trước khi trao id cho
/// màn, nên id `../../tasks/1/claim#` ghép thẳng vào đường thì Dio gộp `..` và
/// cắt ở `#` — request đi tới một đường API khác hẳn, bằng phiên người dùng.
///
/// Mã hoá bằng [Uri.encodeComponent] để id luôn là đúng một đoạn. Giữ `:` và
/// `@` (hợp lệ trong một đoạn đường theo RFC 3986) vì vài khoá thật có chúng.
/// `.`/`..`/rỗng không mã hoá được (Dart tự giải `%2E` về `.`), nên từ chối.
String pathSegment(String id) {
  if (id.isEmpty || id == '.' || id == '..') {
    throw const NotFoundException('Không tìm thấy.');
  }
  return Uri.encodeComponent(id).replaceAll('%3A', ':').replaceAll('%40', '@');
}

final _dotSegment = RegExp(r'(^|/)\.{1,2}($|/)');

/// Đường có đoạn `.`/`..` — kể cả viết dạng `%2e`, hay nằm trong một đoạn đã
/// mã hoá `%2F` (máy chủ Laravel giải mã đường trước khi khớp route).
bool hasDotSegment(String path) {
  final cut = path.indexOf(RegExp(r'[?#]'));
  final raw = cut < 0 ? path : path.substring(0, cut);
  String decoded;
  try {
    decoded = Uri.decodeFull(Uri.decodeFull(raw));
  } catch (_) {
    decoded = raw;
  }
  decoded = decoded.replaceAll(r'\', '/');
  return _dotSegment.hasMatch(decoded);
}
