import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../customers/customers.dart';
import '../../domain/conversation.dart';

/// Khối giới thiệu khách ở đầu hội thoại 1-1 (`Thread.dc.html`): avatar, tên,
/// nguồn, "Khách từ…". Lối tắt Hồ sơ / Chuyển KH / Cơ hội / Việc nằm ở trang
/// Thông tin khách (nút ⓘ trên header) để đầu hội thoại không chiếm chỗ của tin.
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
                        '${Formatters.vnd(lifetime)}'
                  : 'Khách từ ${Formatters.dayMonth(since)}',
              style: OmniType.micro.copyWith(color: muted),
            ),
        ],
      ),
    );
  }
}
