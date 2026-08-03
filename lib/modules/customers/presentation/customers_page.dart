import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../domain/customer.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 400) {
        ref.read(customerListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(customerListProvider);
    final filter = ref.watch(customerFilterProvider);
    final access = ref.watch(customerAccessProvider);
    final controller = ref.read(customerFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        titleSpacing: OmniSpacing.lg,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  0,
                  OmniSpacing.lg,
                  OmniSpacing.md,
                ),
                child: OmniSearchField(
                  hint: 'Tìm tên, số điện thoại...',
                  initialValue: filter.search,
                  onChanged: controller.setSearch,
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
                  itemCount: CustomerQuickFilter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
                  itemBuilder: (context, index) {
                    final quick = CustomerQuickFilter.values[index];
                    return OmniFilterPill(
                      label: quick.label,
                      selected: filter.quick == quick,
                      onTap: () => controller.setQuick(quick),
                    );
                  },
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
            ],
          ),
        ),
      ),
      floatingActionButton: access.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(CustomersModule.create),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm khách'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerListProvider.notifier).refresh(),
        child: OmniAsyncView(
          value: list,
          onRetry: () => ref.invalidate(customerListProvider),
          isEmpty: (state) => state.items.isEmpty,
          empty: OmniEmptyState(
            icon: Icons.people_outline_rounded,
            title: filter.search.isEmpty
                ? 'Chưa có khách hàng'
                : 'Không tìm thấy khách hàng',
            message: filter.search.isEmpty
                ? 'Khách từ hộp thư sẽ tự động xuất hiện ở đây khi được chuyển đổi.'
                : 'Thử từ khoá khác hoặc bỏ bớt bộ lọc.',
            actionLabel: access.canCreate ? 'Thêm khách hàng' : null,
            onAction: () => context.pushNamed(CustomersModule.create),
          ),
          data: (state) => ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.md,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(OmniSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return CustomerCard(customer: state.items[index]);
            },
          ),
        ),
      ),
    );
  }
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniCard(
      padding: const EdgeInsets.all(OmniSpacing.md),
      onTap: () => context.pushNamed(
        CustomersModule.detail,
        pathParameters: {'id': customer.id},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OmniAvatar(name: customer.name),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    Text(
                      Formatters.vndCompact(customer.lifetimeValue),
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (customer.phone.isNotEmpty) customer.phone,
                    if (customer.city.isNotEmpty) customer.city,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: OmniSpacing.sm),
                Row(
                  children: [
                    OmniSourcePill(channel: customer.source, compact: true),
                    const SizedBox(width: OmniSpacing.xs),
                    for (final tag in customer.tags.take(2)) ...[
                      OmniTag(label: tag),
                      const SizedBox(width: OmniSpacing.xs),
                    ],
                    const Spacer(),
                    if (customer.ownerName != null)
                      OmniAvatar(name: customer.ownerName!, size: 20),
                    const SizedBox(width: OmniSpacing.sm),
                    Text(
                      Formatters.relative(customer.lastInteractionAt),
                      style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
