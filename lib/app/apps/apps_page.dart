import 'dart:async';

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
import '../shell/tab_icons.dart';
import 'app_manifest.dart';
import 'app_shell_layout.dart';

/// Màn Chọn ứng dụng (quyết định 2026-11-11): tới sau khi mở app, chọn hay đổi
/// công ty. Chỉ những ứng dụng người dùng có quyền và công ty bật.
///
/// Hướng "Quỹ đạo" (duyệt 26/11/2026), gọn trong một màn 390×844: tên công ty
/// có ô chữ viết tắt (chạm để đổi khi có nhiều công ty), lời chào MỘT dòng
/// 26/800 + ngày, thẻ "Hôm nay" chia đều tối đa 3 cột (số mục đang cần xử lý,
/// số đỏ khi > 0), lưới iOS 4 cột ô 58 hiện lần lượt khi mở, ô tìm ghim ở đáy
/// tầm ngón cái; quỹ đạo mờ xoay chậm ở góc trên phải.
///
/// Cũng là điểm rẽ: chỉ MỘT ô thì vào thẳng ô đó; bản khai báo nói tắt (hoặc
/// tải lỗi, API cũ) thì về màn mở đầu cũ.
class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key, this.resume = false});

  /// Mở từ luồng đăng nhập ([landingPath]): vào thẳng ứng dụng dùng lần trước
  /// nếu còn trong lưới. Mở bằng nút lưới thì không — người dùng muốn chọn.
  final bool resume;

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage>
    with SingleTickerProviderStateMixin {
  bool _leaving = false;

  /// Từ khoá ô "Tìm ứng dụng hoặc màn" (bỏ dấu, tại chỗ).
  String _q = '';

  /// Nhịp hiện lần lượt khi mở: lời chào, thẻ Hôm nay, rồi từng ô ứng dụng.
  late final AnimationController _entrance = AnimationController(vsync: this);
  bool _entered = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _leave(String Function() target) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(target());
    });
  }

  /// Chạy nhịp hiện một lần, sau khung đầu có lưới (không chạy giữa lúc dựng).
  void _enter(int tiles) {
    if (_entered) return;
    _entered = true;
    _entrance.duration = _Entrance.total(tiles);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward(from: 0);
    });
  }

  String _pathOf(ShellApp app, ShellItem item) {
    ref.read(currentAppKeyProvider.notifier).state = app.key;
    unawaited(ref.read(lastAppStoreProvider).write(app.key));
    final name = appTabRouteName(
      item.entry.routeName,
      ref.read(appTabCloneRoutesProvider),
    );
    return GoRouter.of(context).namedLocation(name);
  }

  String _entryPath(ShellApp app) => _pathOf(app, app.first!);

  /// Ứng dụng dùng lần trước nếu vẫn còn trong lưới và mở được.
  static ShellApp? _lastApp(List<ShellApp> entries, String? key) {
    if (key == null) return null;
    for (final app in entries) {
      if (app.key == key && app.first != null) return app;
    }
    return null;
  }

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

    final resumeApp = widget.resume && ready
        ? _lastApp(entries, ref.read(lastAppStoreProvider).read())
        : null;
    if (ready && entries.isEmpty) {
      _leave(() => legacyLandingPath(ref.read));
    } else if (ready && entries.length == 1) {
      _leave(() => _entryPath(entries.single));
    } else if (resumeApp != null) {
      _leave(() => _entryPath(resumeApp));
    }
    final showGrid = ready && entries.length > 1 && resumeApp == null;

    // Bàn làm việc là ô ĐẦU của lưới (bản duyệt giống web).
    final apps = [
      ...entries.where((a) => a.key == homeAppKey),
      ...entries.where((a) => a.key != homeAppKey),
    ];
    if (showGrid) _enter(apps.length);
    // Giảm chuyển động: mọi thứ hiện ngay, không chờ nhịp.
    final Animation<double> entrance = OmniMotion.enabled(context)
        ? _entrance
        : kAlwaysCompleteAnimation;

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
                builder: (context) {
                  final searching = _q.trim().isNotEmpty;
                  return Stack(
                    children: [
                      const _CornerOrbit(),
                      Positioned.fill(
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                  OmniSpacing.lg,
                                  OmniTopBarOverlap.of(context) + 4,
                                  OmniSpacing.lg,
                                  16,
                                ),
                                children: [
                                  _Centered(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _Rise(
                                          animation: entrance,
                                          interval: _Entrance.at(0, 0),
                                          child: const _AppsGreeting(),
                                        ),
                                        const SizedBox(height: 16),
                                        if (searching)
                                          _SearchResults(
                                            query: _q,
                                            apps: apps,
                                            onOpen: _open,
                                            onOpenItem: _openItem,
                                          )
                                        else ...[
                                          _Rise(
                                            animation: entrance,
                                            interval: _Entrance.at(120, 0),
                                            child: _TodayCard(
                                              apps: entries,
                                              onOpen: _openItem,
                                            ),
                                          ),
                                          _AppGrid(
                                            apps: apps,
                                            onOpen: _open,
                                            entrance: entrance,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Ô tìm ghim ở đáy, tầm ngón cái; bàn phím bật thì
                            // nổi ngay trên bàn phím (Scaffold co thân màn).
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                OmniSpacing.lg,
                                8,
                                OmniSpacing.lg,
                                MediaQuery.paddingOf(context).bottom + 12,
                              ),
                              child: _Centered(
                                child: OmniSearchBottom(
                                  fieldKey: const ValueKey('apps-search'),
                                  hint: 'Tìm ứng dụng hoặc màn…',
                                  debounce: const Duration(milliseconds: 150),
                                  onChanged: (v) => setState(() => _q = v),
                                ),
                              ),
                            ),
                          ],
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

/// Cột rộng tối đa 560, căn giữa (máy tính bảng).
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  );
}

/// Mốc của nhịp hiện lần lượt (bản duyệt: ô thứ i trễ .25 + i × .05 giây,
/// mỗi ô .55 giây).
abstract final class _Entrance {
  static const _tileStartMs = 250;
  static const _tileStepMs = 50;
  static const _lengthMs = 550;

  static Duration total(int tiles) => Duration(
    milliseconds:
        _tileStartMs + _tileStepMs * (tiles > 0 ? tiles - 1 : 0) + _lengthMs,
  );

  /// Đoạn của một phần tử bắt đầu ở [startMs] (+ [index] bước ô) trên tổng.
  static ({int start, int index}) at(int startMs, int index) =>
      (start: startMs, index: index);

  static Interval interval(({int start, int index}) at, Duration total) {
    final ms = total.inMilliseconds.toDouble();
    if (ms <= 0) return const Interval(0, 1);
    final from = (at.start + _tileStepMs * at.index) / ms;
    final to = (at.start + _tileStepMs * at.index + _lengthMs) / ms;
    return Interval(from.clamp(0.0, 1.0), to.clamp(0.0, 1.0));
  }

  /// Nảy nhẹ — `cubic-bezier(.2,.9,.3,1.3)`.
  static const Curve pop = Cubic(0.2, 0.9, 0.3, 1.3);
}

/// Một phần tử nổi lên theo nhịp hiện: trượt lên 12, hơi phóng từ .9, hiện dần.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.interval,
    required this.child,
    this.scale = false,
  });

  final Animation<double> animation;
  final ({int start, int index}) interval;
  final Widget child;
  final bool scale;

  @override
  Widget build(BuildContext context) {
    final controller = animation;
    final total = controller is AnimationController
        ? controller.duration ?? Duration.zero
        : Duration.zero;
    final window = _Entrance.interval(interval, total);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final linear = window.transform(controller.value);
        final e = _Entrance.pop.transform(linear);
        return Opacity(
          opacity: e.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - e)),
            child: scale
                ? Transform.scale(scale: 0.9 + 0.1 * e, child: child)
                : child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Quỹ đạo mờ (.45) xoay chậm ở góc trên phải, sau mọi nội dung, không logo.
