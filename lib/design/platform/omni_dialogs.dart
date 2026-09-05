import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'omni_platform.dart';

/// Hỏi người dùng một câu có/không.
///
/// Trả về `true` khi người dùng xác nhận. Gạt bỏ hộp thoại — bấm ra ngoài, bấm
/// nút back — trả về `false`, không phải null: với một hành động phá huỷ,
/// "chưa trả lời" mà bị hiểu thành "đồng ý" là xoá nhầm dữ liệu của người ta.
/// Kiểu trả về không cho phép chỗ gọi mắc lỗi đó.
Future<bool> showOmniConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Huỷ',
  bool destructive = false,
}) async {
  final answer = isApple(context)
      ? await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                // Trên iOS, hành động phá huỷ KHÔNG được là mặc định: mặc định
                // là cái người dùng bấm khi không đọc kỹ.
                isDefaultAction: !destructive,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        );

  return answer ?? false;
}
