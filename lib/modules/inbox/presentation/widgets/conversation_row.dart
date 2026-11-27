import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

/// Một dòng hội thoại trong hộp thư (duyệt 26/11/2026, rà soát mục 9):
///
///   ● [avatar] Tên ............................ giờ
///              [OA] tin cuối ..................  [HT]
///
/// Chưa đọc = MỘT chấm đỏ đầu dòng + tên và dòng xem trước đậm. Kênh là nhãn
/// xám ở đầu dòng xem trước. Bỏ chấm nhãn xám, chấm đỏ giữa câu và vòng "+"
/// nét đứt — gắn nhãn / gán người nằm ở menu nhấn giữ. Bấm giữ 450ms mở xem
/// trước ([onPeek]); trong lúc giữ dòng co nhẹ để báo "sắp mở".
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
    final motion = OmniMotion.enabled(context);

    return Material(
      // Hàng chưa đọc phủ một lớp mòng màu chính; hàng được chọn đậm hơn và
      // thắng, để chọn nhiều vẫn đọc được.
      // Chọn nhiều: dòng đã chọn không tô nền — avatar đổi thành dấu ✓ kính.
      color: scheme.surface,
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
                  padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.selectionMode && !widget.selected) ...[
                        Icon(LucideIcons.circle, color: scheme.outline),
                        const SizedBox(width: OmniSpacing.md),
                      ] else if (widget.selectionMode) ...[
                        // Giữ lề của dòng chưa chọn để avatar không nhảy.
                        const SizedBox(width: 24 + OmniSpacing.md),
                      ],
                      if (widget.selectionMode && widget.selected)
                        Semantics(
                          label: 'Đã chọn',
                          child: OmniGlassCircle(
                            child: Icon(
                              LucideIcons.check,
                              color: scheme.primary,
                            ),
                          ),
                        )
                      else
                        _Avatar(conversation: conversation),
                      const SizedBox(width: 12),
                      Expanded(child: _body(context, unread)),
                    ],
                  ),
                ),
                // Chưa đọc: một chấm đỏ ở mép trái, ngang giữa dòng.
                if (unread && !widget.selectionMode)
                  const Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(child: OmniUnreadDot(size: 8, ring: false)),
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
      OmniColors.ink,
      scheme.onSurface,
    );
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    // Khẩn / quá hạn trả lời: giờ đổi sang đỏ "cần chú ý" thay cho chấm đỏ
    // giữa câu (duyệt 26/11/2026).
    final attention = conversation.urgent || overdue;
    final stampColor = attention ? OmniColors.attentionOf(context) : muted;
    final stamp = Text(
      Formatters.relative(conversation.lastMessageAt),
      style: OmniType.micro.copyWith(
        color: stampColor,
        fontWeight: attention ? FontWeight.w600 : FontWeight.w500,
        fontFeatures: OmniType.tabular,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) => Row(
            children: [
              Expanded(
                child: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.listTitle.copyWith(
                    color: ink,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (conversation.isMuted) ...[
                Semantics(
                  label: 'Đã tắt thông báo',
                  // Nút riêng: InkWell của dòng không nuốt vào nhãn gộp.
                  container: true,
                  excludeSemantics: true,
                  child: Icon(LucideIcons.bellOff, size: 14, color: muted),
                ),
                const SizedBox(width: 4),
              ],
              if (attention)
                Tooltip(
                  message: conversation.urgent
                      ? 'Khẩn'
                      : 'Quá hạn trả lời '
                            '${Formatters.duration(conversation.waiting!)}',
                  child: stamp,
                )
              else
                stamp,
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _ChannelTag(conversation: conversation),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                conversation.lastMessage.isEmpty
                    ? 'Chưa có tin nhắn'
                    : conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.chip.copyWith(
                  color: unread ? ink : muted,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            // Chỉ hiện người phụ trách khi ĐÃ gán; chưa gán không vẽ gì (bỏ
            // vòng "+" nét đứt — gán ở menu nhấn giữ).
            if (_AssigneeBox.hasAssignee(conversation)) ...[
              const SizedBox(width: 8),
              _AssigneeBox(conversation: conversation),
            ],
          ],
        ),
      ],
    );
  }
}

/// Nhãn kênh xám (duyệt 26/11/2026, rà soát mục 8): một kiểu cho mọi kênh —
/// nền `surfaceContainerHighest`, chữ `onSurfaceVariant` w600, bo 5. Kênh là
/// thông tin, không phải trạng thái, nên không tô màu theo kênh. Tên tài
/// khoản kênh ("Trung Nguyên") nằm ở dòng nguồn đầu màn hội thoại.
class _ChannelTag extends StatelessWidget {
  const _ChannelTag({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final account = conversation.sourceAccount;
    final kind = conversation.channel.sourceKind;
    return Semantics(
      label: account == null ? 'Kênh $kind' : 'Kênh $kind $account',
      // Nút riêng: InkWell của dòng không nuốt vào nhãn gộp.
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          kind,
          maxLines: 1,
          // 12 là sàn cỡ chữ của app (OmniType.micro) — bản duyệt ghi 11.
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// Ô tròn 22 của người phụ trách (inbox-assignee-uiux.html, phương án B):
/// chữ tắt trên nền nhạt theo từng người. Chưa gán thì dòng không vẽ ô nào
/// (bỏ vòng nét đứt "+", duyệt 26/11/2026).
class _AssigneeBox extends StatelessWidget {
  const _AssigneeBox({required this.conversation});

  final Conversation conversation;

  static const double _size = 22;

  static bool hasAssignee(Conversation c) {
    final name = c.assigneeName;
    return !c.isUnassigned && name != null && name.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final name = conversation.assigneeName;
    if (name == null || !hasAssignee(conversation)) {
      return const SizedBox.shrink();
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final tones = dark
        ? OmniColors.darkAssigneeTones
        : OmniColors.assigneeTones;
    // Màu cố định theo người: cùng người luôn cùng màu ở mọi dòng, mọi lần mở.
    final seed = conversation.assigneeId ?? name;
    final (bg, fg) =
        tones[seed.codeUnits.fold<int>(0, (a, c) => a + c) % tones.length];

    return Semantics(
      label: 'Phụ trách: $name',
      excludeSemantics: true,
      child: Container(
        key: const Key('assignee-chip'),
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(
          Formatters.initials(name),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            color: fg,
            height: 1,
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
      size: 42,
      borderRadius: 999,
    );
  }
}
