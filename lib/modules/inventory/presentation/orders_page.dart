import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../application/inventory_providers.dart';
import '../domain/order_list.dart';
import '../routes.dart';
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
    final now = ref.watch(inventoryTodayProvider);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final rows = res.valueOrNull;
    final List<Widget> list = [
      OmniSegmented(
        labels: const ['Cần thu', 'Đang xử lý', 'Tất cả'],
        counts: [
          if (due == null || due.awaiting == 0) null else due.awaiting,
          null,
          null,
        ],
        index: OrderListFilter.values.indexOf(_filter),
        onChanged: (i) => setState(() => _filter = OrderListFilter.values[i]),
      ),
      // Khối tổng (spec phong cách iOS §3.1): số tiền là số lớn nhất màn.
      if (due != null && due.outstanding > 0)
        OmniTotalCard(
          key: const ValueKey('orders-due'),
          label: 'Còn phải thu',
          trailingLabel: due.awaiting > 0 ? '${due.awaiting} đơn' : null,
          amount: Formatters.vnd(due.outstanding),
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
                dividerIndent: 16,
                children: [for (final o in group) _OrderRowTile(order: o)],
              ),
        ],
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: OmniAppBar(
        title: 'Đơn hàng',
        bottom: OmniSearchBottom(
          fieldKey: const ValueKey('orders-search'),
          hint: 'Tìm khách, mã đơn',
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      // Nút + kính qua OmniFabLayer (rà soát 12/11): một chỗ tính phần đáy bị
      // thanh kính + vùng an toàn che, không cộng tay.
      body: OmniFabLayer(
        // Tạo đơn = bán cây trong kho: cần quyền bán (`orders.write` +
        // `inventory.reserve`), như nút Bán ở Tồn kho.
        fab: perms.sell
            ? OmniLiquidFab(
                key: const ValueKey('orders-create'),
                tooltip: 'Tạo đơn',
                onPressed: (_) => _create(),
              )
            : null,
        body: OmniTopBarOverlap.wrap(
          child: Builder(
            builder: (context) {
              final topInset = OmniTopBarOverlap.of(context);
              return RefreshIndicator(
                edgeOffset: topInset,
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topInset + 4,
                    16,
                    OmniFabLayer.listBottom(context, hasFab: perms.sell),
                  ),
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: OmniGroupSection.gap),
                      list[i],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrderRowTile extends StatelessWidget {
  const _OrderRowTile({required this.order});
  final OrderRow order;

  /// "5 cây: KAWAI BL-71, …" → "5 cây". Tên hàng tự do (đơn cũ) giữ nguyên.
  static String? _unitCount(String product) {
    final p = product.trim();
    if (p.isEmpty) return null;
    final m = RegExp(r'^(\d+ cây)\b').firstMatch(p);
    return m?.group(1) ?? p;
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final router = GoRouter.maybeOf(context);
    final money = o.remaining > 0 ? o.remaining : o.value;
    final (label, tone) = o.cancelled
        ? ('Đã huỷ', OmniTone.neutral)
        : switch (o.payStatus) {
            OrderPayStatus.unpaid => (o.payStatus.label, OmniTone.warning),
            OrderPayStatus.partial => (o.payStatus.label, OmniTone.info),
            OrderPayStatus.paid => (o.payStatus.label, OmniTone.success),
          };

    return OmniMoneyRow(
      key: ValueKey('order-row-${o.id}'),
      title: o.customerName.isEmpty ? o.code : o.customerName,
      amount: Formatters.vnd(money),
      // Dòng phụ chỉ "mã · n cây" (spec §3.1): danh sách model ở màn chi tiết.
      subtitle: Text([o.code, ?_unitCount(o.product)].join(' · ')),
      status: OmniStatusLabel(label: label, tone: tone),
      onTap: router == null
          ? null
          : () => router.pushNamed(
              InventoryRoutes.order,
              pathParameters: {'orderId': o.id},
            ),
    );
  }
}
