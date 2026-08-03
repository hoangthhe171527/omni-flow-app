import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The single surface primitive. Hairline border, near-invisible shadow —
/// hierarchy comes from spacing, not elevation.
class OmniCard extends StatelessWidget {
  const OmniCard({
    super.key,
    required this.child,
    this.padding = OmniSpacing.card,
    this.onTap,
    this.borderColor,
    this.background,
    this.leadingEdge,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;

  /// A 3px coloured strip on the leading edge — how a conversation row encodes
  /// its platform without spending horizontal space.
  final Color? leadingEdge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content = Padding(padding: padding, child: child);

    if (leadingEdge != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: leadingEdge),
          Expanded(child: content),
        ],
      );
    }

    return Material(
      color: background ?? scheme.surface,
      borderRadius: OmniRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: OmniRadius.lgAll,
            border: Border.all(color: borderColor ?? scheme.outline),
          ),
          child: content,
        ),
      ),
    );
  }
}

class OmniSectionHeader extends StatelessWidget {
  const OmniSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(
      left: OmniSpacing.lg,
      right: OmniSpacing.lg,
      top: OmniSpacing.xxl,
      bottom: OmniSpacing.md,
    ),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text(
                    action!,
                    style: OmniType.micro.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One KPI tile — pipeline value, open opportunities, conversation count.
class OmniStatTile extends StatelessWidget {
  const OmniStatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
    this.caption,
  });

  final String label;
  final String value;
  final Color? tone;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniCard(
      padding: const EdgeInsets.all(OmniSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.money.copyWith(color: tone ?? scheme.onSurface),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label/value row inside a detail card.
class OmniDetailRow extends StatelessWidget {
  const OmniDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: OmniRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: OmniSpacing.md),
            ],
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: OmniType.caption.copyWith(
                  color: valueColor ?? scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
