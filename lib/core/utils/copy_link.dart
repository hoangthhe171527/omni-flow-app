import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chép [link] vào bộ nhớ tạm rồi báo bằng [messenger]. Người gọi lấy
/// `ScaffoldMessenger` TRƯỚC khi await (sheet đã đóng, context có thể đã
/// gỡ). Bộ nhớ tạm lỗi (nền tảng từ chối) thì báo không chép được, không
/// ném ra ngoài.
Future<void> copyLinkToClipboard(
  ScaffoldMessengerState messenger,
  String link,
) async {
  try {
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã sao chép liên kết.')),
    );
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(content: Text('Không sao chép được liên kết.')),
    );
  }
}
