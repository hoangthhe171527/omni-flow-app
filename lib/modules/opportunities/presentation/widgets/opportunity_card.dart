import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/opportunities_providers.dart';
import '../../domain/opportunity.dart';
import '../../opportunities_module.dart';
import 'stage_picker_sheet.dart';

class OpportunityCard extends ConsumerWidget {
  const OpportunityCard({
    super.key,
    required this.opportunity,
    this.canMove = false,
  });

  final Opportunity opportunity;
  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // A row, not a card. The card stacked four bands: title+value, then a
    // probability bar with a date tag, a source pill and an owner avatar, then a
    // divider, then an "Đổi giai đoạn" button — so ten opportunities filled the
    // screen three times over.
    //
    // The probability bar went entirely: the LIST IS ALREADY FILTERED BY STAGE,
    // so drawing the stage again inside every row is the same fact twice. Source
    // and owner live on the detail page. Changing stage is a long-press away
    // instead of a button on every row.
    final overdue = opportunity.isOverdue;

    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => context.pushNamed(
          OpportunitiesModule.detail,
          pathParameters: {'id': opportunity.id},
        ),
        onLongPress: canMove ? () => _moveStage(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (overdue)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: OmniColors.destructive,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      opportunity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.listTitle.copyWith(
                        height: 1.2,
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The number is what a pipeline is scanned for: right
                  // aligned, tabular, so the column reads straight down.
                  Text(
                    Formatters.vndCompact(opportunity.value),
                    style: OmniType.listTitle.copyWith(
                      height: 1.2,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  opportunity.customerName ?? 'Chưa gắn khách hàng',
                  if (opportunity.expectedCloseAt != null)
                    '${overdue ? 'quá hạn' : 'chốt'} ${Formatters.date(opportunity.expectedCloseAt)}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.body.copyWith(
                  height: 1.25,
                  color: overdue
                      ? OmniColors.dangerTextOf(context)
                      : scheme.onSurfaceVariant,
                  fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveStage(BuildContext context, WidgetRef ref) async {
    try {
      final stage = await pickOpportunityStage(context, ref, opportunity);
      if (stage == null) return;
      await moveOpportunityStage(ref, opportunity, stage.code);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chuyển sang "${stage.label}".')),
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
