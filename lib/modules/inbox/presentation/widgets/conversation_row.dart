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

    return Material(
      color: selected ? OmniColors.accent : scheme.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          // 12/16 with a 52 avatar puts the row at ~76 tall — Zalo's rhythm, and
          // comfortably past the 48dp touch minimum.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? OmniColors.chatPrimary : scheme.outline,
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
                style: OmniType.body.copyWith(
                  fontSize: 16,
                  height: 1.2,
                  color: scheme.onSurface,
                  // Zalo bolds an unread name and leaves a read one regular.
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.relative(conversation.lastMessageAt),
              style: OmniType.micro.copyWith(
                fontSize: 12,
                color: overdue ? scheme.error : OmniColors.chatMeta,
                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
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
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: conversation.urgent
                        ? OmniColors.destructive
                        : OmniColors.warning,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? 'Chưa có tin nhắn'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.caption.copyWith(
                  fontSize: 14,
                  height: 1.25,
                  color: unread ? scheme.onSurface : OmniColors.chatMeta,
                  fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              OmniCountBadge(count: conversation.unread),
            ] else if (conversation.isUnassigned) ...[
              const SizedBox(width: 8),
              // Not a warning, just a fact — the row must not shout about it.
              Text(
                'Chưa gán',
                style: OmniType.micro.copyWith(
                  fontSize: 11,
                  color: OmniColors.chatMeta,
                ),
              ),
            ],
          ],
        ),
      ],
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
            right: -1,
            bottom: -1,
            child: Semantics(
              label: 'Kênh ${meta.name}',
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: meta.color,
                  shape: BoxShape.circle,
                  // A ring in the row's own colour, so the badge reads as
                  // sitting on top of the avatar rather than punched into it.
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(meta.icon, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
