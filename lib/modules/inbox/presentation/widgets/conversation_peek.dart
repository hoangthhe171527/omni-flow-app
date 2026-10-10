import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';
import '../../domain/conversation.dart';
import '../../domain/message.dart';
import 'conversation_actions.dart';

/// Tối đa bấy nhiêu tin gần nhất hiện trong khung xem trước.
const _peekMessageCount = 4;

/// 4 tin gần nhất (không tính ghi chú nội bộ), cũ → mới. Tải 6 tin vì ghi chú
/// có thể chiếm chỗ.
final peekMessagesProvider = FutureProvider.autoDispose
    .family<List<Message>, String>((ref, id) async {
      final page = await ref.watch(inboxApiProvider).messages(id, perPage: 6);
      final visible = page.messages.where((m) => !m.isNote).toList();
      return visible.take(_peekMessageCount).toList().reversed.toList();
    });

Color _ink(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.ink,
  Theme.of(context).colorScheme.onSurface,
);

Color _muted(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.mutedForeground,
  Theme.of(context).colorScheme.onSurfaceVariant,
);

Color _danger(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniFeatureTones.light(OmniHue.red).foreground,
  OmniColors.dangerTextDark,
);

/// Bấm giữ một dòng → khung xem trước tin gần nhất + menu thao tác, theo
/// `InboxPeek.dc.html`. Bấm khung mở hội thoại ([onOpen]); bấm ra ngoài đóng.
Future<void> showConversationPeek({
  required BuildContext context,
  required Conversation conversation,
  required VoidCallback onOpen,
  required ValueChanged<PeekAction> onAction,
}) {
  final motion = OmniMotion.enabled(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng xem trước',
    barrierColor: OmniColors.ink.withValues(alpha: 0.35),
    transitionDuration: motion
        ? const Duration(milliseconds: 420)
        : Duration.zero,
    pageBuilder: (dialogContext, _, _) => _PeekOverlay(
      conversation: conversation,
      onOpen: () {
        Navigator.pop(dialogContext);
        onOpen();
      },
      onAction: (action) {
        Navigator.pop(dialogContext);
        onAction(action);
      },
    ),
    transitionBuilder: (context, animation, _, child) {
      if (!motion) return child;
      // Opacity phải nằm trong 0..1 nên đi theo đường thẳng; chỉ độ co dùng
      // đường cong "nảy" cubic-bezier(.2,1.1,.3,1).
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .88, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Cubic(.2, 1.1, .3, 1),
            ),
          ),
          alignment: const Alignment(0, -.6),
          child: child,
        ),
      );
    },
  );
}

class _PeekOverlay extends ConsumerWidget {
  const _PeekOverlay({
    required this.conversation,
    required this.onOpen,
    required this.onAction,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final ValueChanged<PeekAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = peekMenuFor(conversation, ref.watch(inboxAccessProvider));

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Không có con: không nuốt chạm, để rào chắn của route đóng hộp.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PeekCard(conversation: conversation, onOpen: onOpen),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PeekMenu(items: items, onAction: onAction),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekCard extends ConsumerWidget {
  const _PeekCard({required this.conversation, required this.onOpen});

  final Conversation conversation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(peekMessagesProvider(conversation.id));
    final tag = conversation.tags.isEmpty ? null : conversation.tags.first;
    final meta = conversation.channel.meta;
    final account = conversation.sourceAccount;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: OmniColors.ink.withValues(alpha: 0.35),
            offset: Offset(0, 24),
            blurRadius: 60,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: OmniColors.byBrightness(
            context,
            OmniColors.background,
            Theme.of(context).colorScheme.surface,
          ),
          child: Semantics(
            button: true,
            label: 'Mở hội thoại',
            child: InkWell(
              onTap: onOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ink, không phải Container: nền đặc của Container che vệt
                  // chạm của InkWell phía trên.
                  Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: OmniColors.byBrightness(
                        context,
                        Colors.white,
                        Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        OmniAvatar(
                          name: conversation.title,
                          imageUrl: conversation.customerAvatar,
                          size: 34,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OmniType.body.copyWith(
                                  color: _ink(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: conversation.channel.sourceKind,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: meta.textColorOf(
                                          Theme.of(context).brightness,
                                        ),
                                      ),
                                    ),
                                    if (account != null)
                                      TextSpan(text: ' · $account'),
                                    TextSpan(
                                      text:
                                          ' · ${Formatters.relative(conversation.lastMessageAt)}',
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OmniType.micro.copyWith(
                                  color: _muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (tag != null)
                          Semantics(
                            label: 'Nhãn: $tag',
                            container: true,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: OmniLabelColors.of(tag),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: messages.when(
                      loading: () => const _PeekSkeleton(),
                      error: (_, _) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Không tải được tin.',
                              style: OmniType.chip.copyWith(
                                color: _muted(context),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(
                              peekMessagesProvider(conversation.id),
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                      data: (list) => list.isEmpty
                          ? Text(
                              'Chưa có tin nhắn.',
                              style: OmniType.chip.copyWith(
                                color: _muted(context),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < list.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 6),
                                  _PeekBubble(message: list[i]),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bong bóng 14/4: ra = nền màu chính chữ trắng, bên phải; vào = nền trắng,
/// bên trái. Góc 4 nằm ở phía người nói.
class _PeekBubble extends StatelessWidget {
  const _PeekBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final out = message.isOutbound;
    final text = message.text.isEmpty
        ? (message.hasAttachments ? '[Tệp đính kèm]' : '')
        : message.text;

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 60) * .78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: out
                ? Theme.of(context).colorScheme.primary
                : OmniColors.byBrightness(
                    context,
                    Colors.white,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(out ? 14 : 4),
              bottomRight: Radius.circular(out ? 4 : 14),
            ),
          ),
          child: Text(
            text,
            style: OmniType.chip.copyWith(
              height: 1.4,
              color: out
                  ? Theme.of(context).colorScheme.onPrimary
                  : _ink(context),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeekSkeleton extends StatelessWidget {
  const _PeekSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, Alignment align) => Align(
      alignment: align,
      child: Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
    return Semantics(
      label: 'Đang tải tin nhắn',
      child: Column(
        children: [
          bar(150, Alignment.centerLeft),
          const SizedBox(height: 6),
          bar(190, Alignment.centerRight),
          const SizedBox(height: 6),
          bar(120, Alignment.centerLeft),
        ],
      ),
    );
  }
}

/// Menu kính mờ 230 rộng, mục cao 44: chữ bên trái, biểu tượng bên phải.
class _PeekMenu extends StatelessWidget {
  const _PeekMenu({required this.items, required this.onAction});

  final List<PeekMenuItem> items;
  final ValueChanged<PeekAction> onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: OmniColors.ink.withValues(alpha: 0.25),
            offset: Offset(0, 16),
            blurRadius: 40,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 230,
            color: OmniColors.byBrightness(
              context,
              Colors.white,
              Theme.of(context).colorScheme.surfaceContainerHigh,
            ).withValues(alpha: .88),
            // Material trong suốt nằm TRÊN nền kính: vệt chạm của InkWell
            // vẽ lên nó thì mới thấy được.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    _PeekMenuRow(item: items[i], onTap: onAction),
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

class _PeekMenuRow extends StatelessWidget {
  const _PeekMenuRow({required this.item, required this.onTap});

  final PeekMenuItem item;
  final ValueChanged<PeekAction> onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive ? _danger(context) : _ink(context);
    return InkWell(
      onTap: () => onTap(item.action),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(item.icon, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
