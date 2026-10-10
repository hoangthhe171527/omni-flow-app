import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../../customers/customers.dart';
import '../../../opportunities/opportunities.dart';
import '../../../tasks/domain/task_permissions.dart';
import '../../../tasks/routes.dart';
import '../../../tasks/tasks.dart';
import '../../application/inbox_providers.dart';
import '../../domain/conversation.dart';
import 'conversation_actions.dart';

/// Khối giới thiệu khách ở đầu hội thoại 1-1 (`Thread.dc.html`): avatar, tên,
/// nguồn, "Khách từ…", và ba lối tắt tròn Hồ sơ / Cơ hội / Việc.
class ThreadIntro extends ConsumerWidget {
  const ThreadIntro({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final access = ref.watch(inboxAccessProvider);
    final opportunitiesOn = ref
        .watch(sessionProvider)
        .featureEnabled('opportunities');
    final policy = ref.watch(accessProvider);
    final canOpenCustomer = policy.canAny(CustomerPermissions.anyRead);
    final canCreateOpportunity = policy.can(OpportunityPermissions.create);
    final canCreateTask = policy.can(TaskPermissions.write);
    final linked = conversation.isLinkedToCustomer;
    final customer = linked
        ? ref.watch(customerProvider(conversation.customerId!)).valueOrNull
        : null;
    final since = customer?.createdAt;
    final lifetime = customer?.lifetimeValue ?? 0;
    final account = conversation.sourceAccount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Column(
        children: [
          OmniAvatar(
            name: conversation.title,
            imageUrl: conversation.customerAvatar,
            size: 64,
            borderRadius: 12,
          ),
          const SizedBox(height: 8),
          Text(
            conversation.title,
            textAlign: TextAlign.center,
            style: OmniType.navTitle.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                conversation.channel.sourceKind,
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: conversation.channel.meta.textColorOf(
                    Theme.of(context).brightness,
                  ),
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
          ),
          if (since != null)
            Text(
              lifetime > 0
                  ? 'Khách từ ${Formatters.dayMonth(since)} · '
                        '${Formatters.vndCompact(lifetime)}'
                  : 'Khách từ ${Formatters.dayMonth(since)}',
              style: OmniType.micro.copyWith(color: muted),
            ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [
              if (linked && canOpenCustomer)
                _IntroAction(
                  icon: Icons.person_outline_rounded,
                  label: 'Hồ sơ',
                  onTap: () => context.pushNamed(
                    CustomerRoutes.detail,
                    pathParameters: {'id': conversation.customerId!},
                  ),
                )
              else if (!linked && access.canConvert)
                _IntroAction(
                  icon: Icons.person_add_alt_rounded,
                  label: 'Chuyển KH',
                  onTap: () =>
                      convertConversation(context, ref, conversation.id),
                ),
              if (opportunitiesOn && canCreateOpportunity)
                _IntroAction(
                  icon: Icons.trending_up_rounded,
                  label: 'Cơ hội',
                  onTap: () => context.pushNamed(
                    OpportunityRoutes.create,
                    queryParameters: {
                      if (linked) 'customer': conversation.customerId!,
                    },
                  ),
                ),
              if (canCreateTask)
                _IntroAction(
                  icon: Icons.task_alt_rounded,
                  label: 'Việc',
                  onTap: () => context.pushNamed(
                    TaskRoutes.create,
                    extra: CreateTaskArgs(
                      initialTitle: 'Liên hệ ${conversation.title}',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút tròn 36 nền xám nhạt, nhãn 12 w600 bên dưới.
class _IntroAction extends StatelessWidget {
  const _IntroAction({
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
    final fill = OmniColors.byBrightness(
      context,
      OmniColors.muted,
      OmniColors.darkMuted,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: scheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
