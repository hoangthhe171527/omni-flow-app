import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

import 'web_url.dart';

/// Lỗi lưu ảnh đã viết sẵn thành câu cho người dùng.
class SaveImageException implements Exception {
  const SaveImageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Tải ảnh (chỉ http/https) rồi lưu vào thư viện ảnh của máy — nút "Lưu ảnh" của khung xem ảnh.
Future<void> saveNetworkImageToGallery(String url, {String? name}) async {
  final uri = webUriOrNull(url);
  if (uri == null) throw const SaveImageException('Ảnh này không lưu được.');
  final Uint8List bytes;
  try {
    final res = await Dio().getUri<List<int>>(
      uri,
      options: Options(responseType: ResponseType.bytes),
    );
    bytes = Uint8List.fromList(res.data ?? const []);
  } catch (_) {
    throw const SaveImageException(
      'Không tải được ảnh. Kiểm tra mạng rồi thử lại.',
    );
  }
  if (bytes.isEmpty) throw const SaveImageException('Không tải được ảnh.');
  try {
    await Gal.putImageBytes(bytes, name: name ?? 'viomni-anh');
  } on GalException catch (error) {
    throw SaveImageException(switch (error.type) {
      GalExceptionType.accessDenied =>
        'Chưa cho phép lưu ảnh. Mở Cài đặt › Quyền để bật.',
      _ => 'Không lưu được ảnh.',
    });
  }
}
