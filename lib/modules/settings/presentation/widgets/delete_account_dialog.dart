import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';

/// Hỏi mật khẩu + xác nhận rồi gửi yêu cầu xóa tài khoản (bắt buộc bởi cửa
/// hàng ứng dụng). Sau khi server nhận, phiên bị xóa và router đưa về đăng nhập.
///
/// Container và messenger bắt TRƯỚC `await`: khi xóa thành công phiên đổi sang
/// chưa đăng nhập, màn gọi bị gỡ khỏi cây — `context`/`ref` của nó không còn
/// dùng được nữa.
Future<void> requestAccountDeletion(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const DeleteAccountDialog(),
  );
  if (password == null) return;

  try {
    await container
        .read(sessionControllerProvider.notifier)
        .requestAccountDeletion(password: password);
  } on AppException catch (error) {
    // `ValidationException` (sai mật khẩu…) là con của `AppException`.
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _confirmed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Không dùng showOmniConfirm: hộp thoại này có ô mật khẩu và một ô tick
    // xác nhận, tức là một biểu mẫu chứ không phải câu hỏi có/không. Đây cũng
    // đúng là chỗ nên bắt người dùng chậm lại — xoá tài khoản không được dễ
    // như bấm "Đồng ý".
    return AlertDialog(
      title: const Text('Xóa tài khoản?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản sẽ bị vô hiệu hóa ngay. Yêu cầu xóa tài khoản và dữ liệu cá nhân sẽ được hoàn tất trong vòng 7 ngày.',
            ),
            const SizedBox(height: OmniSpacing.lg),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                suffixIcon: IconButton(
                  // Nhãn nói cả trạng thái — xem login_page.dart.
                  tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: OmniSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi hiểu đây là yêu cầu xóa toàn bộ tài khoản, không phải tạm khóa.',
              ),
              onChanged: (value) => setState(() {
                _confirmed = value ?? false;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _confirmed && _password.text.isNotEmpty
              ? () => Navigator.pop(context, _password.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Xác nhận xóa'),
        ),
      ],
    );
  }
}
