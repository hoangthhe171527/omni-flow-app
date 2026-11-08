import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/utils/text_search.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';
import '../../modules/settings/settings_module.dart';
import 'tab_bar_editor_sheet.dart';

export '../../core/utils/text_search.dart' show foldDiacritics, matchesQuery;

/// Một ô trong lưới "Tất cả".
class DirectoryTile {
  const DirectoryTile({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.hue,
    required this.onTap,
    this.badge,
    this.badgeTone = NavBadgeTone.unread,
    this.badgeDisplay = NavBadgeDisplay.count,
    this.id,
  });

  /// Khoá ổn định của ô (tên route); mặc định là nhãn.
  final String? id;

  final String label;
  final String? subtitle;
  final IconData icon;
  final OmniHue hue;
  final VoidCallback onTap;
  final ProviderListenable<int>? badge;
  final NavBadgeTone badgeTone;
  final NavBadgeDisplay badgeDisplay;
}

typedef DirectorySection = ({String label, List<DirectoryTile> tiles});

/// Sắc ô icon theo khu — `All.dc.html`.
OmniHue hueOfArea(NavArea area) => switch (area) {
  NavArea.communication => OmniHue.teal,
  NavArea.sales => OmniHue.orange,
  NavArea.work => OmniHue.blue,
  NavArea.admin => OmniHue.violet,
  NavArea.finance => OmniHue.violet,
  NavArea.account => OmniHue.neutral,
};

/// Gom mục của module thành 4 nhóm nghiệp vụ (`tat-ca-tai-khoan-uiux.html`,
/// duyệt 07/11) và lọc theo từ khoá; nhóm rỗng bị bỏ.
///
/// Bán hàng · Vận hành (công việc, dòng việc, thông báo) · Tài chính · Đội &
/// quản trị. Mục khu Tài khoản (nền, cài đặt thông báo, quyền của tôi) KHÔNG
/// lên lưới: cài đặt nằm ở danh sách "Cài đặt ứng dụng", quyền ở màn Tài khoản.
List<DirectorySection> buildDirectorySections(
  Map<NavArea, List<ModuleNavEntry>> groups, {
  required void Function(String routeName) open,
  required String query,
}) {
  DirectoryTile fromEntry(ModuleNavEntry e) => DirectoryTile(
    label: e.label,
    subtitle: e.subtitle,
    icon: e.icon,
    hue: hueOfArea(e.area),
    onTap: () => open(e.routeName),
    badge: e.badge,
    badgeTone: e.badgeTone,
    badgeDisplay: e.badgeDisplay,
    id: e.routeName,
  );
  List<DirectoryTile> of(List<NavArea> areas) => [
    for (final a in areas) ...?groups[a]?.map(fromEntry),
  ];
  bool keep(DirectoryTile t) =>
      matchesQuery(label: t.label, subtitle: t.subtitle, query: query);
  // Thông báo khai báo ở khu "Trao đổi" nhưng là việc hằng ngày của vận hành.
  bool isNotifications(DirectoryTile t) => t.id == _notificationsRoute;
  final sales = of([NavArea.communication, NavArea.sales]);

  final raw = <(String, List<DirectoryTile>)>[
    (
      'Bán hàng',
      [
        for (final t in sales)
          if (!isNotifications(t)) t,
      ],
    ),
    (
      'Vận hành',
      [
        ...of([NavArea.work]),
        for (final t in sales)
          if (isNotifications(t)) t,
      ],
    ),
    ('Tài chính', of([NavArea.finance])),
    ('Đội & quản trị', of([NavArea.admin])),
  ];

  return [
    for (final (label, tiles) in raw)
      if (tiles.where(keep).toList() case final kept when kept.isNotEmpty)
        (label: label, tiles: kept),
  ];
}

/// Tên route trung tâm thông báo (`NotificationRoutes.centre`) — chép chuỗi
/// để shell không import route của module thông báo.
const _notificationsRoute = 'notifications.centre';

