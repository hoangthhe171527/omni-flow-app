import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

/// One row in the inbox list, shaped like Zalo's.
///
/// It used to be a card: rounded border, a 4px platform edge, a source pill and
/// a third line of tags. Everything a rep triages on was on screen at once — and
/// the list read as a database table rather than a chat app, which is jarring
/// next to the real Zalo they keep open all day.
///
/// So it is now two lines and a hairline, exactly like Zalo:
///
///   name ......................... time
///   last message ................. unread
///
/// Nothing was thrown away, it moved somewhere quieter. The platform rides as a
/// small badge on the avatar (where Zalo itself puts an account marker) instead
/// of a pill competing with the name. Urgency and a breached SLA become a single
/// coloured dot before the preview — colour never carries the meaning alone, the
/// dot has a tooltip and the row stays legible without it. Assignee and labels
/// live one tap away in the thread, which is where a rep acts on them anyway.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = conversation.isUnread;

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      // Unread rows carry a faint wash of the accent. Weight alone was not
      // enough to separate them while scanning — the eye picks up a change of
      // BLOCK colour far faster than a change of font weight, and this is the
      // one question the list has to answer at a glance.
      //
      // The selected wash is stronger and wins, so multi-select stays readable.
      // (Its old fixed OmniColors.accent, a light indigo, turned a selected row
      // into a glaring white band in dark mode.)
      // Bộ Orbit: hàng chưa đọc phủ một lớp mòng két rất nhạt (#F2FBFA).
      color: selected
          ? scheme.primary.withValues(alpha: dark ? 0.22 : 0.12)
          : unread
          ? scheme.primary.withValues(alpha: dark ? 0.10 : 0.05)
          : scheme.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          // 12/16 with a 52 avatar puts the row at ~76 tall — Zalo's rhythm, and
          // comfortably past the 48dp touch minimum.
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: OmniSpacing.md),
              ],
              _Avatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(child: _body(context, unread)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool unread) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = conversation.breachesSla;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.listTitle.copyWith(
                  // A read name also steps BACK in contrast, not just in
                  // weight. Two axes of difference are what make the two states
                  // separable without staring — and it keeps them apart for
                  // anyone who cannot rely on the accent wash.
                  color: unread ? scheme.onSurface : _readName(context),
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.relative(conversation.lastMessageAt),
              style: OmniType.micro.copyWith(
                color: overdue
                    ? OmniColors.dangerTextOf(context)
                    : scheme.onSurfaceVariant,
                fontWeight: overdue || unread
                    ? FontWeight.w600
                    : FontWeight.w400,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (conversation.urgent || overdue) ...[
              Tooltip(
                message: conversation.urgent
                    ? 'Khẩn'
                    : 'Quá hạn trả lời ${Formatters.duration(conversation.waiting!)}',
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conversation.urgent
                        ? OmniColors.destructive
                        : OmniColors.sla,
                  ),
                ),
              ),
            ],
            _SourceLabel(conversation: conversation),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? 'Chưa có tin nhắn'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.chip.copyWith(
                  // An unread preview is full-strength text; a read one drops to
                  // the muted tone, so the two are separable by weight AND by
                  // contrast rather than by weight alone.
                  color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              // Vàng chữ mực: trong bộ Orbit màu vàng chỉ có một nghĩa — "có
              // cái mới". Đỏ để dành cho khẩn và quá hạn.
              OmniCountBadge.unread(count: conversation.unread),
            ] else if (conversation.isUnassigned) ...[
              const SizedBox(width: 8),
              // Not a warning, just a fact — the row must not shout about it.
              Text(
                'Chưa gán',
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact source marker for scanning mixed-channel inboxes. The avatar keeps
/// the visual mark, while this label makes the source unambiguous without
/// spending a third row or turning the conversation list into a table.
/// Tên đã đọc lùi về chữ cấp 2 (#3A4760), không chỉ nhạt độ đậm.
Color _readName(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
    : OmniColors.secondaryForeground;

class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final meta = conversation.channel.meta;
    final account = conversation.accountName;
    final label = account == null || account.isEmpty
        ? meta.short
        : '${meta.short} · $account';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Chữ cấp 2, không màu kênh: màu kênh chỉ còn ở huy hiệu tròn
              // góc avatar. "FB Page" xanh #1877F2 cỡ 12 chỉ đạt ~4,2:1.
              style: OmniType.micro.copyWith(
                color: OmniColors.byBrightness(
                  context,
                  OmniColors.secondaryForeground,
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar with the platform marked in the corner.
///
/// Costs no horizontal space, so the name gets the full line — and it is where
/// Zalo itself marks a linked account, so it reads as native rather than as a
/// CRM annotation.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final meta = conversation.channel.meta;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          conversation.isGroup
              ? OmniGroupAvatar(
                  names: conversation.groupMembers
                      .map((m) => m.name ?? '?')
                      .toList(),
                  size: 52,
                )
              : OmniAvatar(
                  name: conversation.title,
                  imageUrl: conversation.customerAvatar,
                  size: 52,
                ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Semantics(
              label: 'Kênh ${meta.name}',
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: meta.color,
                  shape: BoxShape.circle,
                  // A ring in the row's own colour, so the badge reads as
                  // sitting on top of the avatar rather than punched into it.
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  meta.icon,
                  size: OmniIconSize.xs,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
