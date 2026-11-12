import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/order_list.dart';
import '../routes.dart';
import 'delivered_page.dart' show InvSearchBottom;
import 'widgets/inventory_ui.dart';
import 'widgets/pick_order_units_sheet.dart';
import 'widgets/sell_sheet.dart';

/// Danh sách đơn (bản mẫu NWUQNP "Danh sách đơn"): ô tìm, lọc Cần thu / Đang
/// xử lý / Tất cả, dòng "Còn phải thu — số", đơn gom theo thời gian, nút +
/// tạo đơn (chọn đàn → tấm Bán).
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  OrderListFilter _filter = OrderListFilter.due;
  String _q = '';

  Future<void> _create() async {
    final units = await pickOrderUnits(context);
    if (units == null || units.isEmpty || !mounted) return;
    final ok = await openSellSheet(context, units: units, title: 'Tạo đơn');
    if (ok) bumpOrders(ref);
  }

  @override
  Widget build(BuildContext context) {
    final query = (filter: _filter, q: _q);
    final res = ref.watch(ordersListProvider(query));
    final due = ref.watch(ordersDueProvider).valueOrNull;
    final perms = ref.watch(inventoryPermsProvider);
    final bottom =
        ShellBarInset.of(context) + MediaQuery.viewPaddingOf(context).bottom;
    final now = ref.watch(inventoryTodayProvider);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final rows = res.valueOrNull;
    final List<Widget> list = [
      OmniSegmented(
        labels: [
          due == null || due.awaiting == 0
              ? 'Cần thu'
              : 'Cần thu ${due.awaiting}',
          'Đang xử lý',
          'Tất cả',
        ],
        index: OrderListFilter.values.indexOf(_filter),
        onChanged: (i) => setState(() => _filter = OrderListFilter.values[i]),
      ),
      if (due != null && due.outstanding > 0)
        OmniGroupSection(
          key: const ValueKey('orders-due'),
          children: [
            OmniGroupRow(
              title: 'Còn phải thu',
              value: Formatters.vnd(due.outstanding),
            ),
          ],
        ),
      ...switch (res) {
        AsyncValue(:final error?) when rows == null => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(ordersListProvider(query)),
          ),
        ],
        _ when rows == null => [const InvSkeleton(count: 5, height: 64)],
        _ when rows.isEmpty => [
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có đơn nào')],
          ),
        ],
        _ => [
          for (final (title, group) in [
            (
              'Tuần này',
              [
                for (final o in rows)
                  if (o.createdAt != null && !o.createdAt!.isBefore(weekStart))
                    o,
              ],
            ),
            (
              'Trước đó',
              [
                for (final o in rows)
                  if (o.createdAt == null || o.createdAt!.isBefore(weekStart))
                    o,
              ],
            ),
          ])
            if (group.isNotEmpty)
              OmniGroupSection(
                key: ValueKey('orders-group-$title'),
                title: title,
                children: [for (final o in group) _OrderRowTile(order: o)],
              ),
        ],
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: OmniAppBar(
        title: 'Đơn hàng',
        bottom: InvSearchBottom(
          fieldKey: const ValueKey('orders-search'),
          hint: 'Tìm khách, mã đơn',
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async {
                bumpOrders(ref);
                await ref
                    .read(ordersListProvider(query).future)
                    .catchError((_) => const <OrderRow>[]);
              },
              child: ListView(
                key: const ValueKey('orders-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 96),
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const SizedBox(height: OmniGroupSection.gap),
                    list[i],
                  ],
                ],
              ),
            ),
          ),
          // Tạo đơn = bán cây trong kho: cần quyền bán (`orders.write` +
          // `inventory.reserve`), như nút Bán ở Tồn kho.
          if (perms.sell)
            Positioned(
              right: 20,
              bottom: bottom + 16,
              child: OmniLiquidFab(
                tooltip: 'Tạo đơn',
                onPressed: (_) => _create(),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderRowTile extends StatelessWidget {
  const _OrderRowTile({required this.order});
  final OrderRow order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final scheme = Theme.of(context).colorScheme;
    final router = GoRouter.maybeOf(context);
    final money = o.remaining > 0 ? o.remaining : o.value;
    final payColor = switch (o.payStatus) {
      OrderPayStatus.unpaid => OmniColors.warningTextOf(context),
      OrderPayStatus.partial => scheme.primary,
      OrderPayStatus.paid => scheme.onSurfaceVariant,
    };

    return OmniGroupRow(
      key: ValueKey('order-row-${o.id}'),
      title: o.customerName.isEmpty ? o.code : o.customerName,
      subtitle: [
        o.code,
        if (o.product.isNotEmpty) o.product,
        if (o.cancelled) 'Đã huỷ',
      ].join(' · '),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.vnd(money),
            style: OmniType.body.copyWith(
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            o.payStatus.label,
            style: OmniType.caption.copyWith(color: payColor),
          ),
        ],
      ),
      onTap: router == null
          ? null
          : () => router.pushNamed(
              InventoryRoutes.order,
              pathParameters: {'orderId': o.id},
            ),
    );
  }
}