/// Danh bạ "Tất cả": MỌI tính năng người dùng có quyền dùng, gom theo nhóm,
/// tìm được bằng từ khoá (không cần gõ dấu).
///
/// Không có gì viết cứng theo module — module khai báo mục, registry lọc theo
/// quyền và cờ tính năng, màn này dựng bất cứ thứ gì nhận được. Bên dưới lưới:
/// "Cài đặt ứng dụng" (thông báo, giao diện, nền) và "Trợ giúp". Hồ sơ, mật
/// khẩu, workspace, đăng xuất nằm ở màn Tài khoản (bấm avatar).
class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _query = '';

  /// Ô đã từng hiện: chỉ lần dựng đầu tiên mới chạy hoạt ảnh, gõ tìm không phát lại.
  final _seen = <String>{};

  Future<void> _openLink(Uri url) async {
    // Chụp trước khi await: màn có thể đã bị đóng khi trình duyệt trả về.
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (opened) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(directoryGroupsProvider);
    final sections = buildDirectorySections(
      groups,
      open: (name) => context.pushNamed(name),
      query: _query,
    );
    bool shows(String label) =>
        matchesQuery(label: label, subtitle: null, query: _query);
    final settingsRows = <Widget>[
      if (shows('Thông báo'))
        _ListRow(
          icon: Icons.notifications_none_rounded,
          label: 'Thông báo',
          onTap: () => context.pushNamed(SettingsModule.notifications),
        ),
      if (shows('Giao diện sáng tối')) const _ThemeRow(),
      if (shows('Nền'))
        _ListRow(
          icon: Icons.wallpaper_outlined,
          label: 'Nền',
          onTap: () => context.pushNamed(SettingsModule.background),
        ),
    ];
    final helpRows = <Widget>[
      if (shows('Trung tâm hỗ trợ'))
        _ListRow(
          icon: Icons.help_outline_rounded,
          label: 'Trung tâm hỗ trợ',
          external: true,
          onTap: () => _openLink(AppConfig.supportUrl),
        ),
      if (shows('Chính sách quyền riêng tư'))
        _ListRow(
          icon: Icons.policy_outlined,
          label: 'Chính sách quyền riêng tư',
          external: true,
          onTap: () => _openLink(AppConfig.privacyPolicyUrl),
        ),
      if (shows('Phiên bản'))
        _ListRow(
          icon: Icons.info_outline_rounded,
          label: 'Phiên bản',
          value: AppConfig.appVersion,
        ),
    ];
    final nothing =
        sections.isEmpty && settingsRows.isEmpty && helpRows.isEmpty;
    // Đánh dấu "đã hiện" SAU khung này (ô được dựng sau build của trang).
    final ids = [
      for (final s in sections)
        for (final t in s.tiles) t.id ?? t.label,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _seen.addAll(ids));
    final scheme = Theme.of(context).colorScheme;
    // Chỉ số hoạt ảnh chạy liên tục qua các nhóm.
    final starts = <int>[];
    var running = 0;
    for (final s in sections) {
      starts.add(running);
      running += s.tiles.length;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Nền xám nhạt để các khung nhóm trắng tách bạch (bố cục ERP).
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: OmniTopBar(
        semanticsTitle: 'Tất cả',
        actions: [
          OmniTopBarAction(
            icon: Icons.tune_rounded,
            tooltip: 'Sửa menu',
            onPressed: () => showTabBarEditor(context),
          ),
        ],
        bottom: _SearchBottom(
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final topInset = OmniTopBarOverlap.of(context);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    OmniSpacing.xl,
                    topInset + 14,
                    OmniSpacing.xl,
                    OmniSpacing.bottomSafe,
                  ),
                  children: [
                    if (nothing)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'Không tìm thấy “$_query”',
                          textAlign: TextAlign.center,
                          style: OmniType.body.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final section in sections) ...[
                      if (section != sections.first) const SizedBox(height: 16),
                      _SectionLabel(section.label),
                      _GroupCard(
                        child: _TileGrid(
                          tiles: section.tiles,
                          firstIndex: starts[sections.indexOf(section)],
                          seen: _seen,
                        ),
                      ),
                    ],
                    if (settingsRows.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel('Cài đặt ứng dụng'),
                      _GroupCard(child: Column(children: settingsRows)),
                    ],
                    if (helpRows.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel('Trợ giúp'),
                      _GroupCard(child: Column(children: helpRows)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ô tìm dưới thanh trên (nằm trong viên kính của [OmniTopBar]): cao 44.
/// "Sửa menu" là nút kính tròn trên thanh trên.
class _SearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBottom({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          // Giãn dọc: ô tìm và nút đều cao đúng 44, không co về 40.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: OmniSearchField(
                hint: 'Tìm tính năng…',
                flat: true,
                dense: true,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới tính năng thích ứng theo chiều rộng và cỡ chữ.
///
/// Điện thoại tiêu chuẩn giữ bốn cột như bản mẫu. Khi màn hẹp hoặc người dùng
/// phóng chữ, lưới tự giảm cột thay vì ép nhãn/tràn badge. Mỗi ô có cùng kích
/// thước trong một [Wrap], nên khung nhóm ôm đúng số hàng thực tế; hàng cuối
/// chỉ dựng số ô thật, không chèn ô rỗng hay để lại khoảng trắng giả.
class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.tiles,
    required this.firstIndex,
    required this.seen,
  });

  final Set<String> seen;

  final List<DirectoryTile> tiles;
  final int firstIndex;

  static const _maxColumns = 4;
  static const _gap = OmniSpacing.sm;
  static const _padding = OmniSpacing.sm;

  int _columnCount(double width, TextScaler textScaler) {
    final labelSize = OmniType.caption.fontSize ?? 13;
    final scale = (textScaler.scale(labelSize) / labelSize).clamp(1.0, 2.0);
    // 70dp là bề rộng tối thiểu để nhãn Việt hai dòng vẫn quét nhanh. Cộng
    // thêm chỗ theo text scale để cỡ chữ trợ năng chủ động làm lưới thưa ra.
    final minimumCellWidth = 70 + (scale - 1) * 40;
    return ((width + _gap) / (minimumCellWidth + _gap)).floor().clamp(
      1,
      _maxColumns,
    );
  }

  double _tileExtent(TextScaler textScaler) {
    final labelLineHeight =
        textScaler.scale(OmniType.caption.fontSize ?? 13) *
        (OmniType.caption.height ?? 1.4);
    // 16 padding + 44 khung icon/badge + 6 khoảng cách + hai dòng nhãn.
    return 66 + labelLineHeight * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_padding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final columns = _columnCount(constraints.maxWidth, textScaler);
          final tileWidth =
              (constraints.maxWidth - _gap * (columns - 1)) / columns;
          final tileHeight = _tileExtent(textScaler);
          return Wrap(
            key: ValueKey('directory-tile-grid-$firstIndex'),
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (var index = 0; index < tiles.length; index++)
                SizedBox(
                  width: tileWidth,
                  height: tileHeight,
                  child: Builder(
                    builder: (context) {
                      final tile = tiles[index];
                      final id = tile.id ?? tile.label;
                      return _FeatureTile(
                        key: ValueKey(id),
                        tile: tile,
                        animate: !seen.contains(id),
                        index: firstIndex + index,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({
    super.key,
    required this.tile,
    required this.index,
    required this.animate,
  });

  final bool animate;

  final DirectoryTile tile;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Một tông màu cho mọi ô (app liquid glass): nền xanh nhạt, icon màu
    // chính. Chỉ huy hiệu giữ màu riêng vì là tín hiệu.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final toneBackground = scheme.primary.withValues(alpha: dark ? 0.16 : 0.09);
    final badgeProvider = tile.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);

    final badgeLabel = count <= 0
        ? tile.label
        : tile.badgeDisplay == NavBadgeDisplay.dot
        ? '${tile.label}, có tin chưa đọc'
        : '${tile.label}, $count';
    final content = Semantics(
      button: true,
      label: badgeLabel,
      hint: tile.subtitle,
      onTap: tile.onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: OmniRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            tile.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: OmniSpacing.sm,
              horizontal: OmniSpacing.xs,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 58,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: toneBackground,
                          borderRadius: OmniRadius.xlAll,
                        ),
                        child: Icon(tile.icon, size: 20, color: scheme.primary),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: tile.badgeDisplay == NavBadgeDisplay.dot
                              ? const OmniUnreadDot(excludeSemantics: true)
                              : switch (tile.badgeTone) {
                                  NavBadgeTone.unread => OmniCountBadge.unread(
                                    count: count,
                                    ringColor: scheme.surface,
                                  ),
                                  NavBadgeTone.alert => OmniCountBadge.alert(
                                    count: count,
                                    ringColor: scheme.surface,
                                  ),
                                },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _BalancedLabel(
                      tile.label,
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!OmniMotion.enabled(context)) return content;

    return _PopIn(play: animate, delayMs: 50 + 20 * index, child: content);
  }
}

/// Ô hiện dần: scale .85→1 cùng mờ→rõ trong 300ms, trễ theo thứ tự ô.
class _PopIn extends StatefulWidget {
  const _PopIn({
    required this.play,
    required this.delayMs,
    required this.child,
  });

  final bool play;

  final int delayMs;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  static const _animMs = 300;

  AnimationController? _controller;
  late Animation<double> _t;

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.delayMs + _animMs),
      );
      _controller = ctrl;
      _t = CurvedAnimation(
        parent: ctrl,
        curve: Interval(
          widget.delayMs / (widget.delayMs + _animMs),
          1,
          curve: Curves.easeOutCubic,
        ),
      );
      ctrl.forward();
    } else {
      _t = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1).animate(_t),
        child: widget.child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: OmniType.overline.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Khung nhóm: thẻ nền surface, bo 18, KHÔNG viền (cùng nhóm lồng của Tài
/// khoản) — tách khỏi nền xám bằng màu nền, không bằng nét.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Nhãn ô tối đa hai dòng, CÂN nhau: khi phải xuống dòng thì bề ngang thu về
/// cỡ dòng dài nhất, nên "Kênh kết nối" thành "Kênh / kết nối" chứ không rớt
/// một chữ lẻ xuống dòng hai. Nội dung `Text` giữ nguyên (không chèn ký tự xuống
/// dòng).
class _BalancedLabel extends StatelessWidget {
  const _BalancedLabel(this.label, {required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Đo bằng ĐÚNG kiểu chữ mà Text sẽ vẽ (gộp DefaultTextStyle: họ font,
    // cỡ, khoảng chữ). Đo bằng `style` trơn lệch vài px nên khung thu quá hẹp
    // và chữ thứ hai bị cắt "Kênh kết n…".
    final effective = DefaultTextStyle.of(context).style.merge(style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;

        // Bề ngang MỘT dòng (không xuống dòng) của một đoạn chữ.
        double lineWidth(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: effective),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        // Chừa 6px: đo và vẽ có thể lệch nhau vài phần pixel (web).
        const slack = 6.0;
        var width = max;
        // Chỉ xuống dòng khi chữ thật sự không vừa — chừa `slack` ở đây sẽ
        // ép "Tổng quan" (vừa một dòng) thành hai dòng.
        if (lineWidth(label) > max) {
          // Phải xuống dòng: thử từng chỗ ngắt ở dấu cách, chọn chỗ mà dòng
          // dài hơn là ngắn nhất ("Kênh / kết nối", không "Kênh kết / nối").
          // Không chỗ nào vừa (một chữ dài hơn ô) thì để nguyên bề ngang.
          final words = label.split(' ');
          for (var i = 1; i < words.length; i++) {
            final w =
                [
                  lineWidth(words.sublist(0, i).join(' ')),
                  lineWidth(words.sublist(i).join(' ')),
                ].reduce((a, b) => a > b ? a : b) +
                slack;
            if (w <= max && (width == max || w < width)) width = w;
          }
        }

        return SizedBox(
          width: width,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );
      },
    );
  }
}

/// Icon một tông màu cho dòng danh sách (cùng tông với ô lưới).
class _MonoIcon extends StatelessWidget {
  const _MonoIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: dark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: scheme.primary),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.value,
    this.external = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? value;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _MonoIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: OmniType.body.copyWith(color: scheme.onSurface),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (onTap != null)
              Icon(
                external
                    ? Icons.open_in_new_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: row,
    );
  }
}

/// Giao diện đổi ngay tại chỗ: Theo máy · Sáng · Tối.
class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const _MonoIcon(Icons.contrast_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Giao diện',
              style: OmniType.body.copyWith(color: scheme.onSurface),
            ),
          ),
          SizedBox(
            width: 168,
            child: OmniSegmented(
              labels: const ['Máy', 'Sáng', 'Tối'],
              index: _modes.indexOf(mode).clamp(0, 2),
              onChanged: (i) {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).set(_modes[i]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
