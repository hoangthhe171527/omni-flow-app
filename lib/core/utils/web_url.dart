/// URL được phép trao cho hệ điều hành mở (`launchUrl`) khi nó đến từ dữ liệu
/// người khác soạn — tệp đính kèm khách gửi, link trong tin, URL API trả về.
///
/// Chỉ `http`/`https` có host. Scheme khác (`file:`, `search-ms:`, `ms-*:`,
/// `intent:`, scheme của app khác) là lệnh cho hệ điều hành, không phải trang
/// web: trên Windows `ShellExecute` mở thẳng `file:`; trên Android `intent:`
/// gọi được activity khác. Một chạm vào "invoice.pdf" không được thành chạy
/// một chương trình.
Uri? webUriOrNull(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}
