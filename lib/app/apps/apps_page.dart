import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';
import '../../modules/auth/application/login_controller.dart';
import '../../security/session/session_controller.dart';
import '../router/app_router.dart';
import 'app_manifest.dart';
import 'app_shell_layout.dart';

/// Màn Chọn ứng dụng (quyết định 2026-11-11): tới sau khi mở app, chọn hay đổi
/// công ty. Lưới ô lớn kiểu biểu tượng ứng dụng, chỉ những ứng dụng người dùng
/// có quyền và công ty bật; huy hiệu cho biết ứng dụng nào có việc chờ.
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

  String _entryPath(ShellApp app) {
    ref.read(currentAppKeyProvider.notifier).state = app.key;
    final first = app.first!;
    final name = appTabRouteName(
      first.entry.routeName,
      ref.read(appTabCloneRoutesProvider),
    );
    return GoRouter.of(context).namedLocation(name);
  }

  void _open(ShellApp app) {
    HapticFeedback.lightImpact();
    context.go(_entryPath(app));
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
                    OmniSpacing.xl,
                    OmniTopBarOverlap.of(context) + 24,
                    OmniSpacing.xl,
                    MediaQuery.viewPaddingOf(context).bottom + 32,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _AppGrid(apps: entries, onOpen: _open),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Thanh trên: tên công ty (chạm để đổi khi có nhiều công ty), chuông, tài
/// khoản — không logo, không tiêu đề màn (ít chữ).
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
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.navTitle.copyWith(color: scheme.onSurface),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: OmniIconSize.md,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: onTap != null,
        label: onTap != null ? 'Đổi công ty, $name' : name,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(padding: const EdgeInsets.only(left: 4), child: row),
          ),
        ),
      ),
    );
  }
}

/// Lưới 3 cột (màn hẹp / chữ phóng to thì 2): mỗi ô một biểu tượng lớn bo
/// tròn kiểu logo ứng dụng và tên dưới.
class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps, required this.onOpen});

  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth < 300 || scale > 1.2 ? 2 : 3;
        const gap = 10.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 22,
          children: [
            for (final (i, app) in apps.indexed)
              SizedBox(
                width: width,
                child: _AppTile(
                  key: ValueKey('app-tile-${app.key}'),
                  app: app,
                  index: i,
                  onTap: () => onOpen(app),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppTile extends ConsumerStatefulWidget {
  const _AppTile({
    super.key,
    required this.app,
    required this.index,
    required this.onTap,
  });

  final ShellApp app;
  final int index;
  final VoidCallback onTap;

  @override
  ConsumerState<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends ConsumerState<_AppTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final app = widget.app;

    // Huy hiệu của ô: tổng việc CẦN XỬ LÝ (đỏ); không có thì chấm vàng nếu có
    // cái mới chưa xem.
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
    final semantics = alert > 0
        ? '${app.name}, $alert'
        : unread
        ? '${app.name}, có mục mới'
        : app.name;

    final icon = AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.7],
                colors: [
                  Color.alphaBlend(
                    scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
                    scheme.surface,
                  ),
                  scheme.surface,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(app.icon, size: 34, color: scheme.primary),
          ),
          if (alert > 0)
            Positioned(
              top: -5,
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
    );

    final tile = Semantics(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              app.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: OmniType.bodySm.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    if (!OmniMotion.enabled(context)) return tile;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + 40 * widget.index),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: tile,
    );
  }
}
