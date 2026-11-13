import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/nav/account_extras_slot.dart';
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
      appBar: OmniAppBar(
        title: 'Tài khoản',
        centerTitle: true,
        showAccount: false,
        fallbackBack: () => context.go('/more'),
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
              const SizedBox(height: OmniGroupSection.gap),
              _Rise(delay: 50, child: _buildOrganizationGroup()),
              const SizedBox(height: OmniGroupSection.gap),
              _Rise(
                delay: 100,
                child: OmniGroupSection(
                  title: 'Bảo mật',
                  children: [
                    OmniGroupRow(
                      icon: Icons.key_outlined,
                      title: 'Đổi mật khẩu',
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              // Khung ứng dụng: Cài đặt ứng dụng, Trợ giúp (không còn "Tất cả").
              if (AccountExtrasSlot.maybeOf(context) case final extras?) ...[
                const SizedBox(height: OmniGroupSection.gap),
                _Rise(delay: 125, child: extras(context)),
              ],
              const SizedBox(height: 18),
              _Rise(
                delay: 150,
                child: OmniGroupSection(
                  children: [
                    OmniGroupRow(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      destructive: true,
                      onTap: _confirmLogout,
                    ),
                    OmniGroupRow(
                      icon: Icons.delete_outline_rounded,
                      title: 'Xoá tài khoản',
                      destructive: true,
                      onTap: () => requestAccountDeletion(context),
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
    final email = ref.watch(sessionProvider.select((s) => s.user?.email));
    final avatarUrl = ref.watch(
      sessionProvider.select((s) => s.user?.avatarUrl),
    );
    final roleLabel = ref.watch(sessionProvider.select((s) => s.roleLabel));
    final secondary = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : roleLabel;

    return OmniCard(
      flat: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      badge: const _CameraBadge(),
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
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          ExcludeSemantics(
            child: _GlassActionPill(
              icon: Icons.photo_camera_outlined,
              label: 'Ảnh',
              onTap: _busy ? null : () => _openAvatarMenu(avatarUrl),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationGroup() {
    final roleLabel = ref.watch(sessionProvider.select((s) => s.roleLabel));
    final tenantName = ref.watch(sessionProvider.select((s) => s.tenant?.name));
    final canSwitch =
        (ref.watch(tenantOptionsProvider).valueOrNull?.length ?? 0) > 1;

    void switchWorkspace() {
      HapticFeedback.selectionClick();
      // Danh sách có thể đã cũ (vừa được thêm vào một công ty mới).
      ref.invalidate(tenantOptionsProvider);
      ref.read(sessionControllerProvider.notifier).chooseWorkspace();
    }

    return OmniGroupSection(
      title: 'Tổ chức hiện tại',
      children: [
        OmniGroupRow(
          icon: Icons.apartment_rounded,
          title: (tenantName != null && tenantName.isNotEmpty)
              ? tenantName
              : 'Tổ chức',
          subtitle: roleLabel.isNotEmpty ? roleLabel : null,
          chevron: false,
          trailing: canSwitch
              ? Semantics(
                  button: true,
                  container: true,
                  label: 'Đổi không gian làm việc',
                  excludeSemantics: true,
                  onTap: switchWorkspace,
                  child: _GlassActionPill(label: 'Đổi', onTap: switchWorkspace),
                )
              : null,
        ),
        OmniGroupRow(
          icon: Icons.shield_outlined,
          title: 'Quyền của tôi',
          onTap: () => context.pushNamed(SettingsModule.myPermissions),
        ),
      ],
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

class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(Icons.photo_camera_rounded, size: 11, color: scheme.primary),
    );
  }
}

class _GlassActionPill extends StatelessWidget {
  const _GlassActionPill({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: DecoratedBox(
            decoration: OmniGlass.buttonDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: scheme.primary),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
