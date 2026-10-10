import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/module/customer_opportunities_section.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/opportunities_providers.dart';
import '../routes.dart';
import 'widgets/opportunity_row.dart';

/// Phần Cơ hội của hồ sơ khách, cắm vào `customerOpportunitiesSectionProvider`
/// ở gốc app. Chỉ hiện khi đọc được cơ hội VÀ workspace bật tính năng.
final opportunitiesCustomerSection = CustomerOpportunitiesSection(
  visible: (ref) =>
      ref.watch(opportunityAccessProvider).canRead &&
      ref.watch(sessionProvider).featureEnabled('opportunities'),
  canCreate: (ref) =>
      ref.watch(opportunityAccessProvider).canCreate &&
      ref.watch(sessionProvider).featureEnabled('opportunities'),
  stats: (ref, customerId) {
    final list = ref
        .watch(customerOpportunitiesProvider(customerId))
        .valueOrNull;
    if (list == null) return null;
    return (
      count: list.length,
      openValue: list
          .where((o) => !o.isClosed)
          .fold<double>(0, (sum, o) => sum + o.value),
    );
  },
  body: (customerId) => CustomerOpportunitiesTab(customerId: customerId),
  invalidate: (container, customerId) =>
      container.invalidate(customerOpportunitiesProvider(customerId)),
);

/// Đoạn Cơ hội của hồ sơ khách: danh sách `OpportunityRow`; rỗng (hoặc lỗi
/// tải) → "Chưa có cơ hội" + nút Tạo cơ hội khi được tạo.
class CustomerOpportunitiesTab extends ConsumerWidget {
  const CustomerOpportunitiesTab({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final opps = ref.watch(customerOpportunitiesProvider(customerId));
    final catalog = ref.watch(pipelineCatalogProvider).valueOrNull;
    final canCreate =
        ref.watch(opportunityAccessProvider).canCreate &&
        ref.watch(sessionProvider).featureEnabled('opportunities');

    if (opps.isLoading && !opps.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(OmniSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // Lỗi đọc cơ hội = coi như chưa có (không chặn phần còn lại của hồ sơ).
    final items = opps.valueOrNull ?? const [];
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(OmniSpacing.section),
        child: Column(
          children: [
            Text(
              'Chưa có cơ hội',
              style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (canCreate) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.pushNamed(
                  OpportunityRoutes.create,
                  queryParameters: {'customer': customerId},
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Tạo cơ hội'),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final o in items)
          OpportunityRow(
            opportunity: o,
            pipeline: catalog?.pipelineOf(o.pipelineCode),
          ),
      ],
    );
  }
}
