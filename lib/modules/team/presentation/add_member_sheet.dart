import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/team_providers.dart';
import '../data/team_api.dart';
import '../domain/new_member.dart';

/// Mở tấm "Thêm nhân viên" (`them-nhan-vien-uiux.html`, duyệt 07/11).
Future<void> showAddMemberSheet(BuildContext context) => showOmniSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (_) => const AddMemberSheet(),
);

enum _Mode { create, invite }

/// Hai cách thêm người: **Tạo tài khoản** (mặc định — cấp mật khẩu tạm tại
/// xưởng, đăng nhập được ngay) và **Mời qua email** (như nút Mời trên web).
/// Xong thì hiện thông tin đăng nhập để sao chép gửi qua Zalo.
class AddMemberSheet extends ConsumerStatefulWidget {
  const AddMemberSheet({super.key});

  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: generateTempPassword());

  _Mode _mode = _Mode.create;
  String _role = defaultRoleSlug;
  bool _busy = false;
  String? _nameError;
  String? _emailError;
  String? _formError;

  /// Sau khi gửi thành công: thông tin để hiện ở màn "xong".
  ({String email, String? password, String role, bool invited})? _done;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String _roleLabel(List<RoleOption> roles) {
    for (final r in roles) {
      if (r.slug == _role) return r.label;
    }
    return 'Thợ';
  }

  Future<void> _submit(List<RoleOption> roles) async {
    final email = _email.text.trim();
    final name = _name.text.trim();
    setState(() {
      _formError = null;
      _emailError = _emailPattern.hasMatch(email) ? null : 'Email chưa đúng.';
      _nameError = _mode == _Mode.create && name.isEmpty
          ? 'Nhập họ tên.'
          : null;
    });
    if (_emailError != null || _nameError != null) return;

    setState(() => _busy = true);
    final api = ref.read(teamApiProvider);
    try {
      if (_mode == _Mode.create) {
        final added = await api.addUser(
          email: email,
          fullName: name,
          phone: _phone.text.trim(),
          password: _password.text,
          roleSlug: roles.isEmpty ? null : _role,
        );
        _done = (
          email: email,
          password: added.userCreated ? _password.text : null,
          role: _roleLabel(roles),
          invited: false,
        );
      } else {
        await api.invite(email);
        _done = (email: email, password: null, role: 'Thợ', invited: true);
      }
      HapticFeedback.mediumImpact();
      ref.invalidate(teamDirectoryProvider);
    } on ValidationException catch (error) {
      _emailError = error.firstFor('email');
      _nameError = error.firstFor('full_name');
      _formError = (_emailError == null && _nameError == null)
          ? error.message
          : null;
    } on AppException catch (error) {
      // 409 "đã là thành viên" và các lời khác của server: nói ra, không đóng.
      _formError = failureText(
        error,
        'Chưa gửi được. Kiểm tra mạng rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = ref.watch(assignableRolesProvider).valueOrNull ?? const [];
    final done = _done;
    final create = _mode == _Mode.create;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: done == null ? 'Thêm nhân viên' : 'Hoàn tất',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(
              Icons.close_rounded,
              size: OmniIconSize.md,
              color: scheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      footer: done == null
          ? _OutlineButton(
              label: create ? 'Tạo tài khoản' : 'Gửi lời mời',
              busy: _busy,
              onPressed: _busy ? null : () => _submit(roles),
            )
          : _doneFooter(done),
      children: done == null
          ? _formChildren(context, roles)
          : _successChildren(done),
    );
  }

  Widget _inlineField({
    required BuildContext context,
    required String label,
    required Widget child,
    bool required = false,
    String? hint,
    String? error,
  }) {
    final scheme = Theme.of(context).colorScheme;
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
          child,
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
          ] else if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  static const _borderlessDecoration = InputDecoration(
    isDense: true,
    filled: false,
    contentPadding: EdgeInsets.symmetric(vertical: 4),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );

  List<Widget> _formChildren(BuildContext context, List<RoleOption> roles) {
    final scheme = Theme.of(context).colorScheme;
    final create = _mode == _Mode.create;

    return [
      OmniSegmented(
        labels: const ['Tạo tài khoản', 'Mời qua email'],
        index: create ? 0 : 1,
        onChanged: (i) => setState(() {
          _mode = i == 0 ? _Mode.create : _Mode.invite;
          _formError = null;
        }),
      ),
      OmniGroupSection(
        title: create ? 'Thông tin tài khoản' : 'Lời mời qua email',
        dividerIndent: 14,
        children: [
          if (create) ...[
            _inlineField(
              context: context,
              label: 'Họ tên',
              required: true,
              error: _nameError,
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                style: OmniType.body.copyWith(color: scheme.onSurface),
                decoration: _borderlessDecoration.copyWith(
                  hintText: 'Nguyễn Văn A',
                ),
              ),
            ),
            _inlineField(
              context: context,
              label: 'Số điện thoại',
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                style: OmniType.body.copyWith(
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: _borderlessDecoration.copyWith(
                  hintText: '0912 345 678',
                ),
              ),
            ),
          ],
          _inlineField(
            context: context,
            label: 'Email đăng nhập',
            required: true,
            error: _emailError,
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: OmniType.body.copyWith(color: scheme.onSurface),
              decoration: _borderlessDecoration.copyWith(
                hintText: 'ten@congty.vn',
              ),
            ),
          ),
          if (create)
            _inlineField(
              context: context,
              label: 'Mật khẩu tạm',
              hint: 'Đưa cho nhân viên; họ đổi sau khi đăng nhập.',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _password,
                      autocorrect: false,
                      style: OmniType.bodyStrong.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: _borderlessDecoration,
                    ),
                  ),
                  OmniGlassCircle(
                    child: IconButton(
                      tooltip: 'Tạo mật khẩu khác',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: OmniIconSize.sm,
                        color: scheme.onSurface,
                      ),
                      onPressed: () => setState(
                        () => _password.text = generateTempPassword(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (create && roles.isNotEmpty)
        OmniGroupSection(
          title: 'Vai trò',
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                children: [
                  for (final r in roles)
                    OmniChoicePill(
                      label: r.label,
                      selected: _role == r.slug,
                      onTap: () => setState(() => _role = r.slug),
                    ),
                ],
              ),
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
    ];
  }

  Widget _doneFooter(
    ({String email, String? password, String role, bool invited}) done,
  ) {
    final credentials = done.password == null
        ? null
        : 'Viomni\nEmail: ${done.email}\nMật khẩu: ${done.password}';
    return Row(
      children: [
        if (credentials != null) ...[
          Expanded(
            child: _OutlineButton(
              label: 'Sao chép',
              icon: Icons.content_copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: credentials));
                if (!mounted) return;
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(const SnackBar(content: Text('Đã sao chép.')));
              },
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
        ],
        Expanded(
          child: _OutlineButton(
            label: 'Xong',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  List<Widget> _successChildren(
    ({String email, String? password, String role, bool invited}) done,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final message = done.invited
        ? '${done.email} sẽ nhận email để tự đặt mật khẩu.'
        : done.password == null
        ? 'Email này đã có tài khoản Viomni. Họ đăng nhập bằng mật khẩu cũ.'
        : 'Gửi thông tin này cho nhân viên.';

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: OmniType.bodyStrong.copyWith(
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    return [
      OmniGroupSection(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    done.invited
                        ? Icons.mark_email_read_outlined
                        : Icons.check_circle_rounded,
                    size: OmniIconSize.lg,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                Text(
                  done.invited ? 'Đã gửi lời mời' : 'Đã thêm nhân viên',
                  textAlign: TextAlign.center,
                  style: OmniType.title.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      if (!done.invited)
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            line('Email', done.email),
            if (done.password case final pw?) line('Mật khẩu tạm', pw),
            line('Vai trò', done.role),
          ],
        ),
    ];
  }
}

/// Nút viền kính (theme `OutlinedButton`), cao 48.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final child = busy
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: primary),
          )
        : Text(label);

    return icon == null
        ? OutlinedButton(onPressed: onPressed, child: child)
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: child,
          );
  }
}
