import 'dart:convert';
import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Lưu QR (data URL base64) vào thư viện ảnh, để có thể quét từ chính máy đó.
Future<void> saveQrToGallery(String dataUrl) async {
  final Uint8List bytes;
  try {
    final payload = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    bytes = base64Decode(payload);
  } catch (_) {
    throw Exception('Ảnh QR hỏng, thử lấy mã mới.');
  }

  try {
    await Gal.putImageBytes(bytes, name: 'viomni-qr');
  } on GalException catch (error) {
    throw Exception(switch (error.type) {
      GalExceptionType.accessDenied =>
        'Chưa cho phép lưu ảnh. Mở Cài đặt → Quyền để bật.',
      _ => 'Không lưu được ảnh QR.',
    });
  }
}
