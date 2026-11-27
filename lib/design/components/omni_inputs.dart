import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../platform/omni_motion_scope.dart';
import '../platform/omni_platform.dart';
import '../tokens/tokens.dart';
import 'omni_tinted_buttons.dart';
import 'omni_glass.dart';

/// Debounced search field. Debouncing lives here rather than in each screen so
/// no list ever fires a request per keystroke.
class OmniSearchField extends StatefulWidget {
  const OmniSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Tìm kiếm...',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.trailing,
    this.outlined = false,
    this.flat = false,
    this.dense = false,
    this.autofocus = false,
    this.onSubmitted,
    this.value,
    this.onCover = false,
    this.hints,
  });

  final ValueChanged<String> onChanged;

  /// Gợi ý quay vòng trong ô như máy đánh số (kiểu "Biến hình", duyệt
  /// 26/11/2026): mỗi ~2,2 s lăn lên gợi ý kế tiếp. `null` hoặc chỉ 1 mục =
  /// gợi ý tĩnh [hint]. Dừng quay khi ô đang focus hoặc giảm chuyển động.
  final List<String>? hints;

  /// Ô nằm trên ảnh bìa (đầu Bảng kế hoạch): viên kính trắng mờ, chữ và icon
  /// trắng. Tương phản cao thì viên đặc ([OmniCovers.glass]).
  final bool onCover;

  /// Giá trị từ nơi giữ trạng thái (provider bộ lọc). Có thì ô là ô "có điều
  /// khiển": khi [value] đổi thành thứ khác chữ ô vừa gửi đi (bộ lọc bị đặt
  /// lại, quyền đổi) thì ô theo [value] và huỷ lượt gõ đang chờ. `null` = ô tự
  /// giữ chữ, khởi đầu bằng [initialValue].
  final String? value;

  /// Kiểu có đường biên dùng trong biểu mẫu khi ranh giới nhập liệu phải rõ.
  /// Thanh tìm của màn danh sách dùng [flat] thay vì kiểu này.
  final bool outlined;

  /// Ô tìm nằm ngay trên cùng một mặt phẳng với nội dung: không nền, không
  /// viền. Chỉ dùng cho thanh tìm của màn danh sách; ô nhập trong form vẫn cần
  /// khung để nhận biết ranh giới dữ liệu.
  final bool flat;

  /// Gọn mắt nhưng vẫn cao 44 (vùng chạm): đệm dọc nhỏ, icon 36.
  final bool dense;
  final String hint;
  final String? initialValue;

  /// Chờ ngừng gõ bao lâu mới gửi. `Duration.zero` = gửi ngay theo từng phím
  /// (lọc tại chỗ trên danh sách đã tải, không gọi mạng).
  final Duration debounce;
  final Widget? trailing;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OmniSearchField> createState() => _OmniSearchFieldState();
}

