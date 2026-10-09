import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

/// Một dòng hội thoại trong hộp thư, theo `InboxPeek.dc.html`.
///
///   ● [avatar] Tên  OA · Trung Nguyên ........ giờ
///              tin cuối ................ (2) [HT]
///
/// Chấm nhãn 7px ở mép trái là nhãn đầu tiên của hội thoại (màu không đứng một
/// mình: chấm có `Semantics('Nhãn: …')`). Kênh không còn là huy hiệu trên avatar
/// mà là chữ đậm tô màu kênh ở dòng nguồn. Bấm giữ 450ms mở xem trước
/// ([onPeek]); trong lúc giữ dòng co nhẹ để báo "sắp mở".
class ConversationRow extends StatefulWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onPeek,
    this.selected = false,
    this.selectionMode = false,
  });

  /// Thời gian giữ để mở xem trước.
  static const peekDelay = Duration(milliseconds: 450);

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onPeek;
  final bool selected;
  final bool selectionMode;

  @override
  State<ConversationRow> createState() => _ConversationRowState();
}

class _ConversationRowState extends State<ConversationRow> {
  bool _holding = false;
  Timer? _pressTimer;

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _setHolding(bool value) {
    _pressTimer?.cancel();
    _pressTimer = null;
    if (value) {
      // Chỉ co sau kPressTimeout: chạm lướt qua (cuộn) không làm dòng giật.
      _pressTimer = Timer(kPressTimeout, () {
        if (mounted) setState(() => _holding = true);
      });
    } else if (_holding && mounted) {
      setState(() => _holding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final scheme = Theme.of(context).colorScheme;
    final unread = conversation.isUnread;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tag = conversation.tags.isEmpty ? null : conversation.tags.first;
    final motion = OmniMotion.enabled(context);

    return Material(
      // Hàng chưa đọc phủ một lớp mòng màu chính; hàng được chọn đậm hơn và
      // thắng, để chọn nhiều vẫn đọc được.
      color: widget.selected
          ? scheme.primary.withValues(alpha: dark ? 0.22 : 0.12)
          : unread
          ? scheme.primary.withValues(alpha: dark ? 0.10 : 0.05)
          : scheme.surface,
      child: RawGestureDetector(
        gestures: {
          if (widget.onPeek != null && !widget.selectionMode)
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(
                    duration: ConversationRow.peekDelay,
                  ),
                  (r) => r
                    ..onLongPressDown = ((_) => _setHolding(true))
                    ..onLongPressCancel = (() => _setHolding(false))
                    ..onLongPress = () {
                      _setHolding(false);
                      HapticFeedback.selectionClick();
                      widget.onPeek!();
                    },
                ),
        },
        child: AnimatedScale(
          scale: motion && _holding ? .965 : 1,
          duration: motion
              ? (_holding
                    ? ConversationRow.peekDelay
                    : const Duration(milliseconds: 200))
              : Duration.zero,
          curve: OmniCurves.standard,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.selectionMode) ...[
                        Icon(
                          widget.selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: widget.selected
                              ? scheme.primary
                              : scheme.outline,
                        ),
                        const SizedBox(width: OmniSpacing.md),
                      ],
                      _Avatar(conversation: conversation),
                      const SizedBox(width: 10),
                      Expanded(child: _body(context, unread)),
                    ],
                  ),
                ),
                if (tag != null)
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        label: 'Nhãn: $tag',
                        // Nút riêng: không để InkWell của dòng nuốt nhãn vào
                        // nhãn gộp của cả hàng.
                        container: true,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: OmniLabelColors.of(tag),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool unread) {
    final conversation = widget.conversation;
    final scheme = Theme.of(context).colorScheme;
    final overdue = conversation.breachesSla;
    final ink = OmniColors.byBrightness(
      context,
      const Color(0xFF0B1A33),
      scheme.onSurface,
    );
    final muted = OmniColors.byBrightness(
      context,
      const Color(0xFF56637A),
      scheme.onSurfaceVariant,
    );
    final stampColor = conversation.urgent && unread
        ? const Color(0xFFC2410C)
        : muted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * .52),
                child: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.listTitle.copyWith(
                    color: unread ? ink : muted,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _SourceLine(conversation: conversation)),
              const SizedBox(width: 6),
              Text(
                Formatters.relative(conversation.lastMessageAt),
                style: OmniType.micro.copyWith(
                  color: stampColor,
                  fontWeight: FontWeight.w600,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ],
          ),
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
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? 'Chưa có tin nhắn'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.chip.copyWith(
                  color: unread ? ink : muted,
                  fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              OmniCountBadge(
                count: conversation.unread,
                color: scheme.primary,
                foreground: scheme.onPrimary,
                compact: true,
              ),
            ],
            const SizedBox(width: 8),
            _AssigneeBox(conversation: conversation),
          ],
        ),
      ],
    );
  }
}

/// "**OA** · Trung Nguyên": loại nguồn đậm màu kênh, rồi tên tài khoản.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final meta = conversation.channel.meta;
    final account = conversation.sourceAccount;
    final muted = OmniColors.byBrightness(
      context,
      const Color(0xFF56637A),
      Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          conversation.channel.sourceKind,
          maxLines: 1,
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            color: meta.color,
          ),
        ),
        if (account != null)
          Flexible(
            child: Text(
              ' · $account',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// Ô 20×20 bo 4 của người phụ trách: chữ tắt, hoặc `–` khi chưa gán.
class _AssigneeBox extends StatelessWidget {
  const _AssigneeBox({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final name = conversation.assigneeName;
    final hasName =
        !conversation.isUnassigned && name != null && name.trim().isNotEmpty;
    final text = hasName ? Formatters.initials(name) : '–';
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: hasName ? 'Phụ trách: $name' : 'Chưa gán',
      excludeSemantics: true,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasName
              ? scheme.onSurface
              : OmniColors.byBrightness(
                  context,
                  const Color(0xFFEEF1F5),
                  scheme.surfaceContainerHighest,
                ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            color: hasName ? scheme.surface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Avatar 38 bo 6, không huy hiệu kênh (kênh đã nằm ở dòng nguồn).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroup) {
      return OmniGroupAvatar(
        names: conversation.groupMembers.map((m) => m.name ?? '?').toList(),
        size: 38,
      );
    }
    return OmniAvatar(
      name: conversation.title,
      imageUrl: conversation.customerAvatar,
      size: 38,
      borderRadius: 6,
    );
  }
}
