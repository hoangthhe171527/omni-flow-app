import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_tab_routes.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';
import '../routes.dart';
import 'widgets/create_lot_sheet.dart';
import 'widgets/inventory_intro.dart';
import 'widgets/inventory_ui.dart';

/// Hàng sắp về (rà soát app mobile 12/11, `#s-sap-ve`): tìm mã lô / nhà cung
/// cấp, lô chia hai nhóm Đang về (gồm lô đã đặt hàng) / Đã về kho, vạch đặt
/// trước, tỷ lệ tạm / ước (quyền giá), còn nợ nhà cung cấp (quyền thanh toán
/// lô); tạo lô bằng nút + kính góc phải dưới.
///
/// Nút Nhà cung cấp trên thanh vẫn giữ: module không được import tầng `app/`
/// nên không biết đang ở khung ứng dụng (có tab NCC) hay giao diện cũ.
class LotsPage extends ConsumerStatefulWidget {
  const LotsPage({super.key});

  @override
  ConsumerState<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends ConsumerState<LotsPage> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowInventoryIntro(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final lots = ref.watch(lotsProvider);
    final bottom = OmniFabLayer.listBottom(context, hasFab: perms.write);

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Hàng sắp về',
        actions: [
          // Đợt A: Nhà cung cấp — hồ sơ và công nợ theo lô.
          // Khung ứng dụng có tab NCC → không lặp lối vào trên header.
          if (perms.suppliers &&
              !ShellTabRoutes.reachable(context, InventoryRoutes.suppliers))
            IconButton(
              key: const ValueKey('inv-open-suppliers'),
              tooltip: 'Nhà cung cấp',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => context.pushNamed(InventoryRoutes.suppliers),
              icon: Icon(
                Icons.storefront_outlined,
                size: OmniIconSize.md,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: !perms.read
          ? const OmniEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Chưa có quyền xem kho',
            )
          : OmniAsyncView<List<Lot>>(
              value: lots,
              onRetry: () => ref.invalidate(lotsProvider),
              loading: const OmniSkeletonList(count: 6, height: 72),
              data: (all) {
                final q = _q.trim().toLowerCase();
                bool hit(Lot l) =>
                    q.isEmpty ||
                    l.code.toLowerCase().contains(q) ||
                    (l.supplierName?.toLowerCase().contains(q) ?? false);
                List<Lot> of(LotStatus s) => [
                  for (final l in all)
                    if (l.status == s && hit(l)) l,
                ];
                // Đang về gồm cả lô mới đặt hàng (đang đi trước, đặt sau).
                final coming = [
                  ...of(LotStatus.inTransit),
                  ...of(LotStatus.ordered),
                ];
                final received = of(LotStatus.received);
                final open = [
                  for (final l in all)
                    if (l.status != LotStatus.received) l,
                ];
                final inTransitAll = [
                  for (final l in open)
                    if (l.status == LotStatus.inTransit) l,
                ];
                final dueJpy = open.fold<double>(
                  0,
                  // Lô trả dư không làm giảm tổng còn nợ.
                  (s, l) => s + ((l.dueJpy ?? 0) > 0 ? l.dueJpy! : 0),
                );
                final resv = open.fold<int>(0, (s, l) => s + l.withCustomer);
                final units = inTransitAll.fold<int>(0, (s, l) => s + l.units);

                final list = RefreshIndicator(
                  onRefresh: () => ref.refresh(lotsProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
                    children: [
                      SizedBox(
                        height: 44,
                        child: OmniSearchField(
                          key: const ValueKey('inv-lot-search'),
                          hint: 'Tìm mã lô, nhà cung cấp',
                          flat: true,
                          dense: true,
                          onChanged: (v) => setState(() => _q = v),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OmniGroupSection(
                        children: [
                          OmniGroupRow(
                            title: 'Đang về',
                            value:
                                '${inTransitAll.length} lô · ${InventoryFormat.number(units)} cây',
                          ),
                          OmniGroupRow(
                            title: 'Đặt trước',
                            value: '${InventoryFormat.number(resv)} cây',
                          ),
                          if (perms.pay)
                            OmniGroupRow(
                              title: 'Còn nợ NCC',
                              value: InventoryFormat.yen(dueJpy),
                            ),
                        ],
                      ),
                      for (final (title, group) in [
                        ('Đang về', coming),
                        ('Đã về kho', received),
                      ])
                        if (group.isNotEmpty) ...[
                          const SizedBox(height: OmniGroupSection.gap),
                          OmniGroupSection(
                            title: title,
                            trailingTitle: Text(
                              '${group.length}',
                              style: invMuted(context),
                            ),
                            children: [
                              for (final l in group)
                                LotRow(
                                  key: ValueKey('inv-lot-${l.id}'),
                                  lot: l,
                                  perms: perms,
                                  onTap: () => context.pushNamed(
                                    InventoryRoutes.lot,
                                    pathParameters: {'lotId': l.id},
                                  ),
                                ),
                            ],
                          ),
                        ],
                      if (coming.isEmpty && received.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: OmniGroupSection(
                            children: [OmniGroupRow(title: 'Không có lô khớp')],
                          ),
                        ),
                    ],
                  ),
                );
                return OmniFabLayer(
                  body: list,
                  fab: perms.write
                      ? OmniLiquidFab(
                          key: const ValueKey('inv-lot-create'),
                          tooltip: 'Tạo lô',
                          onPressed: (_) => _create(all),
                        )
                      : null,
                );
              },
            ),
    );
  }

  Future<void> _create(List<Lot> all) async {
    final lot = await openCreateLotSheet(context, lots: all);
    if (lot == null || !mounted) return;
    InvUi.toast(context, 'Đã tạo lô ${lot.code}');
    context.pushNamed(InventoryRoutes.lot, pathParameters: {'lotId': lot.id});
  }
}

/// Một lô: mã · nhà cung cấp, số cây · đặt trước, vạch đặt trước, tỷ lệ (quyền
/// giá) và còn nợ (quyền thanh toán).
class LotRow extends StatelessWidget {
  const LotRow({
    super.key,
    required this.lot,
    required this.perms,
    required this.onTap,
  });

  final Lot lot;
  final InventoryPerms perms;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = lot;
    final muted = invMuted(context);
    final lines = <String>[
      if (perms.cost && l.rateApplied != null)
        l.costFinal
            ? 'Đã chốt ${InventoryFormat.rate(l.rateApplied)}'
            : [
                'Tạm ${InventoryFormat.rate(l.rateApplied)}',
                if (l.rateEstimate != null && l.rateManual)
                  'ước ${InventoryFormat.rate(l.rateEstimate)}',
              ].join(' · '),
      if (perms.pay) lotDebtLine(l),
    ];
    final ratio = l.units == 0
        ? 0.0
        : (l.withCustomer / l.units).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            OmniIconTile(
              l.status == LotStatus.inTransit
                  ? Icons.local_shipping_outlined
                  : Icons.inventory_2_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    l.units == 0
                        ? 'Chưa có packing list'
                        : '${l.units} cây · đặt trước ${l.withCustomer}',
                    style: muted,
                  ),
                  if (l.units > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(
                                  color: OmniColors.trackOf(context),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: ratio,
                                child: ColoredBox(color: scheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  for (final s in lines) Text(s, style: muted),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Còn nợ 1.850.000 ¥" / "Đã cọc 1.000.000 ¥" / "Thuế phí chưa trả …" /
/// "Đã trả đủ" — chỉ gọi khi có quyền thanh toán lô.
String lotDebtLine(Lot l) {
  final due = l.dueJpy ?? 0;
  if (l.units == 0 && (l.paidJpy ?? 0) > 0) {
    return 'Đã cọc ${InventoryFormat.yen(l.paidJpy)}';
  }
  if (due > 0) return 'Còn nợ ${InventoryFormat.yen(due)}';
  if ((l.plannedVnd ?? 0) > 0) {
    return 'Thuế phí chưa trả ${InvUi.vnd(l.plannedVnd)}';
  }
  return 'Đã trả đủ';
}
