import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../core/nav/pinned_tabs.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';
import '../../modules/auth/application/login_controller.dart';
import '../../security/session/session_controller.dart';
import '../router/shell_routes.dart';
import 'app_shell.dart';

/// Danh bạ "Tất cả": hồ sơ người dùng, rồi MỌI tính năng họ có quyền dùng,
/// gom theo nhóm và tìm được bằng từ khoá.
///
/// Không có gì viết cứng theo module — module khai báo mục, registry lọc theo
/// quyền, màn này dựng bất cứ thứ gì nhận được. Một module ra mắt ngày mai xuất
/// hiện ở đây mà file này không đổi một dòng.
///
/// Bố cục theo `MDirectory.dc.html`: thẻ hồ sơ nền mực, thẻ không gian làm
/// việc, ô tìm, lưới ô tính năng theo nhóm, rồi "Cá nhân", "Pháp lý & hỗ trợ"
/// và nút đăng xuất.
class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final groups = _filtered(ref.watch(directoryGroupsProvider), _query);
    final tabCount = ref
        .watch(tabEntriesProvider)
        .take(AppShell.maxTabs)
        .length;
    final accountEntries = groups[NavArea.account] ?? const <ModuleNavEntry>[];

    // Hai dòng cố định của "Cá nhân" cũng tìm được, như mọi mục khác.
    final showTheme = matchesQuery(
      label: 'Giao diện',
      subtitle: 'Sáng tối',
      query: _query,
    );
    final showPinTabs = matchesQuery(
      label: 'Chọn tab',
      subtitle: 'Thanh dưới',
      query: _query,
    );

    // "Bán hàng" và "Quản trị" chung một lưới như thiết kế: mỗi nhóm thường
    // chỉ vài ô, tách ra là hai hàng lẻ loi.
    final sections = <(String, List<ModuleNavEntry>)>[
      for (final area in [NavArea.work, NavArea.communication])
        if (groups[area] case final entries?) (area.label, entries),
      ?_merged(groups),
    ];
    final nothing =
        sections.isEmpty &&
        accountEntries.isEmpty &&
        !showTheme &&
        !showPinTabs;

    return Scaffold(
      appBar: const OmniAppBar(title: 'Tất cả'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.xl,
              OmniSpacing.sm,
              OmniSpacing.xl,
              OmniSpacing.bottomSafe,
            ),
            children: [
              const _ProfileCard(),
              const SizedBox(height: OmniSpacing.lg),
              const _WorkspaceCard(),
              const SizedBox(height: OmniSpacing.lg),
              OmniSearchField(
                hint: 'Tìm tính năng…',
                outlined: true,
                onChanged: (value) => setState(() => _query = value),
              ),

              if (nothing)
                const Padding(
                  padding: EdgeInsets.only(top: OmniSpacing.section),
                  child: OmniEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy',
                    message: 'Thử một từ khác, hoặc xoá ô tìm kiếm.',
                  ),
                ),

              for (final (title, entries) in sections) ...[
                _GroupLabel(title),
                _TileGrid(entries: entries),
              ],

              if (showTheme || showPinTabs || accountEntries.isNotEmpty) ...[
                const _GroupLabel('Cá nhân'),
                _ListCard(
                  children: [
                    if (showTheme) const _ThemeRow(),
                    if (showPinTabs)
                      _ListRow(
                        label: 'Chọn tab',
                        subtitle: '$tabCount mục hiện ở thanh dưới',
                        onTap: () => context.pushNamed(ShellRoutes.pinTabs),
                      ),
                    for (final entry in accountEntries)
                      _ListRow(
                        label: entry.label,
                        subtitle: entry.subtitle,
                        onTap: () => context.pushNamed(entry.routeName),
                      ),
                  ],
                ),
              ],

              const _GroupLabel('Pháp lý & hỗ trợ'),
              _ListCard(
                children: [
                  _ListRow(
                    label: 'Chính sách quyền riêng tư',
                    external: true,
                    onTap: () => _openLink(context, AppConfig.privacyPolicyUrl),
                  ),
                  _ListRow(
                    label: 'Hỗ trợ',
                    subtitle: 'Liên hệ hỗ trợ và yêu cầu về dữ liệu',
                    external: true,
                    onTap: () => _openLink(context, AppConfig.supportUrl),
                  ),
                  _ListRow(
                    label: 'Xóa tài khoản',
                    subtitle:
                        'Vô hiệu hóa ngay và xóa dữ liệu trong vòng 7 ngày',
                    destructive: true,
                    onTap: () => _requestAccountDeletion(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              _LogoutButton(onPressed: () => _confirmLogout(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  (String, List<ModuleNavEntry>)? _merged(
    Map<NavArea, List<ModuleNavEntry>> groups,
  ) {
    final sales = groups[NavArea.sales] ?? const <ModuleNavEntry>[];
    final admin = groups[NavArea.admin] ?? const <ModuleNavEntry>[];
    if (sales.isEmpty && admin.isEmpty) return null;
    if (admin.isEmpty) return (NavArea.sales.label, sales);
    if (sales.isEmpty) return (NavArea.admin.label, admin);

    return (
      '${NavArea.sales.label} · ${NavArea.admin.label}',
      [...sales, ...admin],
    );
  }

  Future<void> _openLink(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  Future<void> _requestAccountDeletion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .requestAccountDeletion(password: password);
    } on ValidationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập lại để tiếp tục làm việc.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

/// Thẻ hồ sơ nền mực, ảnh đại diện có vành quỹ đạo sáng.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` từng trường: màn này vẽ tên, ảnh và vai — không phải cả phiên.
    // Theo dõi cả Session là dựng lại toàn bộ danh bạ mỗi khi phiên đổi bất
    // kỳ trường nào (token xoay, quyền tải lại).
    final displayName = ref.watch(sessionProvider.select((s) => s.displayName));
    final avatarUrl = ref.watch(
      sessionProvider.select((s) => s.user?.avatarUrl),
    );
    final roleLabel = ref.watch(sessionProvider.select((s) => s.roleLabel));

    return Container(
      padding: const EdgeInsets.all(OmniSpacing.lg),
      decoration: BoxDecoration(
        // Mặt mực trên nền tối gần như biến mất — nâng lên một bậc.
        color: Theme.of(context).brightness == Brightness.dark
            ? OmniColors.darkMuted
            : OmniColors.ink,
        borderRadius: OmniRadius.xlAll,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: OmniColors.orbit,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: OmniColors.ink,
                shape: BoxShape.circle,
              ),
              child: OmniAvatar(
                name: displayName,
                imageUrl: avatarUrl,
                size: 48,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: OmniType.section.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: OmniColors.inkMutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Không gian làm việc hiện tại, và nút "Đổi" khi tài khoản thuộc nhiều hơn
/// một không gian.
///
/// Nút chỉ hiện khi danh sách không gian đã về và có từ hai trở lên: bấm "Đổi"
/// để rồi thấy đúng một lựa chọn là lừa người dùng.
class _WorkspaceCard extends ConsumerWidget {
  const _WorkspaceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tenantName = ref.watch(sessionProvider.select((s) => s.tenant?.name));
    final canSwitch =
        (ref.watch(tenantOptionsProvider).valueOrNull?.length ?? 0) > 1;

    return _Surface(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.sm,
        OmniSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: OmniRadius.smAll,
            ),
            child: Icon(
              Icons.work_outline_rounded,
              size: OmniIconSize.md,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không gian làm việc',
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  tenantName ?? '—',
                  style: OmniType.bodyStrong.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (canSwitch)
            TextButton(
              onPressed: () {
                // Danh sách có thể đã cũ (vừa được thêm vào một công ty mới).
                ref.invalidate(tenantOptionsProvider);
                ref.read(sessionControllerProvider.notifier).chooseWorkspace();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                textStyle: OmniType.body.copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text('Đổi'),
            ),
        ],
      ),
    );
  }
}

/// Nhãn nhóm viết hoa, giãn chữ.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.xs,
        22,
        OmniSpacing.xs,
        OmniSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: OmniType.overline.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.96,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Mặt trắng viền mảnh, bo 16 — nền chung của các thẻ trên màn này.
class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Material chứ không DecoratedBox: dòng bên trong vẽ gợn sóng lên
    // Material gần nhất, và một nền tô giữa hai bên sẽ che mất nó.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: OmniRadius.xlAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Màu ô icon theo nhóm: Công việc mòng két, Trao đổi xanh dương, Bán hàng
/// vàng đất, Quản trị trung tính — như thiết kế. Chế độ tối lấy bản tối của
/// cùng giọng (xem `OmniToneColors`).
({Color background, Color foreground}) _toneFor(
  BuildContext context,
  NavArea area,
) {
  final tone = switch (area) {
    NavArea.work => OmniTone.success,
    NavArea.communication => OmniTone.info,
    NavArea.sales => OmniTone.warning,
    NavArea.admin || NavArea.account => OmniTone.neutral,
  };
  final (foreground, background) = tone.of(context);

  return (background: background, foreground: foreground);
}

/// Lưới 3 cột. Dựng bằng hàng chứ không bằng GridView: ô phải cao bằng nhau
/// theo ô có nhãn dài nhất trong hàng, và nhãn tiếng Việt hay xuống hai dòng.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.entries});

  final List<ModuleNavEntry> entries;

  static const _columns = 3;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += _columns) {
      final slice = entries.skip(i).take(_columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < _columns; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(
                  child: c < slice.length
                      ? _FeatureTile(entry: slice[c])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          rows[r],
        ],
      ],
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({required this.entry});

  final ModuleNavEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _toneFor(context, entry.area);
    final badgeProvider = entry.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);

    return Semantics(
      button: true,
      label: count > 0 ? '${entry.label}, $count' : entry.label,
      hint: entry.subtitle,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: OmniRadius.xlAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(entry.routeName),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tone.background,
                        borderRadius: OmniRadius.lgAll,
                      ),
                      child: Icon(entry.icon, size: 22, color: tone.foreground),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      entry.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 10,
                  right: 12,
                  child: switch (entry.badgeTone) {
                    NavBadgeTone.unread => OmniCountBadge.unread(count: count),
                    NavBadgeTone.alert => OmniCountBadge.alert(count: count),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ chứa các dòng, vạch ngăn giữa chúng.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Một dòng: nhãn, dòng phụ, mũi tên (vào màn khác) hoặc mũi tên chéo (mở
/// ra ngoài app). Dòng nguy hiểm tô đỏ và không có mũi tên.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.external = false,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final bool external;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniColors.dangerTextOf(context);
    final foreground = destructive ? danger : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: OmniType.bodyStrong.copyWith(
                        fontWeight: destructive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: destructive ? danger : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (!destructive)
                Icon(
                  external
                      ? Icons.north_east_rounded
                      : Icons.chevron_right_rounded,
                  size: OmniIconSize.md,
                  color: scheme.outline,
                ),
            ],
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
    final danger = OmniColors.dangerTextOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger,
        backgroundColor: scheme.surface,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(
          color: dark ? danger : OmniColors.dangerBorder,
          width: 1.5,
        ),
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.lgAll),
        textStyle: OmniType.input.copyWith(fontWeight: FontWeight.w600),
      ),
      child: const Text('Đăng xuất'),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
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

/// Light / dark / follow-the-system, matching what the web app offers.
///
/// Ba lựa chọn chứ không phải công tắc: "theo hệ thống" là lựa chọn thứ ba
/// thật, và một công tắc hai trạng thái không diễn đạt được nó. Vẽ theo thiết
/// kế: rãnh xám, phần đang chọn là viên trắng nổi nhẹ.
class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Giao diện',
              style: OmniType.bodyStrong.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: OmniRadius.smAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, label) in const [
                  (ThemeMode.system, 'Tự động'),
                  (ThemeMode.light, 'Sáng'),
                  (ThemeMode.dark, 'Tối'),
                ])
                  _ThemeSegment(
                    label: label,
                    tooltip: themeModeDisplay(value).label,
                    selected: mode == value,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).set(value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          // Rãnh 30dp trông gọn như thiết kế; vùng chạm vẫn đủ cao nhờ hàng.
          constraints: const BoxConstraints(minHeight: 32),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: OmniRadius.xsAll,
              border: selected
                  ? Border.all(color: scheme.outlineVariant)
                  : null,
            ),
            child: Text(
              label,
              style: OmniType.micro.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bỏ dấu để "kenh" tìm ra "Kết nối kênh".
///
/// Người dùng gõ trên bàn phím điện thoại, giữa lúc làm việc, và sẽ không bật
/// bộ gõ tiếng Việt lên chỉ để tìm một màn hình.
String foldDiacritics(String input) {
  // Hai chuỗi này phải khớp từng ký tự một. Lệch một là mọi chữ sau đó ánh xạ
  // sai — âm thầm, không lỗi, chỉ là tìm không ra. Nhóm theo nguyên âm để đếm
  // được bằng mắt: a×17, e×11, i×5, o×17, u×11, y×5, đ×1 = 67.
  const marks =
      'àáạảãâầấậẩẫăằắặẳẵ' // a
      'èéẹẻẽêềếệểễ' // e
      'ìíịỉĩ' // i
      'òóọỏõôồốộổỗơờớợởỡ' // o
      'ùúụủũưừứựửữ' // u
      'ỳýỵỷỹ' // y
      'đ';
  const plain =
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyy'
      'd';
  assert(
    marks.length == plain.length,
    'bảng bỏ dấu lệch: ${marks.length} vs ${plain.length}',
  );

  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = marks.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }

  return buffer.toString();
}

/// Một mục có khớp từ khoá không.
///
/// Khớp cả dòng phụ: người dùng nhớ "zalo" chứ không nhớ tính năng tên là
/// "Kết nối kênh".
bool matchesQuery({
  required String label,
  required String? subtitle,
  required String query,
}) {
  final needle = foldDiacritics(query.trim());
  if (needle.isEmpty) return true;

  return foldDiacritics(label).contains(needle) ||
      foldDiacritics(subtitle ?? '').contains(needle);
}

/// Lọc trước khi dựng, để nhóm không còn mục nào thì biến mất luôn cả tiêu đề —
/// một tiêu đề nhóm trống trông như lỗi tải dữ liệu.
Map<NavArea, List<ModuleNavEntry>> _filtered(
  Map<NavArea, List<ModuleNavEntry>> groups,
  String query,
) {
  final result = <NavArea, List<ModuleNavEntry>>{};
  for (final area in NavArea.values) {
    final kept = (groups[area] ?? const <ModuleNavEntry>[])
        .where(
          (entry) => matchesQuery(
            label: entry.label,
            subtitle: entry.subtitle,
            query: query,
          ),
        )
        .toList();
    if (kept.isNotEmpty) result[area] = kept;
  }

  return result;
}