class _OmniSearchFieldState extends State<OmniSearchField> {
  OutlineInputBorder _border(ColorScheme scheme) => widget.outlined
      ? OutlineInputBorder(
          borderRadius: OmniRadius.lgAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        )
      : const OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide.none,
        );

  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? widget.initialValue,
  );
  Timer? _timer;

  /// Ô đang focus — chỉ dùng để dừng gợi ý quay.
  bool _focused = false;

  List<String>? get _rollingHints {
    final h = widget.hints;
    return h != null && h.length > 1 ? h : null;
  }

  /// Chữ ô đã gửi lên gần nhất (chế độ có điều khiển). Gán trong [initState]
  /// — KHÔNG dùng `late` có biểu thức khởi tạo: lần đọc đầu tiên rơi vào
  /// [didUpdateWidget], lúc `widget` đã là widget MỚI, và giá trị mới bị coi
  /// là "đã gửi" nên ô không theo.
  late String _sent;

  @override
  void initState() {
    super.initState();
    _sent = (widget.value ?? widget.initialValue ?? '').trim();
  }

  @override
  void didUpdateWidget(OmniSearchField old) {
    super.didUpdateWidget(old);
    final v = widget.value;
    if (v != null && v != old.value && v != _sent) {
      // Bị đặt từ nơi khác: huỷ lượt gõ đang chờ (không thì hẹn giờ cũ đặt
      // lại chữ vừa bị xoá) và cho ô theo giá trị mới.
      _timer?.cancel();
      _sent = v;
      if (_controller.text != v) _controller.text = v;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emit(String value) {
    _sent = value;
    widget.onChanged(value);
  }

  void _onChanged(String value) {
    _timer?.cancel();
    // Viền cầu vồng của khung ô tìm (nếu có) chạy trong lúc chờ gửi: tối
    // thiểu ~650ms, hoặc hết thời gian debounce (duyệt 26/11/2026).
    if (value.trim().isNotEmpty) {
      final wait = widget.debounce > _busyMin ? widget.debounce : _busyMin;
      OmniSearchFrame._pulse(context, wait);
    }
    if (widget.debounce == Duration.zero) {
      _emit(value.trim());
      setState(() {});
      return;
    }
    _timer = Timer(widget.debounce, () {
      if (mounted) _emit(value.trim());
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onCover = widget.onCover;
    final ink = onCover ? Colors.white : scheme.onSurface;
    final muted = onCover
        ? Colors.white.withValues(alpha: .82)
        : scheme.onSurfaceVariant;
    final coverBorder = OutlineInputBorder(
      borderRadius: OmniRadius.pillAll,
      borderSide: BorderSide(color: Colors.white.withValues(alpha: .36)),
    );

    final rolling = _rollingHints;
    final hintStyle = OmniType.searchHint.copyWith(color: muted);

    // Center: nơi gọi hay ép ô cao đúng 44 (hàng `stretch`, viên kính). Bị ép
    // thì ô nhập dồn nội dung lên mép trên — với phông thật (dòng cao hơn
    // phông thử) kính lúp và chữ lệch lên ~3px trong viên kính. Center để ô
    // giữ chiều cao tự nhiên và nằm đúng giữa khung.
    final field = TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: _onChanged,
      onSubmitted: widget.onSubmitted == null
          ? null
          : (value) {
              _timer?.cancel();
              _sent = value.trim();
              widget.onSubmitted!(value.trim());
            },
      textInputAction: TextInputAction.search,
      cursorColor: onCover ? Colors.white : null,
      style: OmniType.search.copyWith(color: ink, fontStyle: FontStyle.normal),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: rolling == null ? widget.hint : null,
        hint: rolling == null
            ? null
            : _RollingHint(hints: rolling, style: hintStyle, paused: _focused),
        hintStyle: hintStyle,
        prefixIcon: Icon(
          LucideIcons.search,
          color: muted,
          size: OmniIconSize.lg,
        ),
        prefixIconConstraints: widget.dense || onCover
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : null,
        suffixIconConstraints: widget.dense || onCover
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : null,
        suffixIcon: _controller.text.isEmpty
            ? widget.trailing
            : IconButton(
                padding: widget.dense || onCover ? EdgeInsets.zero : null,
                constraints: widget.dense || onCover
                    ? const BoxConstraints(minWidth: 36, minHeight: 36)
                    : null,
                tooltip: 'Xoá tìm kiếm',
                icon: Icon(LucideIcons.x, size: OmniIconSize.md, color: muted),
                onPressed: () {
                  _timer?.cancel();
                  _controller.clear();
                  _emit('');
                  setState(() {});
                },
              ),
        isDense: true,
        // Đệm 12 cho cả bản dense: 12 + dòng 20 + 12 = đúng 44, khớp viên kính
        // / hàng ép vào. Đệm 10 thì nội dung chỉ cao 40, nằm sát mép trên khung
        // 44 → kính lúp và chữ lệch lên 2px (thấy rõ trên viên kính).
        // Trên ảnh bìa: viên 38 (9 + 20 + 9) nằm giữa hàng nút 44.
        contentPadding: EdgeInsets.symmetric(vertical: onCover ? 9 : 12),
        filled: onCover || !widget.flat,
        fillColor: onCover
            ? (MediaQuery.highContrastOf(context)
                  ? OmniCovers.glass
                  : Colors.white.withValues(alpha: .20))
            : widget.flat
            ? Colors.transparent
            : widget.outlined
            ? scheme.surface
            : scheme.surfaceContainerHighest,
        border: onCover
            ? coverBorder
            : widget.flat
            ? InputBorder.none
            : _border(scheme),
        enabledBorder: onCover
            ? coverBorder
            : widget.flat
            ? InputBorder.none
            : _border(scheme),
        focusedBorder: onCover
            ? coverBorder
            : !widget.flat && widget.outlined
            ? OutlineInputBorder(
                borderRadius: OmniRadius.lgAll,
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: .55),
                  width: 1.5,
                ),
              )
            : widget.flat
            ? InputBorder.none
            : _border(scheme),
      ),
    );

    return Center(
      child: rolling == null
          ? field
          // Chỉ nghe focus khi có gợi ý quay (để dừng quay lúc đang gõ).
          : Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: (f) {
                if (f != _focused && mounted) setState(() => _focused = f);
              },
              child: field,
            ),
    );
  }
}

