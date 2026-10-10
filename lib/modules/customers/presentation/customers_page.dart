import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../domain/customer.dart';
import 'widgets/customer_filter_panel.dart';
import 'widgets/customer_row.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _scrollController = ScrollController();
  bool _filtersOpen = false;

  /// Chỉ một dòng mở hàng thao tác nhanh một lúc.
  String? _openId;

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Header và danh sách cùng một mặt phẳng.
      backgroundColor: scheme.surface,
      appBar: OmniTopBar(
        bottom: CustomerSearchRow(
          filtersOpen: _filtersOpen,
          onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
          trailing: [
            // Thanh tab không có "+": Thêm khách là nút vuông ở hàng tìm.
            if (access.canCreate) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Thêm khách',
                onPressed: () => context.pushNamed(CustomersModule.create),
                style: IconButton.styleFrom(
                  fixedSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_rounded),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          CustomerFilterPanel(open: _filtersOpen),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(customerListProvider.notifier).refresh(),
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
                data: (state) => ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    bottom: OmniSpacing.bottomSafe,
                  ),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
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
                    final customer = state.items[index];
                    return CustomerRow(
                      customer: customer,
                      expanded: _openId == customer.id,
                      onTap: () => setState(
                        () => _openId = _openId == customer.id
                            ? null
                            : customer.id,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
