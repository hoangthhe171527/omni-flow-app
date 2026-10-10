import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/guard/access_requirement.dart';
import '../../../security/session/session_controller.dart';
import '../../auth/application/login_controller.dart';
import '../../channels/application/channels_providers.dart';
import '../../channels/channels_module.dart';
import '../../channels/domain/channel_permissions.dart';
import '../../team/team.dart';
import '../../team/team_module.dart';
import '../data/avatar_api.dart';
import '../settings_module.dart';
import 'widgets/delete_account_dialog.dart';

/// Màn Tài khoản (`Me.dc.html`): hồ sơ, đổi không gian, lối tắt làm việc, ứng
/// dụng (thông báo, nền, giao diện), hỗ trợ, xóa tài khoản, đăng xuất.
///
/// Gộp mọi việc từng nằm trong menu avatar cũ (đổi ảnh, nền, thông báo, quyền,
/// đăng xuất) và danh bạ "Tất cả" (đổi không gian, giao diện, chính sách, hỗ
/// trợ, xóa tài khoản). Dòng nào cần quyền thì ẩn khi thiếu quyền.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _busy = false;

  static const _themeModes = [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final policy = ref.watch(sessionProvider.select((s) => s.policy));
    final channelsOn = ref.watch(
      sessionProvider.select((s) => s.featureEnabled('channels')),
    );
    final themeMode = ref.watch(themeModeProvider);

    final canSeeTeam = const AccessRequirement.any([
      TeamPermissions.membersRead,
    ]).isSatisfiedBy(policy);
    final canSeeChannels =
        channelsOn &&
        const AccessRequirement.any(
          ChannelPermissions.anyRead,
        ).isSatisfiedBy(policy);

    final workRows = <Widget>[
      if (canSeeTeam) const _TeamRow(),
      if (canSeeChannels) const _ChannelsRow(),
      _AccountRow(
        icon: Icons.shield_outlined,
        label: 'Quyền của tôi',
        onTap: () => context.pushNamed(SettingsModule.myPermissions),
      ),
    ];

    return Scaffold(
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
                child: _Section(title: 'Làm việc', children: workRows),
              ),
              const SizedBox(height: 14),
              _Rise(
                delay: 100,
                child: _Section(
                  title: 'Ứng dụng',
                  children: [
                    _AccountRow(
                      icon: Icons.notifications_outlined,
                      label: 'Thông báo',
                      onTap: () =>
                          context.pushNamed(SettingsModule.notifications),
                    ),
                    _AccountRow(
                      icon: Icons.wallpaper_outlined,
                      label: 'Nền',
                      onTap: () => context.pushNamed(SettingsModule.background),
                    ),
                    _ThemeRow(
                      index: _themeModes.indexOf(themeMode),
                      onChanged: (i) => ref
                          .read(themeModeProvider.notifier)
                          .set(_themeModes[i]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Rise(
                delay: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'Hỗ trợ',
                      children: [
                        _AccountRow(
                          label: 'Trung tâm hỗ trợ',
                          external: true,
                          onTap: () => _openLink(AppConfig.supportUrl),
                        ),
                        _AccountRow(
                          label: 'Chính sách quyền riêng tư',
                          external: true,
                          onTap: () => _openLink(AppConfig.privacyPolicyUrl),
                        ),
                        _AccountRow(
                          label: 'Xóa tài khoản',
                          destructive: true,
                          onTap: () => requestAccountDeletion(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _LogoutButton(onPressed: _confirmLogout),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Viomni ${AppConfig.appVersion}',
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
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
            label: 'Đổi ảnh đại diện',
            excludeSemantics: true,
            onTap: _busy ? null : _pickAndUpload,
            child: InkResponse(
              onTap: _busy ? null : _pickAndUpload,
              radius: 28,
              child: SizedBox.square(
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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

  Future<void> _pickAndUpload() async {
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
    try {
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLink(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    // `launchUrl` có thể ném PlatformException (không có ứng dụng xử lý, bị
    // chính sách chặn) chứ không chỉ trả false; cả hai đều là "không mở được".
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (opened) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  Future<void> _confirmLogout() async {
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
    if (!OmniMotion.enabled(context)) return child;

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

/// Thẻ bo 8, viền mảnh.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Material chứ không DecoratedBox: dòng bên trong vẽ gợn sóng lên Material
    // gần nhất, và một nền tô giữa hai bên sẽ che mất nó.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
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
  const _AccountRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.value,
    this.destructive = false,
    this.external = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? value;
  final bool destructive;

  /// Mở ra ngoài app (trình duyệt): mũi tên chéo thay cho chevron.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive
        ? OmniColors.dangerTextOf(context)
        : scheme.onSurface;

    return InkWell(
      onTap: onTap,
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
                    fontWeight: destructive ? FontWeight.w600 : FontWeight.w400,
                    color: foreground,
                  ),
                ),
              ),
              ?value,
              if (!destructive) ...[
                const SizedBox(width: 6),
                Icon(
                  external
                      ? Icons.open_in_new_rounded
                      : Icons.chevron_right_rounded,
                  size: 16,
                  // Task 6 thay bằng OmniTaskTones.chevron.
                  color: scheme.outline,
                ),
              ],
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

class _ValueText extends StatelessWidget {
  const _ValueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: OmniType.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 6),
    );
  }
}

class _TeamRow extends ConsumerWidget {
  const _TeamRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamDirectoryProvider).valueOrNull;
    final active = members?.where((m) => m.isActive).length;

    return _AccountRow(
      icon: Icons.group_outlined,
      label: 'Đội nhóm',
      value: active == null ? null : _ValueText('$active người'),
      onTap: () => context.pushNamed(TeamModule.list),
    );
  }
}

class _ChannelsRow extends ConsumerWidget {
  const _ChannelsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final health = ref.watch(channelHealthProvider);

    return _AccountRow(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Kênh kết nối',
      value: health == null
          ? null
          // Chấm màu và số rời nhau không có nghĩa với trình đọc màn hình:
          // gộp thành một câu.
          : Semantics(
              container: true,
              excludeSemantics: true,
              label: '${health.running} chạy, ${health.failing} lỗi',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(scheme.primary),
                  const SizedBox(width: 6),
                  _ValueText('${health.running}'),
                  if (health.failing > 0) ...[
                    const SizedBox(width: 6),
                    const _ValueText('·'),
                    const SizedBox(width: 6),
                    _Dot(scheme.error),
                    const SizedBox(width: 6),
                    _ValueText('${health.failing} lỗi'),
                  ],
                ],
              ),
            ),
      onTap: () => context.pushNamed(ChannelsModule.list),
    );
  }
}

/// Dòng "Giao diện" không bấm; bộ chọn ba ngăn nằm dưới nhãn.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.md,
        10,
        OmniSpacing.md,
        OmniSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconTile(Icons.wb_sunny_outlined),
              const SizedBox(width: 10),
              Text(
                'Giao diện',
                style: OmniType.chip.copyWith(
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OmniSegmented(
            labels: const ['Sáng', 'Tối', 'Theo máy'],
            index: index < 0 ? 2 : index,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Nút "Đổi" vẽ cao 30, vùng chạm 44.
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
    final scheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: OmniColors.dangerTextOf(context),
        backgroundColor: scheme.surface,
        minimumSize: const Size.fromHeight(44),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: OmniType.chip.copyWith(fontWeight: FontWeight.w600),
      ),
      child: const Text('Đăng xuất'),
    );
  }
}
