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
    final meta = scheme.onSurfaceVariant;

    return Scaffold(
      // Header and list on one plane — the AppBar's `background` against the
      // rows' `surface` is what draws a phantom frame around the search area.
      backgroundColor: scheme.surface,
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Khách hàng',
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Column(
            children: [
              // Same flat search line as the inbox: icon, word, no box. The
              // shared OmniSearchField carries the global `filled: true`, which
              // is the dim panel this screen had behind its search text.
              // Ô tìm xám bo 12 như hộp thư (`MCustomers.dc.html`).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: OmniRadius.mdAll,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: OmniIconSize.md,
                        color: meta,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: filter.search)
                            ..selection = TextSelection.collapsed(
                              offset: filter.search.length,
                            ),
                          onChanged: controller.setSearch,
                          textInputAction: TextInputAction.search,
                          style: OmniType.input.copyWith(
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
                            hintStyle: OmniType.input.copyWith(color: meta),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
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
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
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
            padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            // Hairline indented past the avatar, not a gap between cards.
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 1,
              indent: 82,
              color: scheme.outlineVariant,
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
    );
  }
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inactive = customer.status == CustomerStatus.inactive;
    final badge = customerStatusBadge(customer.status);

    // Ba dòng theo `MCustomers.dc.html`: tên + huy hiệu trạng thái; số điện
    // thoại · nơi ở + tổng giá trị; lần liên hệ gần nhất. Khách ngưng hoạt
    // động lùi cả tên lẫn số tiền về chữ phụ.
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: () => context.pushNamed(
          CustomersModule.detail,
          pathParameters: {'id': customer.id},
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              OmniAvatar(name: customer.name, size: 48),
              const SizedBox(width: 14),
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
                            style: OmniType.listTitle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: inactive
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (badge != null) ...[const SizedBox(width: 8), badge],
                      ],
                    ),
                    const SizedBox(height: 3),
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
                            style: OmniType.body.copyWith(
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
                            style: OmniType.body.copyWith(
                              color: inactive
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontFeatures: OmniType.tabular,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (customer.lastInteractionAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Liên hệ ${_ago(customer.lastInteractionAt)}',
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

/// Huy hiệu trạng thái trên dòng khách: VIP vàng, Mới xanh dương, Ngưng xám.
/// "Đang hoạt động" là trạng thái thường — không cần huy hiệu.
Widget? customerStatusBadge(CustomerStatus status, {bool large = false}) =>
    switch (status) {
      CustomerStatus.vip => OmniBadge(
        label: 'VIP',
        tone: OmniTone.warning,
        icon: large ? Icons.star_rounded : null,
        large: large,
      ),
      CustomerStatus.fresh => OmniBadge(
        label: 'Mới',
        tone: OmniTone.info,
        large: large,
      ),
      CustomerStatus.inactive => OmniBadge(label: 'Ngưng', large: large),
      CustomerStatus.active => null,
    };

/// "18 phút trước", "Hôm qua", "12/08" — thêm "trước" chỉ khi đó là một
/// khoảng thời gian, không phải một ngày.
String _ago(DateTime? value) {
  final text = Formatters.relative(value);
  final span = RegExp(r'^\d+ (phút|giờ|ngày)$').hasMatch(text);
  return span ? '$text trước' : text;
}
