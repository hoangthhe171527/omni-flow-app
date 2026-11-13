import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';

/// Hỏi mật khẩu + xác nhận rồi gửi yêu cầu xoá tài khoản (bắt buộc bởi cửa
/// hàng ứng dụng). Sau khi server nhận, phiên bị xoá và router đưa về đăng nhập.
///
/// Container và messenger bắt TRƯỚC `await`: khi xoá thành công phiên đổi sang
/// chưa đăng nhập, màn gọi bị gỡ khỏi cây — `context`/`ref` của nó không còn
/// dùng được nữa.
Future<void> requestAccountDeletion(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final password = await showOmniGlassDialog<String>(
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
    // Không dùng showOmniConfirm: hộp thoại này có ô mật khẩu và một ô đánh
    // dấu xác nhận, tức là một biểu mẫu chứ không phải câu hỏi có/không. Đây
    // cũng đúng là chỗ nên bắt người dùng chậm lại — xoá tài khoản không được
    // dễ như bấm "Đồng ý".
    final scheme = Theme.of(context).colorScheme;
    final ready = _confirmed && _password.text.isNotEmpty;

    return OmniGlassAlert(
      title: 'Xoá tài khoản?',
      message:
          'Tài khoản sẽ bị vô hiệu hoá ngay. Yêu cầu xoá tài khoản và dữ liệu cá nhân sẽ được hoàn tất trong vòng 7 ngày.',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
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
          Semantics(
            checked: _confirmed,
            inMutuallyExclusiveGroup: false,
            child: InkWell(
              key: const Key('delete-account-confirm'),
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _confirmed = !_confirmed);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _confirmed
                              ? OmniGlass.selectionOf(context)
                              : Colors.transparent,
                          border: Border.all(
                            color: _confirmed ? scheme.primary : scheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: _confirmed
                            ? Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: scheme.primary,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tôi hiểu đây là yêu cầu xoá toàn bộ tài khoản, không phải tạm khoá.',
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        OmniAlertAction(label: 'Huỷ', onPressed: () => Navigator.pop(context)),
        OmniAlertAction(
          key: const Key('delete-account-submit'),
          label: 'Xác nhận xoá',
          destructive: true,
          onPressed: ready
              ? () => Navigator.pop(context, _password.text)
              : null,
        ),
      ],
    );
  }
}
