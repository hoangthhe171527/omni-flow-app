import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../auth/application/login_controller.dart';
import '../data/avatar_api.dart';
import '../settings_module.dart';
import 'change_password_sheet.dart';
import 'widgets/delete_account_dialog.dart';

/// Màn Tài khoản — mở khi bấm avatar (`tat-ca-tai-khoan-uiux.html`, duyệt
/// 07/11): CHỈ việc của tài khoản — hồ sơ (ảnh, tên, vai trò · workspace, đổi
/// workspace), bảo mật (đổi mật khẩu), quyền của tôi, đăng xuất, xoá tài khoản.
///
/// Thông báo, nền, giao diện, hỗ trợ, quyền riêng tư đã chuyển về "Tất cả";
/// Đội nhóm, Kênh kết nối vốn có ô ở "Tất cả".
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

enum _AvatarAction { change, remove }

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _busy = false;
  final _avatarButtonKey = GlobalKey(debugLabel: 'AccountProfileAvatar');

  Future<void> _changePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showChangePasswordSheet(context);
    if (changed == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Nền xám để các thẻ nhóm lồng nổi lên.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniAppBar(
        title: 'Tài khoản',
        centerTitle: true,
        showAccount: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              14,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            children: [
              _Rise(delay: 0, child: _buildProfile(scheme)),
              const SizedBox(height: 14),
              _Rise(
                delay: 50,
                child: _Section(
                  title: 'Bảo mật',
                  children: [
                    _AccountRow(
                      icon: Icons.key_outlined,
                      label: 'Đổi mật khẩu',
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Rise(
                delay: 100,
                child: _Section(
                  title: 'Không gian làm việc',
                  children: [
                    _AccountRow(
                      icon: Icons.shield_outlined,
                      label: 'Quyền của tôi',
                      onTap: () =>
                          context.pushNamed(SettingsModule.myPermissions),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Rise(
                delay: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LogoutButton(onPressed: _confirmLogout),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () => requestAccountDeletion(context),
                        child: const Text('Xoá tài khoản'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(ColorScheme scheme) {
    final displayName = ref.watch(sessionProvider.select((s) => s.displayName));
    final avatarUrl = ref.watch(
      sessionProvider.select((s) => s.user?.avatarUrl),
    );
    final roleLabel = ref.watch(sessionProvider.select((s) => s.roleLabel));
    final tenantName = ref.watch(sessionProvider.select((s) => s.tenant?.name));
    final canSwitch =
        (ref.watch(tenantOptionsProvider).valueOrNull?.length ?? 0) > 1;
    final subtitle = [
      roleLabel,
      ?tenantName,
    ].where((p) => p.isNotEmpty).join(' · ');

    return _Card(
      padding: const EdgeInsets.all(OmniSpacing.md),
      child: Row(
        children: [
          Semantics(
            button: true,
            container: true,
            label: 'Tuỳ chọn ảnh đại diện',
            excludeSemantics: true,
            onTap: _busy ? null : () => _openAvatarMenu(avatarUrl),
            child: InkResponse(
              onTap: _busy ? null : () => _openAvatarMenu(avatarUrl),
              radius: 28,
              child: SizedBox.square(
                key: _avatarButtonKey,
                dimension: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    OmniAvatar(
                      name: displayName.isEmpty ? 'Tài khoản' : displayName,
                      imageUrl: avatarUrl,
                      size: 48,
                    ),
                    // Vành tiến độ trong lúc tải lên; ảnh cũ VẪN hiện bên dưới.
                    if (_busy)
                      const SizedBox.square(
                        dimension: 48,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.section.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canSwitch) ...[
            const SizedBox(width: OmniSpacing.sm),
            _SwitchWorkspaceButton(
              onTap: () {
                HapticFeedback.selectionClick();
                // Danh sách có thể đã cũ (vừa được thêm vào một công ty mới).
                ref.invalidate(tenantOptionsProvider);
                ref.read(sessionControllerProvider.notifier).chooseWorkspace();
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAvatarMenu(String? avatarUrl) async {
    HapticFeedback.selectionClick();
    final box =
        _avatarButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final action = await showOmniAnchoredMenu<_AvatarAction>(
      context: context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      width: 236,
      menuKey: const Key('profile-avatar-menu'),
      semanticsLabel: 'Tuỳ chọn ảnh đại diện',
      builder: (menuContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OmniAnchoredMenuItem(
            icon: Icons.photo_library_outlined,
            label: 'Đổi ảnh',
            onTap: () => Navigator.of(menuContext).pop(_AvatarAction.change),
          ),
          if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
            OmniAnchoredMenuItem(
              icon: Icons.delete_outline_rounded,
              label: 'Xoá ảnh',
              divider: true,
              destructive: true,
              onTap: () => Navigator.of(menuContext).pop(_AvatarAction.remove),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AvatarAction.change:
        await _pickAndUpload();
      case _AvatarAction.remove:
        await _removeAvatar();
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá ảnh đại diện?',
      message: 'Viomni sẽ dùng chữ cái tên của bạn thay cho ảnh.',
      confirmLabel: 'Xoá ảnh',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(avatarApiProvider).remove();
      await ref.read(sessionControllerProvider.notifier).refreshContext();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa xoá được ảnh đại diện.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      // Nén ở CLIENT trước khi gửi. Một ảnh 12MB từ camera điện thoại sẽ bị API
      // từ chối ở trần 5MB, và "tệp quá lớn" là một cách tệ để nói "máy bạn chụp
      // ảnh to quá". Cùng tham số `thread_page.dart` và `task_detail_page.dart`
      // đang dùng.
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;

      setState(() => _busy = true);
      await ref.read(avatarApiProvider).upload(picked.path);
      // Đọc lại phiên thay vì tự vá URL vào: server là nơi biết URL cuối cùng,
      // và một bản sao ở client sẽ lệch ngay lần đầu server đổi cách sinh URL.
      await ref.read(sessionControllerProvider.notifier).refreshContext();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không mở được thư viện ảnh. Vui lòng thử lại.'),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa cập nhật được ảnh đại diện. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    final container = ProviderScope.containerOf(context);
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập lại để tiếp tục làm việc.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (confirmed) {
      await container.read(sessionControllerProvider.notifier).logout();
    }
  }
}

/// `rise`: hiện dần và trượt lên 10px, trễ [delay] ms. Tắt khi giảm chuyển động.
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});

  final int delay;
  final Widget child;

  static const _duration = 450;

  @override
  Widget build(BuildContext context) {
    // Bậc hiệu năng thấp: hiện ngay (mỗi mục hiện dần = một lớp vẽ mờ).
    if (!OmniMotion.enabled(context) ||
        !OmniPerformance.riseOnScroll(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: _duration + delay),
      curve: Interval(
        delay / (_duration + delay),
        1,
        curve: OmniCurves.standard,
      ),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Mặt phẳng nội dung. Các nhóm cấp trang dùng khoảng cách + divider thay vì
/// khung bo quanh toàn bộ nội dung.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Thẻ nhóm lồng bo 18 trên nền xám (viomni-apple-uiux.html `.group`).
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Nhãn nhóm + thẻ chứa các dòng, vạch ngăn giữa chúng. Nhóm rỗng không vẽ.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.xs,
            0,
            OmniSpacing.xs,
            6,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Một dòng: ô icon 28, nhãn, giá trị phụ, mũi tên. Dòng nguy hiểm tô đỏ và
/// không có mũi tên.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
          child: Row(
            children: [
              if (icon != null) ...[_IconTile(icon), const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  label,
                  style: OmniType.chip.copyWith(
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: OmniTaskTones.of(context).chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: scheme.onSurface),
    );
  }
}

class _SwitchWorkspaceButton extends StatelessWidget {
  const _SwitchWorkspaceButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      container: true,
      label: 'Đổi không gian làm việc',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                'Đổi',
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: OmniColors.dangerTextOf(context),
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
        textStyle: OmniType.chip.copyWith(fontWeight: FontWeight.w600),
      ),
      child: const Text('Đăng xuất'),
    );
  }
}
