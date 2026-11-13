import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../data/password_api.dart';

/// Tấm đổi mật khẩu (`tat-ca-tai-khoan-uiux.html`, tab Tài khoản). Trả về
/// true khi đã đổi.
Future<bool?> showChangePasswordSheet(BuildContext context) =>
    showOmniSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const ChangePasswordSheet(),
    );

/// Tối thiểu của server (`ChangeOwnPasswordRequest`).
const passwordMinLength = 8;

class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _currentError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _next.addListener(_refresh);
    _again.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  String? get _nextError {
    final next = _next.text;
    if (next.isNotEmpty && next.length < passwordMinLength) {
      return 'Tối thiểu $passwordMinLength ký tự.';
    }
    if (_again.text.isNotEmpty && _again.text != next) {
      return 'Hai mật khẩu chưa khớp.';
    }
    return null;
  }

  bool get _ready =>
      _next.text.length >= passwordMinLength && _again.text == _next.text;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _currentError = null;
      _formError = null;
    });
    try {
      await ref
          .read(passwordApiProvider)
          .change(current: _current.text, next: _next.text);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      // 422: sai mật khẩu hiện tại (lời của server) hoặc lỗi theo trường.
      _currentError = error.firstFor('current_password') ?? error.message;
    } on AppException catch (error) {
      _formError = failureText(
        error,
        'Chưa lưu được. Kiểm tra mạng rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget rowField({
      required String label,
      required TextEditingController controller,
      required String hintText,
      List<String>? autofillHints,
      bool required = false,
      String? error,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (required)
                  Text(
                    ' *',
                    style: OmniType.caption.copyWith(color: scheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            TextField(
              controller: controller,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: autofillHints,
              style: OmniType.body.copyWith(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: OmniIconSize.xs,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      error,
                      style: OmniType.micro.copyWith(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Đổi mật khẩu',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OmniGlassCircle(
              child: IconButton(
                tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: OmniIconSize.md,
                  color: scheme.onSurface,
                ),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            const SizedBox(width: 8),
            OmniGlassCircle(
              child: IconButton(
                tooltip: 'Đóng',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: OmniIconSize.md,
                  color: scheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
      footer: OutlinedButton(
        onPressed: _ready && !_busy ? _save : null,
        child: _busy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : const Text('Lưu mật khẩu mới'),
      ),
      children: [
        OmniGroupSection(
          title: 'Bảo mật đăng nhập',
          dividerIndent: 14,
          footer:
              'Bỏ trống mật khẩu hiện tại nếu bạn chỉ đăng nhập bằng Google.',
          children: [
            rowField(
              label: 'Mật khẩu hiện tại',
              controller: _current,
              hintText: 'Nhập mật khẩu hiện tại',
              autofillHints: const [AutofillHints.password],
              error: _currentError,
            ),
            rowField(
              label: 'Mật khẩu mới',
              controller: _next,
              hintText: 'Ít nhất 8 ký tự',
              required: true,
              autofillHints: const [AutofillHints.newPassword],
            ),
            rowField(
              label: 'Nhập lại mật khẩu mới',
              controller: _again,
              hintText: 'Nhập khớp mật khẩu mới',
              required: true,
              autofillHints: const [AutofillHints.newPassword],
              error: _nextError,
            ),
          ],
        ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formError!,
              style: OmniType.caption.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
