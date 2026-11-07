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

    Widget field(TextEditingController c, {List<String>? hints}) => TextField(
      controller: c,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: hints,
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Đổi mật khẩu',
                      style: OmniType.title.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  icon: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
            OmniField(
              label: 'Mật khẩu hiện tại',
              hint: 'Bỏ trống nếu bạn chỉ đăng nhập bằng Google.',
              error: _currentError,
              child: field(_current, hints: const [AutofillHints.password]),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Mật khẩu mới',
              required: true,
              child: field(_next, hints: const [AutofillHints.newPassword]),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Nhập lại mật khẩu mới',
              required: true,
              error: _nextError,
              child: field(_again, hints: const [AutofillHints.newPassword]),
            ),
            if (_formError != null) ...[
              const SizedBox(height: OmniSpacing.md),
              Text(
                _formError!,
                style: OmniType.caption.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: OmniSpacing.lg),
            OutlinedButton(
              onPressed: _ready && !_busy ? _save : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(
                  color: _ready ? scheme.primary : scheme.outlineVariant,
                  width: 1.5,
                ),
                shape: const StadiumBorder(),
                textStyle: OmniType.bodyStrong,
              ),
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
          ],
        ),
      ),
    );
  }
}
