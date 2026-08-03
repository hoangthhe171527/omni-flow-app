import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../customers/customers.dart';
import '../../../opportunities/opportunities.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';

/// The customer panel behind the chat: who they are, what's open with them, what
/// happened recently, and the two or three actions a rep takes from a chat.
class ConversationContextSheet extends ConsumerWidget {
  const ConversationContextSheet({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider(conversationId));
    final contextData = ref.watch(conversationContextProvider(conversationId));
    final access = ref.watch(inboxAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    return OmniAsyncView(
      value: conversation,
      data: (thread) => ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          0,
          OmniSpacing.lg,
          OmniSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              OmniAvatar(
                name: thread.title,
                imageUrl: thread.customerAvatar,
                size: 56,
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      style: OmniType.title.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    OmniSourcePill(
                      channel: thread.channel,
                      accountName: thread.accountName,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.xl),

          Row(
            children: [
              if (thread.isLinkedToCustomer)
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_outline_rounded,
                    label: 'Hồ sơ KH',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed(
                        CustomersModule.detail,
                        pathParameters: {'id': thread.customerId!},
                      );
                    },
                  ),
                )
              else if (access.canConvert)
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_rounded,
                    label: 'Chuyển KH',
                    onTap: () => _convert(context, ref),
                  ),
                ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: _QuickAction(
                  icon: Icons.trending_up_rounded,
                  label: 'Tạo cơ hội',
                  onTap: () {
                    Navigator.pop(context);
                    context.pushNamed(
                      OpportunitiesModule.create,
                      queryParameters: {
                        if (thread.customerId != null)
                          'customer': thread.customerId!,
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          const OmniSectionHeader(title: 'Nhãn hội thoại'),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final tag in thread.tags) OmniTag(label: tag),
              if (thread.tags.isEmpty)
                Text(
                  'Chưa có nhãn',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),

          const OmniSectionHeader(title: 'Cơ hội đang mở'),
          OmniAsyncView(
            value: contextData,
            loading: const OmniSkeletonBox(height: 70),
            isEmpty: (data) => data.opportunities.isEmpty,
            empty: Text(
              'Chưa có cơ hội nào gắn với khách này.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            data: (data) => Column(
              children: [
                for (final opportunity in data.opportunities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                    child: OmniCard(
                      padding: const EdgeInsets.all(OmniSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opportunity.title,
                                  style: OmniType.caption.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (opportunity.stage != null)
                                  Text(
                                    'Giai đoạn: ${opportunity.stage}',
                                    style: OmniType.micro.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.vnd(opportunity.budget),
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontFeatures: OmniType.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const OmniSectionHeader(title: 'Hoạt động gần đây'),
          OmniAsyncView(
            value: contextData,
            loading: const OmniSkeletonBox(height: 100),
            isEmpty: (data) => data.timeline.isEmpty,
            empty: Text(
              'Chưa có hoạt động.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            data: (data) => Column(
              children: [
                for (final entry in data.timeline.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: OmniSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _timelineIcon(entry.kind),
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: OmniSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.text, style: OmniType.caption),
                              Text(
                                Formatters.relative(entry.at),
                                style: OmniType.micro.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _timelineIcon(String kind) => switch (kind) {
    'call' => Icons.call_outlined,
    'message' || 'chat' => Icons.chat_bubble_outline_rounded,
    'email' => Icons.mail_outline_rounded,
    'stage' => Icons.timeline_rounded,
    _ => Icons.sticky_note_2_outlined,
  };

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(inboxApiProvider).convert(conversationId);
      ref.invalidate(conversationProvider(conversationId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.linkedExisting
                ? 'Đã liên kết với khách hàng có sẵn.'
                : 'Đã tạo khách hàng mới.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 5),
          Text(label, style: OmniType.micro.copyWith(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
