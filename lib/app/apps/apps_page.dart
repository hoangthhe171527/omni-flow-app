import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/module/nav_destination.dart';
import '../../core/utils/text_search.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
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

  /// Từ khoá ô "Tìm ứng dụng hoặc màn" (bỏ dấu, tại chỗ).
  String _q = '';

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

    // Bàn làm việc là ô ĐẦU của lưới (bản duyệt giống web), không còn dòng
    // riêng phía trên.
    final apps = [
      ...entries.where((a) => a.key == homeAppKey),
      ...entries.where((a) => a.key != homeAppKey),
    ];

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
                            OmniSearchBottom(
                              fieldKey: const ValueKey('apps-search'),
                              hint: 'Tìm ứng dụng hoặc màn…',
                              debounce: const Duration(milliseconds: 150),
                              onChanged: (v) => setState(() => _q = v),
                            ),
                            const SizedBox(height: 24),
                            if (_q.trim().isNotEmpty)
                              _SearchResults(
                                query: _q,
                                apps: apps,
                                onOpen: _open,
                                onOpenItem: _openItem,
                              )
                            else ...[
                              _AppGrid(apps: apps, onOpen: _open),
                              _TodoSection(apps: entries, onOpen: _openItem),
                            ],
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
            LucideIcons.chevronsUpDown,
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