class _CornerOrbit extends StatelessWidget {
  const _CornerOrbit();

  static const double _scale = 0.9;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    const w = 400 * _scale;
    const h = 200 * _scale;
    return Positioned(
      // Tâm cách mép phải 40, ngang tên công ty / lời chào.
      top: top + 60 - h / 2,
      right: 40 - w / 2,
      child: const IgnorePointer(
        child: ExcludeSemantics(
          child: OmniOrbit(
            scale: _scale,
            showLogo: false,
            opacity: 0.45,
            spin: true,
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

/// Tên công ty: ô chữ viết tắt 30 bo 9 + tên + ⌄ (⌄ chỉ khi đổi được).
class _CompanyButton extends StatelessWidget {
  const _CompanyButton({required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  /// "Công ty Sao Mai" → "SM": bỏ tiền tố loại hình, lấy chữ đầu hai từ.
  static String initials(String name) {
    var words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length > 2 &&
        words[0].toLowerCase() == 'công' &&
        words[1].toLowerCase() == 'ty') {
      words = words.sublist(2);
    }
    return words.take(2).map((w) => w.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            initials(name),
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Cỡ chữ lấy từ OmniType (luật: không đặt cỡ thô ngoài lib/design).
            style: OmniType.body.copyWith(
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronDown,
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

/// Lời chào theo buổi MỘT dòng 26/800 căn trái + ngày 14 xám (bản "Quỹ đạo").
/// Tên dài thì thu chữ cho vừa một dòng, không cắt "…".
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          // Không FittedBox: chữ to (1,3× / 200%) phải giữ cỡ, xuống dòng.
          child: Text(
            greeting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OmniOrbitType.greeting.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
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
  // Nhân sự chưa từng được khai: rơi vào mặc định (lưới 4 ô, xanh) trông như
  // nút "Tất cả" và trùng màu Bàn làm việc.
  'hr' => OmniHue.sky,
  'system' => OmniHue.neutral,
  _ => OmniHue.blue,
};

IconData _iconOf(String key) => switch (key) {
  homeAppKey => LucideIcons.monitor,
  'sales' => LucideIcons.shoppingBag,
  'stock' => LucideIcons.package,
  'work' => LucideIcons.squareKanban,
  'finance' => LucideIcons.wallet,
  'hr' => LucideIcons.users,
  'system' => LucideIcons.settings,
  _ => LucideIcons.layoutGrid,
};

/// Icon ĐẶC (Phosphor Fill, cùng bộ với thanh tab) cho ô ứng dụng của lưới.
IconData _glyphOf(String key) => switch (key) {
  homeAppKey => OmniFillIcons.desktop,
  'sales' => OmniFillIcons.shoppingBag,
  'stock' => OmniFillIcons.package,
  'work' => OmniFillIcons.kanban,
  'finance' => OmniFillIcons.wallet,
  'hr' => OmniFillIcons.usersThree,
  'system' => OmniFillIcons.gearSix,
  _ => OmniFillIcons.squaresFour,
};

String _descOf(ShellApp app) => switch (app.key) {
  homeAppKey => 'Việc cần làm, lịch nhắc',
  'sales' => 'Hộp thư, khách, đơn hàng',
  'stock' => 'Lô, tồn kho, kiểm kê',
  'work' => 'Dự án, tài liệu',
  'finance' => 'Chi phí, tiền hàng lô',
  'hr' => 'Công tháng, đơn từ, thưởng đội',
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

/// Ô ứng dụng kiểu màn hình chính iOS: 58 bo 16, nền màu ĐẶC dải trên → dưới
/// theo tông, lớp sáng mảnh ở nửa trên, icon đặc trắng. Tương phản cao: thêm
/// viền mực.
class _SolidAppIcon extends StatelessWidget {
  const _SolidAppIcon({required this.icon, required this.hue});

  final IconData icon;
  final OmniHue hue;

  static const double size = 58;
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = OmniFeatureTones.solid(hue);
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        border: contrast
            ? Border.all(color: Theme.of(context).colorScheme.onSurface)
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .22),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .45],
        ),
      ),
      child: Icon(icon, size: 28, color: Colors.white),
    );
  }
}

/// Lưới kiểu màn hình chính iOS (duyệt 26/11/2026): 4 cột (màn hẹp / chữ
/// phóng to thì 3), ô 58 màu đặc + icon trắng, chỉ tên (≤ 2 dòng, không "…"),
/// đặt thẳng trên nền; mô tả vẫn tìm được qua ô tìm. Bàn làm việc là ô đầu,
/// chấm đỏ góc ô khi có việc. Các ô hiện lần lượt khi mở.
class _AppGrid extends StatelessWidget {
  const _AppGrid({
    required this.apps,
    required this.onOpen,
    required this.entrance,
  });

  final List<ShellApp> apps;
  final ValueChanged<ShellApp> onOpen;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = box.maxWidth < 300 || scale > 1.35 ? 3 : 4;
        // Làm tròn xuống để 4 ô không dư lẻ pixel mà bị Wrap đẩy xuống hàng.
        final width = (box.maxWidth / columns).floorToDouble();
        return Wrap(
          runSpacing: 20,
          children: [
            for (var i = 0; i < apps.length; i++)
              SizedBox(
                width: width,
                child: _Rise(
                  animation: entrance,
                  interval: _Entrance.at(_Entrance._tileStartMs, i),
                  scale: true,
                  child: _AppTile(
                    key: ValueKey('app-tile-${apps[i].key}'),
                    app: apps[i],
                    onTap: () => onOpen(apps[i]),
                  ),
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
                  _SolidAppIcon(icon: _glyphOf(app.key), hue: _hueOf(app.key)),
                  // Chấm đỏ "cần chú ý" (duyệt 26/11/2026): không ghi số.
                  if (alert > 0 || unread)
                    const Positioned(
                      top: -3,
                      right: -3,
                      child: OmniUnreadDot(size: 12, excludeSemantics: true),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  app.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: OmniType.micro.copyWith(
                    height: 1.25,
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

/// Thẻ "Hôm nay" (thay mục "Cần chú ý"): các mục có huy hiệu "cần xử lý",
/// chia đều tối đa 3 cột — số 24/800 (đỏ khi > 0) + tên mục 12 xám; mục đang
/// có việc lên trước. Chạm một cột là vào thẳng mục đó. Không có mục nào có
/// huy hiệu thì ẩn thẻ.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.apps, required this.onOpen});

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
        rows.add((app, item, ref.watch(badge)));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = [
      ...rows.where((r) => r.$3 > 0),
      ...rows.where((r) => r.$3 <= 0),
    ].take(3).toList();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: MediaQuery.highContrastOf(context)
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  VerticalDivider(
                    width: 0.5,
                    thickness: 0.5,
                    color: scheme.outlineVariant,
                  ),
                Expanded(
                  child: _TodayCell(row: shown[i], onOpen: onOpen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCell extends StatelessWidget {
  const _TodayCell({required this.row, required this.onOpen});

  final (ShellApp, ShellItem, int) row;
  final void Function(ShellApp app, ShellItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (app, item, n) = row;
    return Semantics(
      button: true,
      label: '${item.entry.label}, ${app.name}, $n',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('app-todo-${item.key}'),
        onTap: () => onOpen(app, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$n',
                style: OmniOrbitType.stat.copyWith(
                  color: n > 0
                      ? OmniColors.attentionOf(context)
                      : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.entry.label,
                maxLines: 2,
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
