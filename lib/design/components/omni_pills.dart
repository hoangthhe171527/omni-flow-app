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

  /// Màu nền của viên đang được chọn. Bỏ trống thì lấy màu mực của bộ Orbit.
  ///
  /// Widget dùng chung không được ghim màu Zalo — `chat_palette_boundary_test`
  /// chặn việc đó. Chỗ gọi nào cần màu riêng thì truyền vào từ chỗ gọi.
  final Color? tint;

  /// Viên nằm trên nền MỰC (dải nhóm việc của bảng dự án): viên thường nền
  /// mực sáng hơn một bậc chữ xám xanh, viên đang chọn nền quỹ đạo sáng chữ
  /// tối đậm.
  final bool onInk;

  /// Lựa chọn trong BIỂU MẪU (nguồn khách, giai đoạn): viên chưa chọn trong
  /// suốt có viền mảnh thay vì nền xám, cao 36.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Bộ Orbit: viên đang chọn là khối MỰC chữ trắng, số đếm màu quỹ đạo
    // sáng; các viên khác nền xám nhạt chữ mực, số đếm chữ phụ. Ở chế độ tối
    // khối mực biến mất vào nền, nên đảo lại: nền chữ sáng, chữ màu nền.
    final Color background;
    final Color foreground;
    final Color countColor;
    if (onInk) {
      background = selected ? OmniColors.orbit : OmniColors.inkRaised;
      foreground = selected
          ? OmniColors.darkPrimaryForeground
          : OmniColors.inkMutedForeground;
      countColor = foreground;
    } else if (selected) {
      background = tint ?? (dark ? scheme.onSurface : OmniColors.ink);
      foreground = dark && tint == null ? scheme.surface : Colors.white;
      countColor = tint != null
          ? Colors.white.withValues(alpha: 0.75)
          : dark
          ? OmniColors.primary
          : OmniColors.orbit;
    } else if (outlined) {
      background = Colors.transparent;
      foreground = scheme.onSurface;
      countColor = scheme.onSurfaceVariant;
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
        customBorder: const StadiumBorder(),
        // 44dp là sàn vùng chạm; viên nhìn thấy cao 34dp như thiết kế.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: OmniMotion.of(context).fast,
              constraints: BoxConstraints(minHeight: outlined ? 36 : 34),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: outlined ? 8 : 7,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: OmniRadius.pillAll,
                border: outlined && !selected
                    ? Border.all(color: scheme.outlineVariant)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: OmniType.caption.copyWith(
                        height: 1.2,
                        color: foreground,
                        fontWeight: selected
                            ? (onInk ? FontWeight.w600 : FontWeight.w500)
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: OmniType.caption.copyWith(
                        height: 1.2,
                        color: countColor,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
        borderRadius: OmniRadius.smAll,
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
        borderRadius: OmniRadius.smAll,
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
              fontWeight: FontWeight.w600,
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

    // The badge glows, not the text.
    //
    // A halo around the NAME is what gets asked for, but no messaging app does
    // it — and it is actively wrong for Vietnamese, where diacritics stack above
    // and below the x-height (ế, ộ, ữ) and a glow bleeds straight into the marks
    // that carry the meaning. Putting the light on the badge gets the same "this
    // one is live" read with none of that cost: it is a solid shape, so a halo
    // only makes it rounder.
    //
    // It also scales in, so a count that arrives while the rep is looking at the
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
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: background.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
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