/// Thời gian tối thiểu viền cầu vồng chạy sau một phím gõ.
const Duration _busyMin = Duration(milliseconds: 650);

/// Gợi ý quay như máy đánh số: gợi ý cũ lăn lên, gợi ý mới lăn từ dưới lên,
/// có nảy nhẹ (cubic-bezier(.2,.9,.3,1.25) của bản duyệt). Giảm chuyển động
/// hoặc [paused]: đứng yên ở gợi ý đang hiện.
class _RollingHint extends StatefulWidget {
  const _RollingHint({
    required this.hints,
    required this.style,
    required this.paused,
  });

  final List<String> hints;
  final TextStyle style;
  final bool paused;

  @override
  State<_RollingHint> createState() => _RollingHintState();
}

class _RollingHintState extends State<_RollingHint> {
  static const _every = Duration(milliseconds: 2200);
  static const _roll = Duration(milliseconds: 550);

  Timer? _timer;
  int _i = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(_RollingHint old) {
    super.didUpdateWidget(old);
    if (old.paused != widget.paused ||
        old.hints.length != widget.hints.length) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (widget.paused ||
        widget.hints.length < 2 ||
        !OmniMotion.enabled(context)) {
      return;
    }
    _timer = Timer.periodic(_every, (_) {
      if (mounted) setState(() => _i = (_i + 1) % widget.hints.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = _i % widget.hints.length;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: OmniMotion.enabled(context) ? _roll : Duration.zero,
        switchInCurve: const Cubic(0.2, 0.9, 0.3, 1.25),
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          // Mục mới lăn từ dưới lên; mục cũ (chạy ngược 1→0) lăn lên trên.
          final incoming = child.key == ValueKey<int>(i);
          return SlideTransition(
            position: Tween<Offset>(
              begin: incoming ? const Offset(0, 1) : const Offset(0, -1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: Text(
          widget.hints[i],
          key: ValueKey<int>(i),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        ),
      ),
    );
  }
}

/// Khung ô tìm kiểu "Biến hình" (duyệt 26/11/2026, rà soát mục 18): nền xám
/// đặc bo [radius]; vầng sáng xanh mảnh khi ô bên trong có focus; viền chạy
/// vòng cầu vồng (xanh → tím → đỏ → vàng → xanh lá) trong lúc ô
/// [OmniSearchField] bên trong đang gõ / chờ gửi. Giảm chuyển động: vầng sáng
/// và viền hiện/tắt thẳng, viền không xoay.
class OmniSearchFrame extends StatefulWidget {
  const OmniSearchFrame({
    super.key,
    required this.child,
    this.radius = 10,
    this.color,
  });

  final Widget child;
  final double radius;

  /// Nền ô; null = mực 12% (tối) / 6% (sáng).
  final Color? color;

  /// Đang nằm trong một khung ô tìm — ô con không vẽ khung lần hai.
  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_OmniSearchScope>() != null;

  /// Báo khung gần nhất "đang tìm" trong [wait]. Không có khung thì thôi.
  static void _pulse(BuildContext context, Duration wait) => context
      .getInheritedWidgetOfExactType<_OmniSearchScope>()
      ?.state
      ._busyFor(wait);

  @override
  State<OmniSearchFrame> createState() => _OmniSearchFrameState();
}

class _OmniSearchFrameState extends State<OmniSearchFrame>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  bool _busy = false;
  Timer? _busyTimer;
  AnimationController? _spin;

  void _busyFor(Duration wait) {
    if (!mounted) return;
    _busyTimer?.cancel();
    if (!_busy) setState(() => _busy = true);
    _syncSpin();
    _busyTimer = Timer(wait, () {
      if (!mounted) return;
      setState(() => _busy = false);
      _syncSpin();
    });
  }

  void _syncSpin() {
    if (_busy && OmniMotion.enabled(context)) {
      final spin = _spin ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
      if (!spin.isAnimating) spin.repeat();
    } else {
      _spin?.stop();
    }
  }

  @override
  void dispose() {
    _busyTimer?.cancel();
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final motion = OmniMotion.enabled(context);
    final radius = BorderRadius.circular(widget.radius);
    final glow = OmniColors.primaryFillOf(context).withValues(alpha: .25);
    final fade = motion ? const Duration(milliseconds: 300) : Duration.zero;

    final box = AnimatedContainer(
      duration: fade,
      decoration: BoxDecoration(
        color:
            widget.color ??
            scheme.onSurface.withValues(alpha: dark ? .12 : .06),
        borderRadius: radius,
        border: MediaQuery.highContrastOf(context)
            ? Border.all(color: scheme.outline)
            : null,
        // Vầng sáng xanh mảnh 3dp khi focus (box-shadow 0 0 0 4px .25).
        boxShadow: _focused
            ? [BoxShadow(color: glow, spreadRadius: 3)]
            : const <BoxShadow>[],
      ),
      child: widget.child,
    );

    return _OmniSearchScope(
      state: this,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) {
          if (f != _focused && mounted) setState(() => _focused = f);
        },
        child: Stack(
          children: [
            box,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const Key('omni-search-busy-ring'),
                  opacity: _busy ? 1 : 0,
                  duration: fade,
                  child: CustomPaint(
                    painter: _RainbowRingPainter(
                      radius: widget.radius,
                      turns: _spin,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OmniSearchScope extends InheritedWidget {
  const _OmniSearchScope({required this.state, required super.child});

  final _OmniSearchFrameState state;

  @override
  bool updateShouldNotify(_OmniSearchScope oldWidget) =>
      state != oldWidget.state;
}

/// Viền 2dp tô SweepGradient cầu vồng, xoay theo [turns] (0..1 = một vòng).
class _RainbowRingPainter extends CustomPainter {
  _RainbowRingPainter({required this.radius, required this.color, this.turns})
    : super(repaint: turns);

  final double radius;
  final Animation<double>? turns;

  /// Một màu nhấn (đuôi mờ dần) — không còn vòng 5 màu ngoài token.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
        transform: GradientRotation((turns?.value ?? 0) * 2 * math.pi),
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1),
        Radius.circular(math.max(0, radius - 1)),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RainbowRingPainter old) =>
      old.radius != radius || old.turns != turns || old.color != color;
}

/// Nút lọc trong ô tìm (duyệt 26/11/2026, rà soát mục 6): chưa lọc = icon
/// sliders XÁM (`onSurfaceVariant`); đang lọc = viên đặc `onSurface` (mực ở
/// chế độ sáng, trắng ở tối) chữ `surface` kèm số bộ lọc đang bật. Vùng chạm
/// tối thiểu 44.
class OmniSearchFilterButton extends StatelessWidget {
  const OmniSearchFilterButton({
    super.key,
    required this.onPressed,
    this.activeFilters,
    this.semanticsLabel,
    this.open,
    this.countKey,
  });

  final VoidCallback? onPressed;

  /// Số bộ lọc đang bật; null hoặc 0 = chưa lọc.
  final int? activeFilters;

  /// Nhãn trình đọc màn hình; null = "Lọc" / "Lọc · đang bật N".
  final String? semanticsLabel;

  /// Bảng lọc đang mở (trình đọc màn hình đọc "đã mở rộng"); null = không báo.
  final bool? open;

  /// Key cho viên đếm (bài kiểm tìm theo key).
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = activeFilters ?? 0;
    final label = semanticsLabel ?? (n > 0 ? 'Lọc · đang bật $n' : 'Lọc');
    final Widget face = n > 0
        ? Container(
            key: countKey,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.onSurface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  size: 14,
                  color: scheme.surface,
                ),
                const SizedBox(width: 4),
                Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: scheme.surface,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ),
          )
        : Icon(
            LucideIcons.slidersHorizontal,
            size: OmniIconSize.md,
            color: open == true ? scheme.onSurface : scheme.onSurfaceVariant,
          );

    return Semantics(
      button: true,
      label: label,
      expanded: open,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
            maxHeight: 44,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onPressed,
              radius: 22,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              child: Center(widthFactor: 1, child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô tìm cao 44 dùng thống nhất làm `bottom` của [OmniAppBar]: nền xám đặc bo
/// 10, không viên kính (spec phong cách iOS §3.4) — cùng dáng ô tìm của
/// [OmniTopBar]. [trailing] nằm trong ô, bên phải (vd nút lọc xanh).
class OmniSearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const OmniSearchBottom({
    super.key,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.onSubmitted,
    this.trailing,
    this.hints,
    this.onFilter,
    this.activeFilters,
    this.filterKey,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final Widget? trailing;

  /// Gợi ý quay vòng (xem [OmniSearchField.hints]); null = [hint] tĩnh.
  final List<String>? hints;

  /// Có thì trong ô có nút lọc [OmniSearchFilterButton] (khi không truyền
  /// [trailing]).
  final VoidCallback? onFilter;

  /// Số bộ lọc đang bật — nút lọc thành viên đặc có số (rà soát mục 6).
  final int? activeFilters;

  /// Key của nút lọc.
  final Key? filterKey;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final end =
        trailing ??
        (onFilter == null
            ? null
            : OmniSearchFilterButton(
                key: filterKey,
                onPressed: onFilter,
                activeFilters: activeFilters,
              ));
    final content = SizedBox(
      height: 44,
      child: Padding(
        padding: EdgeInsets.only(left: 6, right: end == null ? 6 : 0),
        child: Row(
          children: [
            Expanded(
              child: OmniSearchField(
                key: fieldKey,
                hint: hint,
                hints: hints,
                initialValue: initialValue,
                debounce: debounce,
                flat: true,
                dense: true,
                autofocus: autofocus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            ?end,
          ],
        ),
      ),
    );
    // Đã nằm trong khung ô tìm của thanh trên: không vẽ nền lần hai.
    if (OmniSearchFrame.isInside(context)) return content;
    return OmniSearchFrame(child: content);
  }
}

/// Labelled form field wrapper — one place for the label, hint, error and
/// required marker so no two forms disagree.
class OmniField extends StatelessWidget {
  const OmniField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Nhãn dài (sheet trong viên kính hẹp hơn 16) xuống dòng, không tràn.
            Flexible(
              child: Text(
                label,
                // 14/600 màu chữ chính — nhãn của mọi biểu mẫu trong bộ Orbit.
                style: OmniType.body.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (required)
              Text(
                ' *',
                style: OmniType.caption.copyWith(
                  color: OmniColors.dangerTextOf(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        OmniFocusGlow(child: child),
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                LucideIcons.circleAlert,
                size: OmniIconSize.xs,
                color: OmniColors.dangerTextOf(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  error!,
                  style: OmniType.micro.copyWith(
                    color: OmniColors.dangerTextOf(context),
                  ),
                ),
              ),
            ],
          ),
        ] else if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Thanh hành động đáy của form và màn chi tiết — khay nổi nền đặc + bóng
/// (bớt kính mờ 26/11/2026; trước là viên kính `.actbar.glass`): cách mép 12,
/// bo 32, đệm 7.
///
/// Nút trong thanh là nút VIỀN (gu người dùng: không nút tô đặc): nút chính
/// (FilledButton) viền + chữ màu chủ đạo, nút phụ (OutlinedButton) viền nhạt
/// chữ phụ; cao 50, dạng viên thuốc. Nút phụ ôm chữ của nó, nút chính cuối
/// hàng chiếm phần còn lại — chia đều làm chữ nút phụ gãy dòng ở màn 390dp.
class OmniActionBar extends StatelessWidget {
  const OmniActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Nút đáy 50 (lõi 50–56); khay = 50 + 2×7 → bo 32 theo thang.
    const height = 50.0;
    // Nền đặc: Tối dùng `accent-fill` + chữ trắng, không `scheme.primary`
    // (xanh chữ, chữ đen trên nó).
    final fill = OmniColors.byBrightness(
      context,
      scheme.primary,
      OmniColors.primaryFillOf(context),
    );
    const onFill = OmniColors.primaryForeground;
    final label = OmniType.body.copyWith(fontWeight: FontWeight.w600);

    Color tone(Set<WidgetState> s, Color on) => s.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: .38)
        : on;

    final primary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(label),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: .10)
            : fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith((s) => tone(s, onFill)),
      overlayColor: WidgetStatePropertyAll(onFill.withValues(alpha: .12)),
    );
    final secondary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(label),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => tone(s, scheme.onSurfaceVariant),
      ),
      overlayColor: WidgetStatePropertyAll(
        scheme.onSurface.withValues(alpha: .06),
      ),
      side: WidgetStatePropertyAll(
        BorderSide(width: 1, color: scheme.outlineVariant),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: OmniGlass(
        opaque: true,
        radius: OmniRadius.xxl,
        padding: const EdgeInsets.all(7),
        child: FilledButtonTheme(
          data: FilledButtonThemeData(style: primary),
          child: OutlinedButtonTheme(
            data: OutlinedButtonThemeData(style: secondary),
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  if (i == children.length - 1)
                    Expanded(child: children[i])
                  else
                    children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Consistent modal sheet — used for assign, labels, filters, stage change.
///
/// Nơi DUY NHẤT trong app gọi `showModalBottomSheet`. Module gọi hàm này và
/// nhận hình thức đúng nền tảng mà không phải biết nền tảng là gì.
Future<T?> showOmniSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool expand = false,
  Color? backgroundColor,
  Color? barrierColor,
  double? maxHeight,
  double? radius,
  bool? showDragHandle,
  AnimationStyle? animationStyle,
  // Mặc định mở ở navigator gốc: màn trong tab nằm ở navigator lồng, còn
  // thanh tab kính vẽ bên ngoài nó — sheet mở trong tab bị thanh tab đè lên
  // đáy. Chỉ truyền `false` khi sheet thật sự phải nằm dưới thanh tab.
  bool useRootNavigator = true,
}) {
  final apple = isApple(context);
  final fill = backgroundColor ?? Theme.of(context).colorScheme.surface;

  // Sheet nền đặc (spec phong cách iOS 25/11/2026 §3.4): sát mép dưới, bo
  // trên 32, không nhoè. Tấm Material của sheet để trong suốt;
  // [OmniGlassSheet] vẽ nền, bo và thanh kéo.
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: barrierColor,
    constraints: maxHeight == null
        ? null
        : BoxConstraints(maxHeight: maxHeight),
    // Giảm chuyển động: sheet hiện ngay, không trượt lên.
    sheetAnimationStyle: OmniMotion.enabled(context)
        ? animationStyle
        : AnimationStyle.noAnimation,
    showDragHandle: false,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: OmniGlassSheet(
        fill: fill,
        radius: radius ?? OmniGlassSheet.defaultRadius,
        // iOS luôn có thanh kéo — dấu hiệu người dùng iPhone đọc để biết sheet
        // kéo xuống đóng được. Trên Android nút back đã nói điều đó.
        handle: showDragHandle ?? apple,
        expand: expand,
        child: builder(context),
      ),
    ),
  );
}

/// Tấm chứa nội dung của [showOmniSheet].
///
/// Phong cách iOS 25/11/2026 (spec §3.4): nền ĐẶC, sát mép dưới, bo trên
/// [defaultRadius], bóng mảnh hướng lên — không nhoè, không viền sáng. Lớp phủ
/// phía sau vẫn có thể mờ; bản thân sheet thì không. Giữ tên để mọi chỗ gọi
/// không phải sửa.
class OmniGlassSheet extends StatelessWidget {
  const OmniGlassSheet({
    super.key,
    required this.fill,
    required this.child,
    this.radius = defaultRadius,
    this.handle = false,
    this.expand = false,
  });

  /// Bo trên của sheet (thang bo góc: sheet 32).
  static const double defaultRadius = 32;

  final Color fill;
  final double radius;
  final bool handle;
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final shape = BorderRadius.vertical(top: Radius.circular(radius));
    final sheet = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .36 : .10),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Material(
        key: const Key('omni-glass-sheet'),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: solid
              ? BorderSide(color: Theme.of(context).colorScheme.outline)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (handle)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: OmniSheetHandle(gap: 2),
              )
            else
              // Không thanh kéo (Android/web): chừa mép trên để tiêu đề không
              // nằm trong đường cong bo góc.
              const SizedBox(height: 14),
            // Nút chính trong sheet là nền đặc màu chính (OmniTintedButtons).
            Flexible(
              fit: expand ? FlexFit.tight : FlexFit.loose,
              child: OmniTintedButtons(child: child),
            ),
            // Sát mép dưới: chừa vùng an toàn (thanh Home) bên trong sheet.
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );

    return expand
        ? FractionallySizedBox(heightFactor: 0.9, child: sheet)
        : sheet;
  }
}

/// Sheet chia nhóm của màn Việc (`Board.dc.html` menu kế hoạch,
/// `TaskDetail.dc.html` nhãn): bo trên 12, lớp phủ mực .4, trượt 380ms
/// [OmniCurves.sheet], cao tối đa 740, thanh kéo vẽ trong nội dung
/// ([OmniSheetHandle]).
Future<T?> showOmniViecSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  Color? backgroundColor,
}) => showOmniSheet<T>(
  context: context,
  builder: builder,
  backgroundColor: backgroundColor,
  barrierColor: OmniColors.ink.withValues(alpha: 0.28),
  maxHeight: 740,
  showDragHandle: false,
  animationStyle: const AnimationStyle(
    duration: OmniDuration.sheet,
    curve: OmniCurves.sheet,
    reverseDuration: OmniDuration.base,
  ),
);

/// Thanh kéo 36×4 của [showOmniViecSheet] (`#C9D2DE`), cách nội dung [gap].
class OmniSheetHandle extends StatelessWidget {
  const OmniSheetHandle({super.key, this.gap = 10});

  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: Center(
      child: Container(
        key: const Key('sheet-handle'),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: OmniColors.controlBorderOf(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// Vầng sáng 4dp quanh ô nhập đang focus (`MLogin.dc.html`: viền màu chính
/// 1.5 và `box-shadow: 0 0 0 4px #E3F8F6`).
///
/// InputDecoration không vẽ được bóng, nên vầng sáng nằm ở widget bọc ngoài và
/// nghe focus của cả cây con — không cần FocusNode riêng cho từng ô. Chỉ thêm
/// một lớp nhận diện "đang gõ ở đây", không thay viền: viền focus vẫn do theme
/// vẽ, nên ô nào không bọc cũng không mất gì.
class OmniFocusGlow extends StatefulWidget {
  const OmniFocusGlow({
    super.key,
    required this.child,
    this.borderRadius = OmniRadius.mdAll,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<OmniFocusGlow> createState() => _OmniFocusGlowState();
}

class _OmniFocusGlowState extends State<OmniFocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glow = dark
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
        : OmniColors.accentSoft;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedContainer(
        duration: OmniMotion.of(context).fast,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _focused
              ? [BoxShadow(color: glow, spreadRadius: 4)]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Ô nhập nằm TRONG một dòng của [OmniGroupSection] (Chuẩn Mobile UI —
/// FormField kiểu "trong nhóm thẻ"): bỏ nền và viền của theme — dòng đã là
/// thẻ, ranh giới ô do vạch chia của nhóm đảm nhiệm. Giữ mọi thứ khác của
/// [base] (gợi ý, hậu tố…); đệm dọc mặc định 6.
InputDecoration omniBareDecoration([
  InputDecoration base = const InputDecoration(),
]) => base.copyWith(
  filled: false,
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  contentPadding:
      base.contentPadding ?? const EdgeInsets.symmetric(vertical: 6),
);

/// Một ô của form trong nhóm thẻ (Chuẩn Mobile UI — FormField): nhãn nhỏ
/// 13/600 phía trên (dấu * đỏ khi bắt buộc), ô nhập [child] (dùng
/// [omniBareDecoration]), rồi lỗi đỏ ([error]) hoặc gợi ý xám ([hint]) ngay
/// dưới ô. Đặt trong [OmniGroupSection] với `dividerIndent: 14`.
class OmniGroupField extends StatelessWidget {
  const OmniGroupField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = error ?? hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: OmniColors.dangerTextOf(context)),
                  ),
              ],
            ),
            style: OmniType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          child,
          if (note != null)
            Padding(
              padding: EdgeInsets.only(top: error != null ? 4 : 2),
              child: Text(
                note,
                style: OmniType.caption.copyWith(
                  color: error != null
                      ? OmniColors.dangerTextOf(context)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
