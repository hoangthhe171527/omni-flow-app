/// Loại tệp đang chờ trong composer.
enum PendingKind { image, file, voice }

/// Một tệp đã chọn nhưng chưa tải lên — ảnh, tài liệu hay bản ghi âm. Composer
/// giữ danh sách này cho tới khi gửi; trang chat tải từng tệp lên
/// `POST /inbox/media` rồi gửi tin với `type` do server trả.
class PendingAttachment {
  const PendingAttachment({
    required this.path,
    required this.name,
    required this.kind,
    this.size,
  });

  final String path;
  final String name;

  /// Byte. Null = trình chọn không cho biết (không chặn theo cỡ được).
  final int? size;
  final PendingKind kind;

  bool get isImage => kind == PendingKind.image;

  /// Đuôi thường, không dấu chấm; rỗng khi tên không có đuôi.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }
}
