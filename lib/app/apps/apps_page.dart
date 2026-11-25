import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';
import '../../modules/auth/application/login_controller.dart';
import '../../security/session/session_controller.dart';
import '../router/app_router.dart';
import 'app_manifest.dart';
import 'app_shell_layout.dart';

/// Màn Chọn ứng dụng (quyết định 2026-11-11): tới sau khi mở app, chọn hay đổi
/// công ty. Chỉ những ứng dụng người dùng có quyền và công ty bật.
///
/// Phong cách iOS 25/11/2026 (spec §3.6): tên công ty nhỏ ở đầu (chạm để đổi),
/// lời chào 28 đậm, Bàn làm việc là một dòng riêng ở trên, các ứng dụng là lưới
/// 3 cột biểu tượng màu đặc như màn hình iPhone (chỉ tên, không chữ phụ), và
/// nhóm "Cần xử lý" liệt kê đúng những mục đang có huy hiệu đỏ.
///
/// Cũng là điểm rẽ: chỉ MỘT ô thì vào thẳng ô đó; bản khai báo nói tắt (hoặc
/// tải lỗi, API cũ) thì về màn mở đầu cũ.
class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  bool _leaving = false;

  void _leave(String Function() target) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(target());
    });
  }

  String _pathOf(ShellApp app, ShellItem item) {
    ref.read(currentAppKeyProvider.notifier).state = app.key;
    final name = appTabRouteName(
      item.entry.routeName,
      ref.read(appTabCloneRoutesProvider),
    );
    return GoRouter.of(context).namedLocation(name);
  }

  String _entryPath(ShellApp app) => _pathOf(app, app.first!);

  void _open(ShellApp app) {
    HapticFeedback.lightImpact();
    context.go(_entryPath(app));
  }

  void _openItem(ShellApp app, ShellItem item) {
    HapticFeedback.lightImpact();
    context.go(_pathOf(app, item));
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(appManifestProvider);
    final layout = ref.watch(appShellLayoutProvider);
    final entries = layout?.entries ?? const <ShellApp>[];
    final ready = manifest.hasValue || manifest.hasError;

    if (ready && entries.isEmpty) {
      _leave(() => legacyLandingPath(ref.read));
    } else if (ready && entries.length == 1) {
      _leave(() => _entryPath(entries.single));
    }
    final showGrid = ready && entries.length > 1;

    final home = entries.where((a) => a.key == homeAppKey).firstOrNull;
    final apps = entries.where((a) => a.key != homeAppKey).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showGrid
          ? const _AppsTopBar()
          : const PreferredSize(
              preferredSize: Size.zero,
              child: SizedBox.shrink(),
            ),
      body: !showGrid
          ? const SizedBox.expand()
          : OmniTopBarOverlap.wrap(
              child: Builder(
                builder: (context) => ListView(
                  padding: EdgeInsets.fromLTRB(
                    OmniSpacing.lg,
                    OmniTopBarOverlap.of(context) + 4,
                    OmniSpacing.lg,
                    MediaQuery.viewPaddingOf(context).bottom + 32,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _AppsGreeting(),
                            const SizedBox(height: 16),
                            if (home != null)
                              _HomeRow(app: home, onTap: () => _open(home)),
                            if (apps.isNotEmpty) ...[
                              const _SectionLabel('Ứng dụng'),
                              _AppGrid(apps: apps, onOpen: _open),
                            ],
                            _TodoSection(apps: entries, onOpen: _openItem),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Thanh trên: tên công ty (chạm để đổi khi có nhiều công ty), chuông và tài
/// khoản. Không logo (logo chỉ ở đăng nhập / màn mở app).
class _AppsTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AppsTopBar();

  static const _bar = OmniTopBar(semanticsTitle: 'Ứng dụng');

  @override
  Size get preferredSize => _bar.preferredSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider.select((s) => s.tenant?.name));
    final canSwitch =
        (ref.watch(tenantOptionsProvider).valueOrNull?.length ?? 0) > 1;
    return OmniTopBarLeading(
      builder: (context, _) => _CompanyButton(
        name: name ?? 'Viomni',
        onTap: canSwitch
            ? () {
                HapticFeedback.selectionClick();
                ref.invalidate(tenantOptionsProvider);
                ref.read(sessionControllerProvider.notifier).chooseWorkspace();
              }
            : null,
      ),
      child: _bar,
    );
  }
}

class _CompanyButton extends StatelessWidget {
  const _CompanyButton({required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Cỡ chữ lấy từ OmniType (luật: không đặt cỡ thô ngoài lib/design).
            style: OmniType.body.copyWith(
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: .82),
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.unfold_more_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Semantics(
          button: onTap != null,
          label: onTap != null ? 'Đổi công ty, $name' : name,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppsGreeting extends ConsumerWidget {
  const _AppsGreeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userName = ref.watch(sessionProvider.select((s) => s.user?.fullName));
    final firstName = userName?.trim().split(RegExp(r'\s+')).last;
    final greeting = firstName != null && firstName.isNotEmpty
        ? 'Xin chào, $firstName'
        : 'Ứng dụng của bạn';

    return Semantics(
      header: true,
      child: Text(
        greeting,
        maxLines: 2,
        // 28/800 (spec iOS §3.6): kiểu 28 có sẵn của OmniType.
        style: OmniType.moneyHero.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// Màu đặc của từng ứng dụng (tông đậm của bảng cũ). Ngoại lệ duy nhất của
/// luật "một màu nhấn": biểu tượng ứng dụng giúp nhận ra nhau trong lưới.
Color _appColor(String key) => switch (key) {
  homeAppKey => OmniColors.primary,
  'sales' => const Color(0xFF059669),
  'stock' => const Color(0xFFEA580C),
  'work' => const Color(0xFF4F46E5),
  'finance' => const Color(0xFF0D9488),
  'hr' => const Color(0xFFDB2777),
  'system' => const Color(0xFF475569),
  _ => OmniColors.primary,
};

/// Tổng huy hiệu đỏ (cần xử lý) và cờ "có mục mới" của một ứng dụng.
(int alert, bool unread) _badgeOf(WidgetRef ref, ShellApp app) {
  var alert = 0;
  var unread = false;
  for (final item in app.all) {
    final badge = item.entry.badge;
    if (badge == null) continue;
    final n = ref.watch(badge);
    if (n <= 0) continue;
    if (item.entry.badgeTone == NavBadgeTone.alert) {
      alert += n;
    } else {
      unread = true;
    }
  }
  return (alert, unread);
}

/// Ô vuông màu đặc chứa icon trắng (biểu tượng ứng dụng).
class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: contrast
            ? Border.all(color: Theme.of(context).colorScheme.onSurface)
            : null,
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        // Đầu nhóm 13/600 = OmniType.overline.
        style: OmniType.overline.copyWith(
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Thẻ trắng bo 16 (nhóm) — nền của dòng Bàn làm việc, lưới và Cần xử lý.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// Dòng Bàn làm việc: trang mở đầu, không phải một ứng dụng ngang hàng.
class _HomeRow extends ConsumerWidget {
  const _HomeRow({required this.app, required this.onTap});

  final ShellApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (alert, unread) = _badgeOf(ref, app);
    final subtitle = app.all.take(2).map((i) => i.entry.label).join(' · ');

    return _Card(
      child: Semantics(
        button: true,
        label: alert > 0 ? '${app.name}, $alert' : app.name,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('app-tile-${app.key}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                _AppIcon(
                  icon: app.icon,
                  color: _appColor(app.key),
                  size: 44,
                  radius: 12,
                  iconSize: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: OmniType.navTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.bodySm.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (alert > 0) ...[
                  OmniCountBadge.alert(count: alert, ringColor: scheme.surface),
                  const SizedBox(width: 6),
                ] else if (unread) ...[
                  const OmniUnreadDot(excludeSemantics: true),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant.withValues(alpha: .6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lưới 3 cột (màn hẹp / chữ phóng to thì 2) trong một thẻ: biểu tượng 62 bo
/// 16 màu đặc, tên 13 đậm bên dưới. Không chữ phụ.
class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps, required this.onOpen});

  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 16),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = box.maxWidth < 260 || scale > 1.35 ? 2 : 3;
            final width = box.maxWidth / columns;
            return Wrap(
              runSpacing: 18,
              children: [
                for (final app in apps)
                  SizedBox(
                    width: width,
                    child: _AppTile(
                      key: ValueKey('app-tile-${app.key}'),
                      app: app,
                      onTap: () => onOpen(app),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppTile extends ConsumerStatefulWidget {
  const _AppTile({super.key, required this.app, required this.onTap});

  final ShellApp app;
  final VoidCallback onTap;

  @override
  ConsumerState<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends ConsumerState<_AppTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = widget.app;
    final (alert, unread) = _badgeOf(ref, app);
    final semantics = alert > 0
        ? '${app.name}, $alert'
        : unread
        ? '${app.name}, có mục mới'
        : app.name;

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AppIcon(
                    icon: app.icon,
                    color: _appColor(app.key),
                    size: 62,
                    radius: 16,
                    iconSize: 30,
                  ),
                  if (alert > 0)
                    Positioned(
                      top: -6,
                      right: -7,
                      child: OmniCountBadge.alert(
                        count: alert,
                        ringColor: scheme.surface,
                      ),
                    )
                  else if (unread)
                    const Positioned(
                      top: -2,
                      right: -2,
                      child: OmniUnreadDot(excludeSemantics: true),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  app.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: OmniType.overline.copyWith(
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Cần xử lý": mỗi mục đang có huy hiệu đỏ là một dòng (icon + tên mục + tên
/// ứng dụng + số), chạm là vào thẳng mục đó. Không có mục nào thì ẩn nhóm.
class _TodoSection extends ConsumerWidget {
  const _TodoSection({required this.apps, required this.onOpen});

  final List<ShellApp> apps;
  final void Function(ShellApp app, ShellItem item) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <(ShellApp, ShellItem, int)>[];
    for (final app in apps) {
      for (final item in app.all) {
        final badge = item.entry.badge;
        if (badge == null || item.entry.badgeTone != NavBadgeTone.alert) {
          continue;
        }
        final n = ref.watch(badge);
        if (n > 0) rows.add((app, item, n));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Cần xử lý'),
        _Card(
          child: Column(
            children: [
              for (final (i, (app, item, n)) in rows.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: scheme.outlineVariant.withValues(alpha: .6),
                  ),
                Semantics(
                  button: true,
                  label: '${item.entry.label}, ${app.name}, $n',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('app-todo-${item.key}'),
                    onTap: () => onOpen(app, item),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          children: [
                            _AppIcon(
                              icon: item.entry.icon,
                              color: _appColor(app.key),
                              size: 32,
                              radius: 9,
                              iconSize: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.entry.label,
                                    maxLines: 2,
                                    style: OmniType.section.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    app.name,
                                    style: OmniType.caption.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OmniCountBadge.alert(count: n),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
