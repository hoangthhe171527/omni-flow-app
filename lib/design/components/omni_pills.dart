import 'package:flutter/material.dart';

import '../../core/domain/channel.dart';
import '../tokens/tokens.dart';

/// Horizontally scrolling filter pill with an optional count.
class OmniFilterPill extends StatelessWidget {
  const OmniFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Only the CHOSEN one is a pill. The rest are plain text.
    //
    // Six filled capsules in a row was the heaviest thing on the screen, and
    // filling all of them spends the same ink on the five a rep is not using as
    // on the one they are. Emptying the others lets the selection carry the
    // whole signal, and the row turns into a line of words above the list
    // instead of a tray of buttons.
    final background = selected ? OmniColors.chatPrimary : Colors.transparent;
    final foreground = selected
        ? Colors.white
        : dark
        ? Colors.white.withValues(alpha: 0.6)
        : scheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: OmniRadius.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: OmniType.caption.copyWith(
                  fontSize: 13.5,
                  height: 1.1,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: OmniType.caption.copyWith(
                    fontSize: 13.5,
                    height: 1.1,
                    // Dimmed rather than boxed: the count qualifies the label, it
                    // is not a second thing to look at.
                    color: foreground.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ],
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
class OmniCountBadge extends StatelessWidget {
  const OmniCountBadge({super.key, required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final background = color ?? Theme.of(context).colorScheme.primary;

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
      duration: OmniDuration.base,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: OmniRadius.pillAll,
          boxShadow: [
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
            color: Colors.white,
            // Bold: this is the one number on the row that must be read from a
            // glance, and the regular weight let it sink into the pill.
            fontWeight: FontWeight.w700,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ),
    );
  }
}

enum OmniTone { neutral, info, success, warning, danger }

extension OmniToneColor on OmniTone {
  Color get color => switch (this) {
    OmniTone.neutral => OmniColors.mutedForeground,
    OmniTone.info => OmniColors.info,
    OmniTone.success => OmniColors.success,
    OmniTone.warning => OmniColors.warning,
    OmniTone.danger => OmniColors.destructive,
  };
}

class OmniStatusChip extends StatelessWidget {
  const OmniStatusChip({
    super.key,
    required this.label,
    this.tone = OmniTone.neutral,
    this.icon,
  });

  final String label;
  final OmniTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.12),
        borderRadius: OmniRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: OmniIconSize.xs, color: tone.color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: OmniType.micro.copyWith(
              color: tone.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
