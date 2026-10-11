import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/outbound_capabilities.dart';
import '../../domain/pending_attachment.dart';

/// Đuôi tài liệu cho mục "Tệp" — khớp `omni-flow-api/config/media.php` kind
/// `file` (upload kiểm MIME dò từ nội dung; đuôi khác sẽ 422).
const kInboxFileExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'csv',
];

/// Nén ảnh PHÍA MÁY trước khi tải lên, bằng chính `image_picker`
/// (`maxWidth`/`maxHeight` + `imageQuality`, ra JPEG): không thêm gói nén.
///
/// Mặc định cạnh dài ≤ 2048px, chất lượng 85 — ảnh điện thoại 4–8MB còn vài
/// trăm KB, tải nhanh hơn trên 4G. Kênh có `image_constraints` chặt (Zalo OA:
/// ≤ 1MB) thì ≤ 1600px, chất lượng 75: một JPEG như vậy thường 200–500KB, dưới
/// trần 1MB. Không đảm bảo tuyệt đối — ảnh vẫn vượt thì `POST /inbox/media`
/// nén JPG/PNG/WebP xuống ≤ 1MB, nên composer chỉ cảnh báo theo ĐUÔI.
///
/// GIF không được `image_picker` nén lại (giữ nguyên tệp gốc); composer báo
/// trước vì Zalo OA gửi GIF thành link.
({double maxDimension, int quality}) inboxImagePickOptions(
  OutboundCapabilities? capabilities,
) {
  final max = capabilities?.imageConstraints?.nativeMaxBytes;
  if (max != null && max <= 2 * 1024 * 1024) {
    return (maxDimension: 1600, quality: 75);
  }
  return (maxDimension: 2048, quality: 85);
}

/// Trình chọn của hệ điều hành không mở được (từ chối quyền, máy ảnh bận…).
/// [message] là câu cho người dùng.
class PickerUnavailable implements Exception {
  const PickerUnavailable(this.message);

  final String message;

  @override
  String toString() => 'PickerUnavailable: $message';
}

/// Chọn ảnh từ thư viện, tối đa [remaining] ảnh. Còn đúng 1 chỗ thì dùng
/// `pickImage` (chọn một): `pickMultiImage(limit: 1)` không hợp lệ ở nhiều
/// bản `image_picker`, còn bỏ `limit` thì cho chọn quá trần. Composer vẫn tự
/// cắt vì có trình chọn bỏ qua `limit`.
Future<List<PendingAttachment>> pickInboxImages(
  ImagePicker picker,
  int remaining,
  OutboundCapabilities? capabilities,
) async {
  if (remaining <= 0) return const [];
  final options = inboxImagePickOptions(capabilities);
  try {
    if (remaining == 1) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: options.quality,
        maxWidth: options.maxDimension,
        maxHeight: options.maxDimension,
      );
      return one == null ? const [] : [await _imageFrom(one)];
    }
    final picked = await picker.pickMultiImage(
      imageQuality: options.quality,
      maxWidth: options.maxDimension,
      maxHeight: options.maxDimension,
      limit: remaining,
    );
    return [for (final x in picked) await _imageFrom(x)];
  } on PlatformException {
    throw const PickerUnavailable(
      'Không mở được thư viện ảnh — kiểm tra quyền truy cập ảnh trong Cài đặt.',
    );
  }
}

/// Chụp một ảnh bằng máy ảnh.
Future<PendingAttachment?> takeInboxPhoto(
  ImagePicker picker,
  OutboundCapabilities? capabilities,
) async {
  final options = inboxImagePickOptions(capabilities);
  try {
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: options.quality,
      maxWidth: options.maxDimension,
      maxHeight: options.maxDimension,
    );
    return x == null ? null : await _imageFrom(x);
  } on PlatformException {
    throw const PickerUnavailable(
      'Không mở được máy ảnh — kiểm tra quyền máy ảnh trong Cài đặt.',
    );
  }
}

/// Tài liệu qua `file_picker` (SAF trên Android, UIDocumentPicker trên iOS —
/// không cần quyền bộ nhớ). Tệp không có đường dẫn (nhà cung cấp ảo) bị bỏ.
/// [pick] thay trình chọn thật trong test.
Future<List<PendingAttachment>> pickInboxFiles({
  Future<FilePickerResult?> Function()? pick,
}) async {
  final FilePickerResult? result;
  try {
    result =
        await (pick ??
            () => FilePicker.pickFiles(
              allowMultiple: true,
              type: FileType.custom,
              allowedExtensions: kInboxFileExtensions,
            ))();
  } on PlatformException {
    throw const PickerUnavailable(
      'Không mở được trình chọn tệp. Vui lòng thử lại.',
    );
  }
  if (result == null) return const [];
  return [
    for (final f in result.files)
      if (f.path != null)
        PendingAttachment(
          path: f.path!,
          name: f.name,
          size: f.size,
          kind: PendingKind.file,
        ),
  ];
}

Future<PendingAttachment> _imageFrom(XFile x) async {
  int? size;
  try {
    size = await x.length();
  } on Object {
    size = null; // không đọc được cỡ: để upload báo lỗi nếu có
  }
  return PendingAttachment(
    path: x.path,
    name: x.name,
    size: size,
    kind: PendingKind.image,
  );
}
