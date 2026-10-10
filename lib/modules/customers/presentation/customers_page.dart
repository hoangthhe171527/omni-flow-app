import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/module/extra_segment.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/permissions/resource_access.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../domain/customer.dart';
import 'widgets/customer_filter_panel.dart';
import 'widgets/customer_row.dart';

/// Tab Khách: hai đoạn — danh sách khách và (khi có quyền + cờ bật) đoạn Cơ
/// hội. `/customers?seg=co-hoi` mở thẳng đoạn Cơ hội.
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key, this.initialSegment = 0});

  /// 0 = Khách hàng, 1 = Cơ hội.
  final int initialSegment;

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _scrollController = ScrollController();
  bool _filtersOpen = false;
  bool _oppFiltersOpen = false;
  late int _segment = widget.initialSegment;

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
  void didUpdateWidget(CustomersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đường dẫn sâu đổi `?seg=` khi màn đã mở.
    if (oldWidget.initialSegment != widget.initialSegment) {
      _segment = widget.initialSegment;
    }
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

    // Đổi lọc/tìm kiếm là danh sách khác: dòng đang mở không còn nghĩa.
    ref.listen(customerFilterProvider, (_, _) {
      if (_openId != null) setState(() => _openId = null);
    });

    // Đoạn Cơ hội chỉ khi được đọc cơ hội VÀ workspace bật tính năng; không
    // thì không có thanh chọn đoạn, kể cả khi đường dẫn đòi `?seg=co-hoi`.
    final extra = ref.watch(khachExtraSegmentProvider);
    final showSegments = extra != null && extra.visible(ref);
    final segment = showSegments ? _segment.clamp(0, 1) : 0;
    final customerTotal = list.valueOrNull?.pagination.total;

    return Scaffold(
      // Header và danh sách cùng một mặt phẳng.
      backgroundColor: scheme.surface,
      appBar: OmniTopBar(
        bottom: _KhachHeaderBottom(
          showSegments: showSegments,
          segment: segment,
          labels: [
            customerTotal == null
                ? 'Khách hàng'
                : 'Khách hàng · $customerTotal',
            if (showSegments) extra.label(ref),
          ],
          onSegment: (i) => setState(() => _segment = i),
          search: segment == 1
              ? extra!.searchRow(
                  _oppFiltersOpen,
                  () => setState(() => _oppFiltersOpen = !_oppFiltersOpen),
                )
              : CustomerSearchRow(
                  filtersOpen: _filtersOpen,
                  onToggleFilters: () =>
                      setState(() => _filtersOpen = !_filtersOpen),
                  trailing: [
                    // Thanh tab không có "+": Thêm khách là nút vuông ở hàng tìm.
                    if (access.canCreate) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Thêm khách',
                        onPressed: () =>
                            context.pushNamed(CustomersModule.create),
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
      ),
      body: _SegmentSwitcher(
        segment: segment,
        child: segment == 1
            ? extra!.body(_oppFiltersOpen)
            : _customersBody(list, filter, access),
      ),
    );
  }

  Widget _customersBody(
    AsyncValue<CustomerListState> list,
    CustomerFilter filter,
    ResourceAccess access,
  ) {
    return Column(
      key: const ValueKey('khach-seg-khach-hang'),
      children: [
        CustomerFilterPanel(open: _filtersOpen),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              setState(() => _openId = null);
              return ref.read(customerListProvider.notifier).refresh();
            },
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
                padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
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
                      () =>
                          _openId = _openId == customer.id ? null : customer.id,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phần dưới header của tab Khách: thanh chọn đoạn (khi có) rồi hàng tìm của
/// đoạn đang chọn.
class _KhachHeaderBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const _KhachHeaderBottom({
    required this.showSegments,
    required this.segment,
    required this.labels,
    required this.onSegment,
    required this.search,
  });

  final bool showSegments;
  final int segment;
  final List<String> labels;
  final ValueChanged<int> onSegment;
  final PreferredSizeWidget search;

  @override
  Size get preferredSize => Size.fromHeight(
    search.preferredSize.height + (showSegments ? 44 + 8 : 0),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSegments)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OmniSegmented(
              labels: labels,
              index: segment,
              onChanged: onSegment,
            ),
          ),
        search,
      ],
    );
  }
}

/// Chuyển đoạn: đoạn mới trượt vào 24px từ phía chuyển tới, đoạn cũ trượt ra
/// phía ngược lại. Tắt chuyển động thì đổi ngay.
class _SegmentSwitcher extends StatelessWidget {
  const _SegmentSwitcher({required this.segment, required this.child});

  final int segment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.enabled(context);
    final width = MediaQuery.sizeOf(context).width;
    // Đoạn 1 vào từ phải (+), đoạn 0 vào từ trái (-).
    final direction = segment == 1 ? 1.0 : -1.0;
    final shift = width == 0 ? 0.0 : 24 / width;

    return AnimatedSwitcher(
      duration: motion ? const Duration(milliseconds: 250) : Duration.zero,
      switchInCurve: OmniCurves.standard,
      switchOutCurve: OmniCurves.standard,
      layoutBuilder: (current, previous) => Stack(
        children: [
          for (final widget in [...previous, ?current])
            Positioned.fill(child: widget),
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        final begin = Offset((incoming ? direction : -direction) * shift, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
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
