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

    final scheme = Theme.of(context).colorScheme;
    final meta = OmniColors.chat(
      context,
      OmniColors.chatMeta,
      OmniColors.chatMetaDark,
    );

    return Scaffold(
      // Header and list on one plane — the AppBar's `background` against the
      // rows' `surface` is what draws a phantom frame around the search area.
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Khách hàng'),
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(89),
          child: Column(
            children: [
              // Same flat search line as the inbox: icon, word, no box. The
              // shared OmniSearchField carries the global `filled: true`, which
              // is the dim panel this screen had behind its search text.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 22, color: meta),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: filter.search)
                          ..selection = TextSelection.collapsed(
                            offset: filter.search.length,
                          ),
                        onChanged: controller.setSearch,
                        textInputAction: TextInputAction.search,
                        style: OmniType.body.copyWith(
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Tìm tên, số điện thoại',
                          hintStyle: OmniType.body.copyWith(
                            fontSize: 16,
                            color: meta,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: CustomerQuickFilter.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: OmniSpacing.sm),
                  itemBuilder: (context, index) {
                    final quick = CustomerQuickFilter.values[index];
                    return Center(
                      child: OmniFilterPill(
                        label: quick.label,
                        selected: filter.quick == quick,
                        onTap: () => controller.setQuick(quick),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Divider(
                height: 1,
                thickness: 1,
                color: OmniColors.chat(
                  context,
                  OmniColors.chatDivider,
                  OmniColors.chatDividerDark,
                ),
              ),
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
          data: (state) => OmniDesktopFrame(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              // Hairline indented past the avatar, not a gap between cards.
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                indent: 76,
                color: OmniColors.chat(
                  context,
                  OmniColors.chatDivider,
                  OmniColors.chatDividerDark,
                ),
              ),
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

    // Two lines and a hairline, like the inbox. It was a bordered card with a
    // THIRD line carrying a source pill, two tags, an owner avatar and a
    // relative time — six competing objects per customer, and 200 of them made
    // a wall. Source, tags and owner all live on the detail page, which is where
    // a rep acts on them; the list only has to answer "who, and are they warm".
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => context.pushNamed(
          CustomersModule.detail,
          pathParameters: {'id': customer.id},
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              OmniAvatar(name: customer.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.body.copyWith(
                              fontSize: 16,
                              height: 1.2,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.relative(customer.lastInteractionAt),
                          style: OmniChatType.meta.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (customer.phone.isNotEmpty) customer.phone,
                              if (customer.city.isNotEmpty) customer.city,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.caption.copyWith(
                              fontSize: 14,
                              height: 1.25,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        // Lifetime value is the one number worth scanning a
                        // customer list for, so it keeps its place — right
                        // aligned and tabular so the column reads straight down.
                        if (customer.lifetimeValue > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            Formatters.vndCompact(customer.lifetimeValue),
                            style: OmniType.caption.copyWith(
                              fontSize: 14,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontFeatures: OmniType.tabular,
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
        ),
      ),
    );
  }
}