/// Lời chào theo buổi + ngày, căn giữa (bản duyệt "Màn Ứng dụng giống web",
/// web `nav.appsGreeting`).
class _AppsGreeting extends ConsumerWidget {
  const _AppsGreeting();

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userName = ref.watch(sessionProvider.select((s) => s.user?.fullName));
    final firstName = userName?.trim().split(RegExp(r'\s+')).last;
    final now = DateTime.now();
    final part = now.hour < 11
        ? 'sáng'
        : now.hour < 18
        ? 'chiều'
        : 'tối';
    final greeting = firstName != null && firstName.isNotEmpty
        ? 'Chào buổi $part, $firstName'
        : 'Chào buổi $part';
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            greeting,
            maxLines: 2,
            textAlign: TextAlign.center,
            // `greeting` 26/600 (Chuẩn Mobile UI, gói Viomni).
            style: OmniType.title.copyWith(
              fontSize: 26,
              height: 1.25,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          textAlign: TextAlign.center,
          style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Tông + icon + mô tả của từng ứng dụng — khớp 1:1 web (`use-app-shell`
/// `APP_ICONS` / `APP_TONES`, `nav.appDesc`). Ứng dụng web chưa khai báo thì
/// theo mặc định của web: LayoutGrid, tông xanh, mô tả = các mục bên trong.
OmniHue _hueOf(String key) => switch (key) {
  homeAppKey => OmniHue.blue,
  'sales' => OmniHue.red,
  'stock' => OmniHue.orange,
  'work' => OmniHue.violet,
  'finance' => OmniHue.teal,
  'system' => OmniHue.neutral,
  _ => OmniHue.blue,
};

IconData _iconOf(String key) => switch (key) {
  homeAppKey => LucideIcons.monitor,
  'sales' => LucideIcons.shoppingBag,
  'stock' => LucideIcons.package,
  'work' => LucideIcons.squareKanban,
  'finance' => LucideIcons.wallet,
  'system' => LucideIcons.settings,
  _ => LucideIcons.layoutGrid,
};

String _descOf(ShellApp app) => switch (app.key) {
  homeAppKey => 'Việc cần làm, lịch nhắc',
  'sales' => 'Hộp thư, khách, đơn hàng',
  'stock' => 'Lô, tồn kho, kiểm kê',
  'work' => 'Dự án, tài liệu',
  'finance' => 'Chi phí, tiền hàng lô',
  'system' => 'Kênh, cấu hình',
  _ => app.all.take(3).map((i) => i.entry.label).join(', '),
};

/// Tổng huy hiệu "cần xử lý" và cờ "có mục mới" của một ứng dụng.
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

/// Huy hiệu số VÀNG nhạt (web `--sidebar-badge`): số việc cần xử lý — không
/// đỏ, vì đó là việc thường ngày, không phải lỗi.
class _YellowBadge extends StatelessWidget {
  const _YellowBadge({required this.count, this.ring});

  final int count;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return OmniCountBadge(
      count: count,
      compact: true,
      color: dark ? OmniColors.darkWarningSoft : OmniColors.warningSoft,
      foreground: OmniColors.warningTextOf(context),
      ringColor: ring,
    );
  }
}

/// Ô icon nền nhạt theo tông, icon Lucide màu đậm cùng tông (như web).
class _AppIcon extends StatelessWidget {
  const _AppIcon({
    required this.icon,
    required this.hue,
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  final IconData icon;
  final OmniHue hue;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tone = OmniFeatureTones.of(context, hue);
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: contrast
              ? Theme.of(context).colorScheme.onSurface
              : tone.foreground.withValues(alpha: .16),
        ),
      ),
      child: Icon(icon, size: iconSize, color: tone.foreground),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: OmniType.overline.copyWith(
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Lưới 3 cột (màn hẹp / chữ phóng to thì 2), Bàn làm việc là ô đầu: ô icon
/// 64 bo 20 nền tông, tên 15/600, mô tả 12 ≤ 2 dòng, huy hiệu vàng góc ô.
class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps, required this.onOpen});

  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth < 260 || scale > 1.35 ? 2 : 3;
        final width = box.maxWidth / columns;
        return Wrap(
          runSpacing: 20,
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
    final desc = _descOf(app);
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
          scale: _down ? 0.97 : 1,
          duration: OmniMotion.of(context).fast,
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AppIcon(
                    icon: _iconOf(app.key),
                    hue: _hueOf(app.key),
                    size: 64,
                    radius: 20,
                    iconSize: 30,
                  ),
                  if (alert > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: _YellowBadge(count: alert, ring: scheme.surface),
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
                  style: OmniType.bodyStrong.copyWith(
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                  child: Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurfaceVariant,
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

/// "Cần chú ý": mỗi mục đang có việc cần xử lý là một VIÊN (vòng tông 28 +
/// icon mục + tên mục + huy hiệu vàng), xuống hàng khi nhiều; chạm là vào
/// thẳng mục đó. Không có mục nào thì ẩn nhóm.
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
        const _SectionLabel('Cần chú ý'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (app, item, n) in rows)
              Semantics(
                button: true,
                label: '${item.entry.label}, ${app.name}, $n',
                excludeSemantics: true,
                child: Material(
                  color: scheme.surface,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('app-todo-${item.key}'),
                    onTap: () => onOpen(app, item),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AppIcon(
                            icon: item.entry.icon,
                            hue: _hueOf(app.key),
                            size: 28,
                            radius: 14,
                            iconSize: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.entry.label,
                            style: OmniType.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _YellowBadge(count: n),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Kết quả ô tìm: ứng dụng và màn khớp (bỏ dấu), nhóm theo loại, chạm là vào.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.apps,
    required this.onOpen,
    required this.onOpenItem,
  });

  final String query;
  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;
  final void Function(ShellApp app, ShellItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final appHits = [
      for (final a in apps)
        if (matchesQuery(label: a.name, subtitle: _descOf(a), query: query)) a,
    ];
    final itemHits = [
      for (final a in apps)
        for (final i in a.all)
          if (matchesQuery(
            label: i.entry.label,
            subtitle: a.name,
            query: query,
          ))
            (a, i),
    ];
    if (appHits.isEmpty && itemHits.isEmpty) {
      return OmniEmptyState.filtered(
        title: 'Không có ứng dụng hay màn khớp "$query"',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appHits.isNotEmpty)
          OmniGroupSection(
            title: 'Ứng dụng',
            dividerIndent: 58,
            children: [
              for (final a in appHits)
                OmniGroupRow(
                  key: ValueKey('app-search-app-${a.key}'),
                  leading: _AppIcon(
                    icon: _iconOf(a.key),
                    hue: _hueOf(a.key),
                    size: 32,
                    radius: 10,
                    iconSize: 18,
                  ),
                  title: a.name,
                  subtitle: _descOf(a),
                  onTap: () => onOpen(a),
                ),
            ],
          ),
        if (itemHits.isNotEmpty) ...[
          if (appHits.isNotEmpty) const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            title: 'Màn',
            dividerIndent: 58,
            children: [
              for (final (a, i) in itemHits)
                OmniGroupRow(
                  key: ValueKey('app-search-item-${i.key}'),
                  leading: _AppIcon(
                    icon: i.entry.icon,
                    hue: _hueOf(a.key),
                    size: 32,
                    radius: 10,
                    iconSize: 18,
                  ),
                  title: i.entry.label,
                  subtitle: a.name,
                  onTap: () => onOpenItem(a, i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
