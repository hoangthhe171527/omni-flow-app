import 'package:flutter/material.dart';

import '../../core/domain/channel.dart';
import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';

/// Horizontally scrolling filter pill with an optional count.
class OmniFilterPill extends StatelessWidget {
  const OmniFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.tint,
    this.onInk = false,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  /// Màu nền của viên đang được chọn. Bỏ trống thì lấy màu mực.
  ///
  /// Widget dùng chung không được ghim màu Zalo — `chat_palette_boundary_test`
  /// chặn việc đó. Chỗ gọi nào cần màu riêng thì truyền vào từ chỗ gọi.
  final Color? tint;

  /// Viên nằm trên nền MỰC của màn đăng nhập (màn thương hiệu, nơi màu quỹ
  /// đạo sáng còn được dùng): viên thường nền mực sáng hơn một bậc chữ xám
  /// xanh, viên đang chọn nền quỹ đạo sáng chữ tối đậm.
  final bool onInk;

  /// Lựa chọn trong BIỂU MẪU (nguồn khách, giai đoạn): ô trắng viền #C9D2DE
  /// thay vì nền xám; đang chọn thì viền màu chính 2px.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Viên đang chọn là khối MỰC chữ trắng, số đếm xám xanh #A9B6CA (8,5:1
    // trên mực — không còn màu quỹ đạo sáng, màu đó chỉ cho logo); các viên
    // khác nền xám nhạt chữ mực, số đếm chữ phụ. Ở chế độ tối khối mực biến
    // mất vào nền, nên đảo lại: nền chữ sáng, chữ màu nền.
    //
    // Lựa chọn trong biểu mẫu ([outlined]) đang chọn là ô trắng viền màu
    // chính 2px — không phải khối đặc giữa một biểu mẫu toàn ô trắng.
    final Color background;
    final Color foreground;
    final Color countColor;
    Border? border;
    if (onInk) {
      background = selected ? OmniColors.orbit : OmniColors.inkRaised;
      foreground = selected
          ? OmniColors.darkPrimaryForeground
          : OmniColors.inkMutedForeground;
      countColor = foreground;
    } else if (selected && outlined) {
      background = scheme.surface;
      foreground = scheme.onSurface;
      countColor = scheme.onSurfaceVariant;
      border = Border.all(color: scheme.primary, width: 2);
    } else if (selected) {
      background = tint ?? (dark ? scheme.onSurface : OmniColors.ink);
      foreground = dark && tint == null ? scheme.surface : Colors.white;
      countColor = tint != null
          ? Colors.white.withValues(alpha: 0.75)
          : dark
          ? scheme.surface.withValues(alpha: 0.72)
          : OmniColors.inkMutedForeground;
    } else if (outlined) {
      background = scheme.surface;
      foreground = scheme.onSurface;
      countColor = scheme.onSurfaceVariant;
      border = Border.all(color: OmniColors.controlBorderOf(context));
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurface;
      countColor = scheme.onSurfaceVariant;
    }

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: OmniRadius.chipAll,
        ),
        // 44dp là sàn vùng chạm; viên nhìn thấy cao 34dp như thiết kế.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: OmniMotion.of(context).fast,
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: OmniRadius.chipAll,
                border: border,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: OmniType.chip.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: OmniType.chip.copyWith(
                        color: countColor,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "ZALO CÁ NHÂN · KIỆT" — which platform *and which account* a thread arrived
/// on. Reps handle several Zalo accounts at once; without the account name the
/// platform alone is not enough to know who the customer thinks they're talking
/// to.
class OmniSourcePill extends StatelessWidget {
  const OmniSourcePill({
    super.key,
    required this.channel,
    this.accountName,
    this.compact = false,
  });

  final Channel channel;
  final String? accountName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = channel.meta;
    final label = (accountName == null || accountName!.isEmpty)
        ? (compact ? meta.short : meta.name)
        : '${meta.short} · $accountName';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: meta.tint,
        borderRadius: OmniRadius.xsAll,
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OmniType.micro.copyWith(
          color: meta.color,
          fontSize: 9.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Free-form conversation/customer label ("gia đình", "VIP").
class OmniTag extends StatelessWidget {
  const OmniTag({super.key, required this.label, this.icon, this.tone});

  final String label;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tone ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone == null
            ? scheme.surfaceContainerHighest
            : tone!.withValues(alpha: 0.12),
        borderRadius: OmniRadius.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: OmniIconSize.xs, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: OmniType.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid filled unread count — deliberately not an outlined badge, so it reads
/// as "action required" rather than decoration.
///
/// Hai giọng theo bộ Orbit: CHƯA ĐỌC là nền vàng [OmniColors.sun] chữ mực
/// ([OmniCountBadge.unread]), CẦN XỬ LÝ (việc trễ hạn) là nền đỏ chữ trắng
/// ([OmniCountBadge.alert]).
class OmniCountBadge extends StatelessWidget {
  const OmniCountBadge({
    super.key,
    required this.count,
    this.color,
    this.foreground,
    this.ringColor,
    this.compact = false,
  });

  /// Huy hiệu "chưa đọc": vàng, chữ mực.
  const OmniCountBadge.unread({
    super.key,
    required this.count,
    this.ringColor,
    this.compact = true,
  }) : color = OmniColors.sun,
       foreground = OmniColors.sunForeground;

  /// Huy hiệu "cần xử lý": đỏ, chữ trắng.
  const OmniCountBadge.alert({
    super.key,
    required this.count,
    this.ringColor,
    this.compact = true,
  }) : color = OmniColors.dangerSurface,
       foreground = Colors.white;

  final int count;
  final Color? color;

  /// Màu chữ. Mặc định trắng.
  final Color? foreground;

  /// Vành 2dp quanh huy hiệu, cùng màu mặt nó nằm lên — tách huy hiệu khỏi
  /// icon bên dưới (thanh tab, ô trong danh bạ).
  final Color? ringColor;

  /// Cỡ 18dp, không quầng sáng — cho thanh tab và ô danh bạ.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final background = color ?? Theme.of(context).colorScheme.primary;
    final ring = ringColor;
    // Thiết kế vẽ chữ 10px trong huy hiệu 18dp. Sàn chữ của app là 12
    // (`type_scale_test`), nên huy hiệu gọn cao 20dp kể cả vành để chữ 12 vừa.
    const height = 20.0;

    // No glow: the badge is a solid shape and reads on its own — a halo was
    // decoration, and shadows are kept for what floats (menus, sheets, FAB).
    // There is no halo around the NAME either: Vietnamese diacritics stack
    // above and below the x-height and a glow bleeds into the marks.
    //
    // It scales in, so a count that arrives while the rep is looking at the
    // list announces itself instead of appearing between two blinks.
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.6, end: 1),
      duration: OmniMotion.of(context).base,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: height),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: OmniRadius.pillAll,
          border: ring == null ? null : Border.all(color: ring, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: OmniType.micro.copyWith(
            color: foreground ?? Colors.white,
            // Bold: this is the one number on the row that must be read from a
            // glance, and the regular weight let it sink into the pill.
            fontWeight: FontWeight.w600,
            height: 1,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ),
    );
  }
}
