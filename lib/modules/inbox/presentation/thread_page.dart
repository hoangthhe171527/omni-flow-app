import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inbox_providers.dart';
import '../application/thread_controller.dart';
import '../data/inbox_api.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import 'widgets/assign_sheet.dart';
import 'widgets/conversation_context_sheet.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

class ThreadPage extends ConsumerStatefulWidget {
  const ThreadPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends ConsumerState<ThreadPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Opening a thread is the act of reading it.
    Future.microtask(() async {
      try {
        await ref.read(inboxApiProvider).markRead(widget.conversationId);
        ref.invalidate(inboxFacetsProvider);
      } on AppException {
        // Non-critical: the badge stays until the next refresh.
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The list is reversed, so "older" is at the far end of the scroll extent.
    if (_scrollController.position.extentAfter < 200) {
      ref.read(threadProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.conversationId));
    final thread = ref.watch(threadProvider(widget.conversationId));
    final access = ref.watch(inboxAccessProvider);

    return Scaffold(
      // Bubbles can only read as raised against a tinted canvas. On white the
      // incoming (white) bubbles vanished into the page and the thread looked
      // like a flat document — the single biggest reason it did not feel like a
      // chat app.
      backgroundColor: OmniColors.chat(
        context,
        OmniColors.chatCanvas,
        OmniColors.chatCanvasDark,
      ),
      appBar: _ThreadAppBar(
        conversation: conversation.valueOrNull,
        onAssign: access.canAssign ? _assign : null,
        onInfo: _showContext,
      ),
      body: Column(
        children: [
          Expanded(
            // No tint layer over the canvas: it fought the chat background and
            // washed the bubbles back down into the page.
            child: OmniAsyncView(
              value: thread,
              onRetry: () =>
                  ref.invalidate(threadProvider(widget.conversationId)),
              isEmpty: (state) => state.messages.isEmpty,
              empty: const OmniEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chưa có tin nhắn',
                message: 'Gửi tin đầu tiên để bắt đầu cuộc trò chuyện.',
              ),
              data: (state) => _MessageList(
                state: state,
                controller: _scrollController,
                isGroup: conversation.valueOrNull?.isGroup ?? false,
                onRetry: (message) => ref
                    .read(threadProvider(widget.conversationId).notifier)
                    .send(message.text, attachments: message.attachments),
                onDiscard: (message) => ref
                    .read(threadProvider(widget.conversationId).notifier)
                    .discard(message.id),
              ),
            ),
          ),
          if (access.canSend)
            MessageComposer(
              canNote: access.canNote,
              suggestions: _suggestions(conversation.valueOrNull),
              onAttach: _attach,
              onCamera: () => _attach(source: ImageSource.camera),
              onSend: (text, mode) async {
                final controller = ref.read(
                  threadProvider(widget.conversationId).notifier,
                );
                if (mode == ComposeMode.note) {
                  await controller.addNote(text);
                } else {
                  await controller.send(text);
                }
                _scrollToBottom();
              },
            )
          else
            _ReadOnlyBar(),
        ],
      ),
    );
  }

  /// Rule-based, not generated: openers a rep would type anyway, offered as one
  /// tap. Deliberately generic — a wrong "smart" suggestion costs more trust
  /// than no suggestion.
  List<String> _suggestions(Conversation? conversation) {
    if (conversation == null) return const [];
    return const [
      'Dạ em chào anh/chị ạ!',
      'Cảm ơn anh/chị đã quan tâm.',
      'Anh/chị cho em xin số điện thoại để tư vấn nhé.',
      'Bên em đang có chương trình ưu đãi ạ.',
    ];
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _attach({ImageSource source = ImageSource.gallery}) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    try {
      final attachment = await ref
          .read(inboxApiProvider)
          .uploadMedia(picked.path, filename: picked.name);
      await ref
          .read(threadProvider(widget.conversationId).notifier)
          .send('', attachments: [attachment]);
      _scrollToBottom();
    } on AppException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _assign() async {
    final conversation = ref
        .read(conversationProvider(widget.conversationId))
        .valueOrNull;
    final result = await showOmniSheet<AssignResult>(
      context: context,
      expand: true,
      builder: (_) => AssignSheet(currentAssigneeId: conversation?.assigneeId),
    );
    if (result == null) return;

    try {
      final updated = await ref
          .read(inboxApiProvider)
          .assign(widget.conversationId, result.assigneeId, note: result.note);
      ref.read(inboxListProvider.notifier).patch(updated);
      ref.invalidate(conversationProvider(widget.conversationId));
      _toast(result.assigneeId == null ? 'Đã bỏ gán.' : 'Đã gán hội thoại.');
    } on AppException catch (error) {
      _toast(error.message);
    }
  }

  void _showContext() {
    showOmniSheet(
      context: context,
      expand: true,
      builder: (_) =>
          ConversationContextSheet(conversationId: widget.conversationId),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadAppBar({
    required this.conversation,
    required this.onInfo,
    this.onAssign,
  });

  final Conversation? conversation;
  final VoidCallback onInfo;
  final VoidCallback? onAssign;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 0,
      backgroundColor: scheme.surface,
      shape: Border(
        bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.72)),
      ),
      title: conversation == null
          ? const SizedBox.shrink()
          : Row(
              children: [
                conversation!.isGroup
                    ? OmniGroupAvatar(
                        names: conversation!.groupMembers
                            .map((m) => m.name ?? '?')
                            .toList(),
                        size: 36,
                      )
                    : OmniAvatar(
                        name: conversation!.title,
                        imageUrl: conversation!.customerAvatar,
                        size: 36,
                      ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.bodyStrong.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          OmniSourcePill(
                            channel: conversation!.channel,
                            accountName: conversation!.accountName,
                          ),
                          if (conversation!.lastMessageAt != null) ...[
                            const SizedBox(width: 5),
                            Text(
                              Formatters.relative(conversation!.lastMessageAt),
                              style: OmniType.micro.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        // The phone number lives on the customer record, not the thread, so
        // "gọi" is offered in the context sheet where that data is loaded.
        if (onAssign != null)
          IconButton(
            tooltip: 'Gán nhân viên',
            onPressed: onAssign,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
            ),
            icon: const Icon(Icons.person_add_alt_outlined, size: 21),
          ),
        IconButton(
          tooltip: 'Thông tin khách hàng',
          onPressed: onInfo,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 21),
        ),
        const SizedBox(width: OmniSpacing.xs),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.controller,
    required this.isGroup,
    required this.onRetry,
    required this.onDiscard,
  });

  final ThreadState state;
  final ScrollController controller;
  final bool isGroup;
  final void Function(Message message) onRetry;
  final void Function(Message message) onDiscard;

  @override
  Widget build(BuildContext context) {
    // Rendered bottom-up so new messages land where the eye already is and
    // loading history never shifts the viewport.
    final items = state.messages.reversed.toList();

    return ListView.builder(
      controller: controller,
      reverse: true,
      // Tight gutters: Zalo lets bubbles run close to both edges, which is what
      // makes the left/right split read at a glance.
      padding: const EdgeInsets.fromLTRB(8, OmniSpacing.lg, 8, OmniSpacing.md),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(OmniSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = items[index];
        // `items` runs newest→oldest, so the *next* index is the earlier message.
        final earlier = index + 1 < items.length ? items[index + 1] : null;
        final needsDayHeader =
            message.sentAt != null &&
            (earlier?.sentAt == null ||
                !_sameDay(message.sentAt!, earlier!.sentAt!));

        return Column(
          // Without this the Column defaults to centre, which collapsed to the
          // bubble's own width and parked every message in the middle of the
          // screen — the side a message is on is the whole point of a thread.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsDayHeader) _DaySeparator(date: message.sentAt!),
            MessageBubble(
              message: message,
              showSender: isGroup && !message.isOutbound,
              onRetry: message.status == DeliveryStatus.failed
                  ? () => onRetry(message)
                  : null,
              onDiscard: message.status == DeliveryStatus.failed
                  ? () => onDiscard(message)
                  : null,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.md,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: OmniRadius.pillAll,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.78)),
          ),
          child: Text(
            Formatters.dayHeader(date),
            style: OmniType.micro.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              letterSpacing: 0.25,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              'Bạn chỉ có quyền xem hội thoại này.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
