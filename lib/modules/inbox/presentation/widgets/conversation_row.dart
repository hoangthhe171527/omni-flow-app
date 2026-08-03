import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

/// One row in the inbox list.
///
/// Everything a rep triages on is on screen at once: who, which account, how
/// long they've waited, whether anyone owns it. The 3px leading edge encodes the
/// platform without spending horizontal space, and the source pill always spells
/// the platform out — colour reinforces, it never carries meaning alone.
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
    final meta = conversation.channel.meta;
    final unread = conversation.isUnread;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: meta.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.md,
                    OmniSpacing.md,
                    OmniSpacing.lg,
                    OmniSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: OmniSpacing.sm),
                          child: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? scheme.primary : scheme.outline,
                          ),
                        ),
                      conversation.isGroup
                          ? OmniGroupAvatar(
                              names: conversation.groupMembers
                                  .map((m) => m.name ?? '?')
                                  .toList(),
                            )
                          : OmniAvatar(
                              name: conversation.title,
                              imageUrl: conversation.customerAvatar,
                            ),
                      const SizedBox(width: OmniSpacing.md),
                      Expanded(child: _body(context, unread)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool unread) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.bodyStrong.copyWith(
                  color: scheme.onSurface,
                  fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            Flexible(
              child: OmniSourcePill(
                channel: conversation.channel,
                accountName: conversation.accountName,
              ),
            ),
            const Spacer(),
            Text(
              Formatters.relative(conversation.lastMessageAt),
              style: OmniType.micro.copyWith(
                color: conversation.breachesSla ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          conversation.lastMessage.isEmpty
              ? 'Chưa có tin nhắn'
              : conversation.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.caption.copyWith(
            color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Row(
          children: [
            if (conversation.urgent) ...[
              const OmniTag(
                label: 'Khẩn',
                icon: Icons.local_fire_department_rounded,
                tone: OmniColors.destructive,
              ),
              const SizedBox(width: OmniSpacing.xs),
            ],
            for (final tag in conversation.tags.take(2)) ...[
              OmniTag(label: tag),
              const SizedBox(width: OmniSpacing.xs),
            ],
            if (conversation.breachesSla)
              OmniTag(
                label: 'Chờ ${Formatters.duration(conversation.waiting!)}',
                icon: Icons.schedule_rounded,
                tone: OmniColors.warning,
              ),
            const Spacer(),
            if (conversation.isUnassigned)
              Text(
                'Chưa gán',
                style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
              )
            else if (conversation.assigneeName != null)
              OmniAvatar(name: conversation.assigneeName!, size: 20),
            if (unread) ...[
              const SizedBox(width: OmniSpacing.sm),
              OmniCountBadge(count: conversation.unread),
            ],
          ],
        ),
      ],
    );
  }
}
