import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showSender = false,
    this.onRetry,
    this.onDiscard,
  });

  final Message message;

  /// Group threads: the member who sent it, above the bubble.
  final bool showSender;

  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    if (message.isNote) return _NoteBubble(message: message);

    final scheme = Theme.of(context).colorScheme;
    final outbound = message.isOutbound;
    final failed = message.status == DeliveryStatus.failed;

    // Measured against Zalo itself rather than from memory: the outgoing bubble
    // is a MUTED blue-grey, not a saturated blue — a bright bubble is exhausting
    // to read a long thread on. Corners are evenly rounded on all four, with no
    // sharp tail, which is what lets a run of messages read as one calm column.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = failed
        ? scheme.errorContainer
        : outbound
        ? OmniColors.chat(
            context,
            OmniColors.chatOutbound,
            OmniColors.chatOutboundDark,
          )
        : OmniColors.chat(
            context,
            OmniColors.chatInbound,
            OmniColors.chatInboundDark,
          );
    // Dark mode carries white text on both sides; light mode is dark-on-pale.
    final onBubble = failed
        ? scheme.onErrorContainer
        : dark
        ? Colors.white
        : scheme.onSurface;
    final metaColor = dark
        ? Colors.white.withValues(alpha: 0.55)
        : OmniColors.chatMeta;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        // No shadow at all. The tinted canvas already separates the bubbles by
        // value, so the drop shadow was doing no work — it only fuzzed every
        // edge in the thread, which is what reads as cheap at this scale.
        boxShadow: null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.hasAttachments) ...[
            _Attachments(attachments: message.attachments),
            if (message.text.isNotEmpty) const SizedBox(height: OmniSpacing.sm),
          ],
          if (message.recalled)
            Text(
              'Tin nhắn đã được thu hồi',
              style: OmniType.caption.copyWith(
                color: metaColor,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (message.text.isNotEmpty)
            Text(
              message.text,
              style: OmniType.body.copyWith(
                fontSize: 15,
                height: 1.35,
                color: onBubble,
              ),
            ),
          // Time and tick inside the bubble, bottom-LEFT. Zalo puts them there
          // on both sides — checked against the real app, not from memory — and
          // they used to sit on their own line underneath, costing a full row of
          // vertical space per message.
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.time(message.sentAt),
                style: OmniType.micro.copyWith(fontSize: 11, color: metaColor),
              ),
              if (outbound) ...[
                const SizedBox(width: 3),
                Icon(
                  _statusIcon(message.status),
                  size: 13,
                  color: message.status == DeliveryStatus.read
                      ? OmniColors.chatPrimary
                      : metaColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    // Incoming messages sit beside the sender's avatar — Zalo shows one on
    // every incoming message, 1-1 threads included, and it is what anchors the
    // left column visually. Outgoing has none, so the right side stays clean.
    final avatarGutter = outbound
        ? const SizedBox(width: 8)
        : Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OmniAvatar(
              name: message.senderName ?? '?',
              imageUrl: message.senderAvatar,
              size: 32,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: outbound
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!outbound) avatarGutter,
          Flexible(
            child: Column(
              crossAxisAlignment: outbound
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showSender && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OmniAvatar(
                          name: message.senderName!,
                          imageUrl: message.senderAvatar,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          message.senderName!,
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    bubble,
                    if (message.reaction != null &&
                        message.reaction!.isNotEmpty)
                      Positioned(
                        right: outbound ? null : -6,
                        left: outbound ? -6 : null,
                        bottom: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Text(
                            message.reaction!,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
                _MetaLine(
                  message: message,
                  onRetry: onRetry,
                  onDiscard: onDiscard,
                ),
              ],
            ),
          ),
          if (outbound) avatarGutter,
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, this.onRetry, this.onDiscard});

  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = message.status == DeliveryStatus.failed;

    if (failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 13, color: scheme.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message.error ?? 'Gửi lỗi',
              style: OmniType.micro.copyWith(color: scheme.error),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Gửi lại'),
            ),
          if (onDiscard != null)
            TextButton(
              onPressed: onDiscard,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.onSurfaceVariant,
              ),
              child: const Text('Bỏ'),
            ),
        ],
      );
    }

    // Time and tick now live inside the bubble, so a delivered message needs
    // nothing here at all — this line exists only to explain a failure.
    return const SizedBox.shrink();
  }
}

IconData _statusIcon(DeliveryStatus status) => switch (status) {
  DeliveryStatus.queued => Icons.schedule_rounded,
  DeliveryStatus.sent => Icons.check_rounded,
  DeliveryStatus.delivered => Icons.done_all_rounded,
  DeliveryStatus.read => Icons.done_all_rounded,
  _ => Icons.check_rounded,
};

/// Internal note. Deliberately unlike a message bubble — full width, amber,
/// labelled — so it can never be mistaken for something the customer saw.
class _NoteBubble extends StatelessWidget {
  const _NoteBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    const amber = OmniColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.09),
          borderRadius: OmniRadius.mdAll,
          border: Border.all(color: amber.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: amber,
                ),
                const SizedBox(width: 5),
                Text(
                  'GHI CHÚ NỘI BỘ',
                  style: OmniType.micro.copyWith(
                    color: amber,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(message.text, style: OmniType.body),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              'Bởi ${message.agentName ?? "bạn"} · ${Formatters.time(message.sentAt)}',
              style: OmniType.micro.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: attachment.isImage
                ? ClipRRect(
                    borderRadius: OmniRadius.smAll,
                    child: Image.network(
                      attachment.url,
                      width: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 210,
                        height: 130,
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          attachment.name ?? 'Tệp đính kèm',
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}
