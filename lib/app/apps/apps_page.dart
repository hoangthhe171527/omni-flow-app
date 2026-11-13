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
                    OmniSpacing.lg,
                    OmniTopBarOverlap.of(context) + 8,
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
                            _AppGrid(apps: entries, onOpen: _open),
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

/// Thanh trên: biểu tượng V-Orbit 30dp cạnh tên công ty (chạm để đổi khi có
/// nhiều công ty), chuông và tài khoản.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final badge = BrandAnchor(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.14)
                : scheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: OmniBrandMark(size: 21, framed: false)),
      ),
    );

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Viomni',
          maxLines: 1,
          style: OmniType.caption.copyWith(
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.body.copyWith(
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 10),
        Flexible(child: label),
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

/// Lưới 3 cột (màn hẹp / chữ phóng to thì 2): mỗi ô một biểu tượng lớn bo
/// tròn kiểu logo ứng dụng và tên dưới.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: OmniType.title.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chọn không gian làm việc để bắt đầu',
            style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps, required this.onOpen});

  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth < 260 || scale > 1.35
            ? 1
            : box.maxWidth >= 520
            ? 3
            : 2;
        const gap = 12.0;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
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

(Color, Color) _appPalette(String key) => switch (key) {
  homeAppKey => (const Color(0xFF38BDF8), const Color(0xFF2563EB)),
  'sales' => (const Color(0xFF34D399), const Color(0xFF059669)),
  'stock' => (const Color(0xFFFBBF24), const Color(0xFFEA580C)),
  'work' => (const Color(0xFF818CF8), const Color(0xFF4F46E5)),
  'finance' => (const Color(0xFF2DD4BF), const Color(0xFF0D9488)),
  'system' => (const Color(0xFF94A3B8), const Color(0xFF475569)),
  _ => (const Color(0xFF60A5FA), const Color(0xFF2563EB)),
};

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
    final (cLight, cDark) = _appPalette(app.key);

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

    final subtitle = app.all.take(3).map((i) => i.entry.label).join(' · ');

    final iconBox = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cLight, cDark],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.18 : 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: cDark.withValues(alpha: dark ? 0.38 : 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(app.icon, size: 26, color: Colors.white),
        ),
        if (alert > 0)
          Positioned(
            top: -5,
            right: -6,
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
    );

    final borderColor = OmniColors.byBrightness(
      context,
      OmniColors.border,
      OmniColors.darkBorder,
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
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface,
                  Color.alphaBlend(
                    cDark.withValues(alpha: dark ? 0.10 : 0.04),
                    scheme.surface,
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: OmniColors.ink.withValues(alpha: dark ? 0.28 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                iconBox,
                const SizedBox(height: 14),
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 32,
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.micro.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
