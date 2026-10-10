import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../core/utils/text_search.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';
import '../../modules/settings/settings_module.dart';

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
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final OmniHue hue;
  final VoidCallback onTap;
  final ProviderListenable<int>? badge;
  final NavBadgeTone badgeTone;
}

typedef DirectorySection = ({String label, List<DirectoryTile> tiles});

/// Sắc ô icon theo khu — `All.dc.html`.
OmniHue hueOfArea(NavArea area) => switch (area) {
  NavArea.communication => OmniHue.teal,
  NavArea.sales => OmniHue.orange,
  NavArea.work => OmniHue.blue,
  NavArea.admin => OmniHue.violet,
  NavArea.account => OmniHue.neutral,
};

/// Gom mục của module thành bốn nhóm theo bản mẫu và lọc theo từ khoá. Nhóm
/// rỗng bị bỏ, để không còn tiêu đề trơ trọi.
List<DirectorySection> buildDirectorySections(
  Map<NavArea, List<ModuleNavEntry>> groups, {
  required List<DirectoryTile> personal,
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
  );
  List<DirectoryTile> of(List<NavArea> areas) => [
    for (final a in areas) ...?groups[a]?.map(fromEntry),
  ];
  bool keep(DirectoryTile t) =>
      matchesQuery(label: t.label, subtitle: t.subtitle, query: query);

  final raw = <(String, List<DirectoryTile>)>[
    ('Bán hàng', of([NavArea.communication, NavArea.sales])),
    ('Công việc', of([NavArea.work])),
    ('Đội & quản trị', of([NavArea.admin])),
    (
      'Cá nhân',
      [
        ...of([NavArea.account]),
        ...personal,
      ],
    ),
  ];

  return [
    for (final (label, tiles) in raw)
      if (tiles.where(keep).toList() case final kept when kept.isNotEmpty)
        (label: label, tiles: kept),
  ];
}

/// Danh bạ "Tất cả": MỌI tính năng người dùng có quyền dùng, gom theo nhóm,
/// tìm được bằng từ khoá (không cần gõ dấu).
///
/// Không có gì viết cứng theo module — module khai báo mục, registry lọc theo
/// quyền và cờ tính năng, màn này dựng bất cứ thứ gì nhận được. Hồ sơ, không
/// gian làm việc, giao diện, pháp lý, đăng xuất và xoá tài khoản nằm ở màn
/// Tài khoản; ở đây chỉ có ô lối vào.
class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _query = '';

  Future<void> _openSupport() async {
    // Chụp trước khi await: màn có thể đã bị đóng khi trình duyệt trả về.
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        AppConfig.supportUrl,
        mode: LaunchMode.externalApplication,
      );
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
      personal: [
        DirectoryTile(
          label: 'Tài khoản',
          icon: Icons.person_outline_rounded,
          hue: OmniHue.neutral,
          onTap: () => context.pushNamed(SettingsModule.account),
        ),
        DirectoryTile(
          label: 'Giao diện',
          subtitle: 'Sáng tối',
          icon: Icons.light_mode_outlined,
          hue: OmniHue.neutral,
          onTap: () => context.pushNamed(SettingsModule.account),
        ),
        DirectoryTile(
          label: 'Hỗ trợ',
          subtitle: 'Liên hệ hỗ trợ',
          icon: Icons.help_outline_rounded,
          hue: OmniHue.neutral,
          onTap: _openSupport,
        ),
      ],
      open: (name) => context.pushNamed(name),
      query: _query,
    );
    final scheme = Theme.of(context).colorScheme;
    // Chỉ số hoạt ảnh chạy liên tục qua các nhóm.
    final starts = <int>[];
    var running = 0;
    for (final s in sections) {
      starts.add(running);
      running += s.tiles.length;
    }

    return Scaffold(
      appBar: OmniTopBar(
        semanticsTitle: 'Tất cả',
        bottom: _SearchBottom(
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.xl,
              14,
              OmniSpacing.xl,
              OmniSpacing.bottomSafe,
            ),
            children: [
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'Không tìm thấy tính năng “$_query”',
                    textAlign: TextAlign.center,
                    style: OmniType.body.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final section in sections) ...[
                if (section != sections.first) const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      section.label,
                      style: OmniType.overline.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                _TileGrid(
                  tiles: section.tiles,
                  firstIndex: starts[sections.indexOf(section)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô tìm dưới thanh trên: cao 36, đệm `16, 0, 16, 10`.
class _SearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBottom({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 36,
        child: OmniSearchField(
          hint: 'Tìm tính năng…',
          outlined: true,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Lưới 4 cột trong một thẻ. Dựng bằng hàng chứ không bằng GridView: ô phải
/// cao bằng nhau theo ô có nhãn dài nhất trong hàng, và nhãn tiếng Việt hay
/// xuống hai dòng.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles, required this.firstIndex});

  final List<DirectoryTile> tiles;
  final int firstIndex;

  static const _columns = 4;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += _columns) {
      final slice = tiles.skip(i).take(_columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < _columns; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(
                  child: c < slice.length
                      ? _FeatureTile(
                          key: ValueKey(slice[c].label),
                          tile: slice[c],
                          index: firstIndex + i + c,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              rows[r],
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends ConsumerWidget {
  const _FeatureTile({super.key, required this.tile, required this.index});

  final DirectoryTile tile;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tone = OmniFeatureTones.of(context, tile.hue);
    final badgeProvider = tile.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);

    final content = Semantics(
      button: true,
      label: count > 0 ? '${tile.label}, $count' : tile.label,
      hint: tile.subtitle,
      onTap: tile.onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: OmniRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tile.onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone.background,
                        borderRadius: OmniRadius.xlAll,
                      ),
                      child: Icon(tile.icon, size: 20, color: tone.foreground),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tile.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 12,
                  child: switch (tile.badgeTone) {
                    NavBadgeTone.unread => OmniCountBadge.unread(count: count),
                    NavBadgeTone.alert => OmniCountBadge.alert(count: count),
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (!OmniMotion.enabled(context)) return content;

    return _PopIn(delayMs: 50 + 20 * index, child: content);
  }
}

/// Ô hiện dần: scale .85→1 cùng mờ→rõ trong 300ms, trễ theo thứ tự ô.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  static const _animMs = 300;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.delayMs + _animMs),
  )..forward();

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delayMs / (widget.delayMs + _animMs),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
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
