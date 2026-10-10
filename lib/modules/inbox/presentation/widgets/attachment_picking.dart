import '../../domain/outbound_capabilities.dart';

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
/// trần 1MB. Không đảm bảo tuyệt đối — composer vẫn đo cỡ thật sau khi chọn và
/// báo trước nếu ảnh vẫn vượt (server cũng nén thêm ở `POST /inbox/media`).
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
