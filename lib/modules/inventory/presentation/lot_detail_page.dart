import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';
import '../routes.dart';
import 'lots_page.dart' show lotDebtLine;
import 'widgets/add_unit_sheet.dart';
import 'widgets/claim_sheet.dart';
import 'widgets/cost_sheet.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/money_keypad_sheet.dart';
import 'widgets/paste_sheet.dart';
import 'widgets/pay_costs_sheet.dart';
import 'widgets/sell_sheet.dart';
import 'widgets/serial_field.dart';
import 'widgets/unit_sheet.dart';

/// Chi tiết lô: tóm tắt, tiền & giá vốn (tỷ lệ · giá vốn lô · còn thiếu, "Dùng
/// ước tính", khoản trả hai loại), Thêm cây, danh sách cây gom theo model,
/// khay kính đáy Nhận hàng / Ghi đã trả (rà soát 12/11, `#s-nhan-hang`).
///
/// Kho chuẩn hóa Đợt A (`inventory.claims`): tổng ¥ dự kiến (sửa khi có quyền
/// thanh toán lô), phải trả nhà cung cấp sau khoản được trừ, trả dư; khoản đòi
/// cây thiếu / lỗi — đổi cách xử lý, đánh dấu đã giải quyết.
class LotDetailPage extends ConsumerStatefulWidget {
  const LotDetailPage({super.key, required this.lotId});

  final String lotId;

  @override
  ConsumerState<LotDetailPage> createState() => _LotDetailPageState();
}

enum _Seg { all, free, held }

class _LotDetailPageState extends ConsumerState<LotDetailPage> {
  _Seg _seg = _Seg.all;
  final _open = <String>{};
  bool _payOpen = false;
  bool _busy = false;

  /// "Trả nhiều khoản": đang chọn khoản dự kiến để ghi đã trả một lần.
  bool _pmsOn = false;
  final _pms = <String>{};

  Future<void> _payMany(Lot lot) async {
    final costs = [
      for (final c in lot.costs ?? const <LotCost>[])
        if (_pms.contains(c.id) && c.status == CostStatus.planned) c,
    ];
    if (costs.isEmpty) return;
    final msg = await openPayCostsSheet(context, lot: lot, costs: costs);
    if (msg == null || !mounted) return;
    setState(() {
      _pmsOn = false;
      _pms.clear();
    });
    InvUi.toast(context, msg);
  }

  Future<void> _useEstimate(Lot lot) async {
    setState(() => _busy = true);
    try {
      final l = await ref.read(inventoryApiProvider).setRate(lot.id, null);
      bumpInventory(ref);
      if (mounted) {
        InvUi.toast(
          context,
          'Tỷ lệ tạm ${InventoryFormat.rate(l.rateApplied)}.',
        );
      }
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRate(Lot lot) async {
    final typed = await showOmniPrompt(
      context: context,
      title: 'Tỷ lệ tạm ₫/¥',
      confirmLabel: 'Lưu',
      initialValue: InventoryFormat.rate(lot.rateApplied),
      hintText: '185,5',
      maxLength: 8,
      fieldKey: const ValueKey('inv-rate-field'),
    );
    if (typed == null || !mounted) return;
    final v = double.tryParse(typed.trim().replaceAll(',', '.'));
    if (v == null || v < 1 || v > 1000) {
      InvUi.toast(context, 'Tỷ lệ không hợp lệ.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(inventoryApiProvider).setRate(lot.id, v);
      bumpInventory(ref);
      if (mounted) {
        InvUi.toast(context, 'Tỷ lệ tạm: ${InventoryFormat.rate(v)}.');
      }
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editExpected(Lot lot) async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Tổng ¥ dự kiến',
      subtitle: lot.code,
      initial: lot.expectedJpy,
      unit: '¥',
    );
    if (v == null || !mounted || v == lot.expectedJpy?.round()) return;
    setState(() => _busy = true);
    try {
      await ref.read(inventoryApiProvider).setExpectedJpy(lot.id, v);
      bumpInventory(ref);
      if (mounted) InvUi.toast(context, 'Đã lưu tổng ¥ dự kiến.');
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openClaim(LotClaim c, String unitName) async {
    final msg = await openClaimSheet(context, claim: c, unitName: unitName);
    if (msg != null && mounted) InvUi.toast(context, msg);
  }

  /// Tổng ¥ dự kiến, phải trả nhà cung cấp, trả dư. API cũ không có khoá
  /// `debt_base_jpy` (hoặc thiếu quyền thanh toán) → không có nhóm.
  List<Widget> _yen(Lot lot, InventoryPerms perms) {
    final base = lot.debtBaseJpy;
    if (!perms.claims || base == null) return const [];
    return [
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        key: const ValueKey('inv-lot-yen'),
        children: [
          OmniGroupRow(
            key: const ValueKey('inv-lot-expected'),
            title: 'Tổng ¥ dự kiến',
            trailing: InvValue(
              lot.expectedJpy == null
                  ? '—'
                  : InventoryFormat.yen(lot.expectedJpy),
            ),
            chevron: perms.pay,
            onTap: perms.pay && !_busy ? () => _editExpected(lot) : null,
          ),
          OmniGroupRow(
            title: 'Phải trả nhà cung cấp',
            trailing: InvValue(InventoryFormat.yen(base)),
          ),
          if ((lot.prepaidJpy ?? 0) > 0)
            OmniGroupRow(
              title: 'Trả dư',
              trailing: InvValue(InventoryFormat.yen(lot.prepaidJpy)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _claims(
    Lot lot,
    List<InventoryUnit> units,
    InventoryPerms perms,
  ) {
    final claims = lot.claims ?? const <LotClaim>[];
    if (!perms.claims || claims.isEmpty) return const [];
    final byId = {for (final u in units) u.id: u};
    return [
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        key: const ValueKey('inv-lot-claims'),
        title: 'Khoản đòi nhà cung cấp',
        dividerIndent: 14,
        children: [
          for (final c in claims)
            () {
              final u = byId[c.unitId];
              final name = u == null ? 'Cây' : '#${u.lineNo} ${u.name}';
              final detail = [
                c.kindLabel,
                if (u?.serial != null) u!.serial!,
                if (perms.cost && (c.debtCutJpy ?? 0) > 0)
                  'trừ ${InventoryFormat.yen(c.debtCutJpy)}',
              ].join(' · ');
              return OmniGroupRow(
                key: ValueKey('inv-claim-row-${c.id}'),
                title: name,
                // Dòng phụ 1: cách xử lý; dòng 2: loại · serial · số ¥ trừ.
                subtitle: '${ClaimResolution.labelOf(c.resolution)}\n$detail',
                value: c.settled ? 'Xong' : null,
                onTap: perms.pay ? () => _openClaim(c, name) : null,
              );
            }(),
        ],
      ),
    ];
  }

  void _tapUnit(InventoryUnit u, InventoryPerms perms) {
    if (u.place == UnitPlace.inStock) {
      openUnitSheet(context, unit: u, onChanged: (_) => bumpInventory(ref));
      return;
    }
    if (perms.reserve && u.sale != UnitSale.sold) {
      openSellSheet(context, units: [u], allowRetail: true);
      return;
    }
    showOmniSheet<void>(
      context: context,
      builder: (_) => _LotUnitInfo(unit: u, perms: perms),
    );
  }

  Future<void> _saveSerial(InventoryUnit u, String? s) async {
    try {
      final res = await ref.read(inventoryApiProvider).updateUnit(u.id, {
        'serial': s,
      });
      bumpInventory(ref);
      if (!mounted) return;
      InvUi.toast(
        context,
        res.warnings.any((w) => w.code == 'serial_taken')
            ? 'Serial $s trùng một cây ${u.maker} khác · đã lưu'
            : s == null
            ? 'Đã xoá serial.'
            : 'Đã lưu serial $s.',
      );
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final lotAsync = ref.watch(lotProvider(widget.lotId));
    final lot = lotAsync.valueOrNull;
    final unitsAsync = ref.watch(lotUnitsProvider(widget.lotId));
    final units = unitsAsync.valueOrNull ?? const <InventoryUnit>[];
    final canReceive =
        lot != null &&
        perms.write &&
        lot.status != LotStatus.received &&
        lot.units > 0;
    final payMany = lot != null && perms.pay && _pmsOn;
    final selected = [
      if (payMany)
        for (final c in lot.costs ?? const <LotCost>[])
          if (_pms.contains(c.id) && c.status == CostStatus.planned) c,
    ];
    final payTotal = lot == null
        ? 0
        : selected.fold<int>(0, (s, c) => s + plannedAmount(lot, c));
    // Khay kính đáy: Ghi đã trả (đang chọn khoản) hoặc Nhận hàng, bên trái là
    // dòng tóm tắt để biết nút sẽ làm gì.
    final OmniBottomDock? dock;
    if (lot != null && payMany && selected.isNotEmpty) {
      dock = OmniBottomDock(
        title: '${selected.length} khoản · ${InvUi.vnd(payTotal)}',
        action: FilledButton(
          key: const ValueKey('inv-lot-pay-many'),
          onPressed: () => _payMany(lot),
          child: const Text('Ghi đã trả'),
        ),
      );
    } else if (lot != null && !payMany && canReceive) {
      // Cây chưa nhận: đếm trên danh sách cây khi đã tải, không thì cả lô.
      final waiting = unitsAsync.hasValue
          ? units.where((u) => u.place == UnitPlace.incoming).length
          : lot.units;
      dock = OmniBottomDock(
        title: waiting > 0
            ? '${InventoryFormat.number(waiting)} cây chưa nhận'
            : null,
        action: FilledButton(
          key: const ValueKey('inv-lot-receive'),
          onPressed: () => context.pushNamed(
            InventoryRoutes.receive,
            pathParameters: {'lotId': lot.id},
          ),
          child: const Text('Nhận hàng'),
        ),
      );
    } else {
      dock = null;
    }

    return Scaffold(
      appBar: OmniAppBar(
        title: lot?.code ?? 'Lô',
        showAccount: false,
        fallbackBack: () =>
            GoRouter.maybeOf(context)?.go(InventoryRoutes.lotsPath),
      ),
      body: lot == null
          ? OmniAsyncView<Lot>(
              value: lotAsync,
              onRetry: () => ref.invalidate(lotProvider(widget.lotId)),
              loading: const OmniSkeletonList(count: 5, height: 56),
              data: (_) => const SizedBox.shrink(),
            )
          : OmniDockLayer(
              dock: dock,
              body: RefreshIndicator(
                onRefresh: () async => bumpInventory(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    dock == null
                        ? OmniFabLayer.listBottom(context, hasFab: false)
                        : OmniDockLayer.listBottom(context),
                  ),
                  children: [
                    ..._summary(lot, perms, units),
                    if (perms.write && lot.status != LotStatus.received) ...[
                      const SizedBox(height: OmniGroupSection.gap),
                      OmniGroupSection(
                        children: [
                          OmniGroupRow(
                            key: const ValueKey('inv-lot-paste'),
                            icon: Icons.content_paste_rounded,
                            accent: true,
                            title: 'Dán packing list',
                            subtitle: lot.units == 0
                                ? 'Copy các dòng từ Excel'
                                : null,
                            onTap: () => openPasteSheet(context, lot: lot),
                          ),
                          OmniGroupRow.add(
                            key: const ValueKey('inv-lot-add-unit'),
                            title: 'Thêm cây',
                            onTap: () => openAddUnitSheet(
                              context,
                              lot: lot,
                              known: [
                                ...units,
                                // Tồn kho đang mở (nếu có) cho thêm gợi ý.
                                if (ref.exists(stockProvider))
                                  ...?ref
                                      .read(stockProvider)
                                      .valueOrNull
                                      ?.items,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: OmniGroupSection.gap),
                    ..._unitList(lot, units, unitsAsync, perms),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _summary(
    Lot lot,
    InventoryPerms perms,
    List<InventoryUnit> units,
  ) {
    final supplierId = lot.supplierId;
    final head = OmniGroupSection(
      children: [
        // Tóm tắt gọn: ngày về là dòng phụ dưới nhà cung cấp, trạng thái là
        // chip bên phải.
        OmniGroupRow(
          key: const ValueKey('inv-lot-supplier'),
          title: lot.supplierName ?? 'Nhà cung cấp',
          subtitle: lot.status == LotStatus.received
              ? 'Về kho ${InventoryFormat.dmy(lot.receivedAt)}'
              : lot.eta != null
              ? 'Dự kiến về ${InventoryFormat.dmy(lot.eta)}'
              : null,
          trailing: OmniBadge(
            label: lot.status.label,
            tone: switch (lot.status) {
              LotStatus.received => OmniTone.success,
              LotStatus.inTransit => OmniTone.info,
              LotStatus.ordered => OmniTone.neutral,
            },
          ),
          // Đợt A: mở hồ sơ nhà cung cấp.
          onTap: perms.suppliers && supplierId != null
              ? () => context.pushNamed(
                  InventoryRoutes.supplier,
                  pathParameters: {'supplierId': supplierId},
                )
              : null,
        ),
        OmniGroupRow(
          title: 'Cây',
          value: lot.units == 0
              ? 'Chưa có'
              : '${lot.units} · đặt trước ${lot.withCustomer}',
        ),
      ],
    );
    final money = <Widget>[];
    if (perms.cost && lot.rateApplied != null) {
      money.add(
        OmniGroupRow(
          key: const ValueKey('inv-lot-rate'),
          title: 'Tỷ lệ',
          trailing: InvValue(
            InventoryFormat.rate(lot.rateApplied),
            sub: lot.costFinal
                ? 'thật'
                : lot.rateManual
                ? 'tạm · sửa tay'
                : 'tạm',
          ),
          chevron: perms.pay && !lot.costFinal,
          onTap: perms.pay && !lot.costFinal && !_busy
              ? () => _editRate(lot)
              : null,
        ),
      );
      if (!lot.costFinal &&
          lot.rateManual &&
          perms.pay &&
          lot.rateEstimate != null) {
        money.add(
          OmniGroupRow(
            key: const ValueKey('inv-lot-use-estimate'),
            icon: Icons.auto_fix_high_rounded,
            accent: true,
            title: 'Dùng ước tính ${InventoryFormat.rate(lot.rateEstimate)}',
            onTap: _busy ? null : () => _useEstimate(lot),
          ),
        );
      }
      money.add(
        OmniGroupRow(
          title: 'Giá vốn lô',
          trailing: InvValue(InvUi.vnd(lot.costTotal)),
        ),
      );
    }
    if (lot.costFinal) {
      final fin = lot.rateLogs
          ?.where((r) => r.reason == 'auto_final')
          .firstOrNull;
      money.add(
        OmniGroupRow(
          title: 'Đã chốt',
          value: fin != null && fin.from != null && perms.cost
              ? 'Tạm ${InventoryFormat.rate(fin.from)}, thật ${InventoryFormat.rate(fin.to)}'
              : 'Giá vốn đã chốt',
        ),
      );
    } else if (perms.pay) {
      final due = lot.dueJpy ?? 0;
      final parts = [
        if (due > 0) InventoryFormat.yen(due),
        if (lot.plannedCount > 0) '${lot.plannedCount} khoản dự kiến',
      ];
      money.add(
        OmniGroupRow(
          title: 'Còn thiếu',
          value: lot.units == 0
              ? lotDebtLine(lot)
              : parts.isEmpty
              ? 'Đủ điều kiện chốt'
              : parts.join(' · '),
        ),
      );
    }

    final costs = lot.costs ?? const <LotCost>[];
    final paid = costs.where((c) => c.status == CostStatus.paid).length;
    final selecting = _pmsOn && _payOpen;
    return [
      head,
      if (money.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(key: const ValueKey('inv-lot-money'), children: money),
      ],
      ..._yen(lot, perms),
      ..._claims(lot, units, perms),
      if (perms.pay) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          key: const ValueKey('inv-lot-costs'),
          children: [
            OmniGroupRow(
              title: 'Khoản trả',
              subtitle: '$paid đã trả · ${costs.length - paid} dự kiến',
              trailing: Icon(
                _payOpen
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              onTap: () => setState(() {
                _payOpen = !_payOpen;
                if (!_payOpen) {
                  _pmsOn = false;
                  _pms.clear();
                }
              }),
            ),
            if (_payOpen) ...[
              if (costs.length > paid)
                OmniGroupRow(
                  key: const ValueKey('inv-lot-pay-select'),
                  icon: Icons.checklist_rounded,
                  title: selecting
                      ? 'Đã chọn ${costs.where((c) => _pms.contains(c.id) && c.status == CostStatus.planned).length} khoản'
                      : 'Trả nhiều khoản',
                  value: selecting ? 'Xong' : null,
                  chevron: !selecting,
                  onTap: () => setState(() {
                    _pmsOn = !_pmsOn;
                    _pms.clear();
                  }),
                ),
              for (final c in costs)
                selecting ? _pickCostRow(lot, c) : _costRow(lot, c),
              if (!selecting)
                OmniGroupRow.add(
                  key: const ValueKey('inv-lot-add-cost'),
                  title: 'Thêm khoản',
                  onTap: () => openCostSheet(context, lot: lot),
                ),
            ],
          ],
        ),
      ],
    ];
  }

  Widget _costRow(Lot lot, LotCost c) {
    final fx = c.isGoods && (c.amountVnd ?? 0) > 0 && (c.amountJpy ?? 0) > 0
        ? ' · ${InventoryFormat.rate(c.amountVnd! / c.amountJpy!)}'
        : '';
    final vnd = c.amountVnd ?? ((c.amountJpy ?? 0) * (lot.lastFx ?? 0));
    final planned = c.status == CostStatus.planned;
    return OmniGroupRow(
      key: ValueKey('inv-cost-${c.id}'),
      title: c.title,
      subtitle: c.isGoods
          ? '${InventoryFormat.yen(c.amountJpy)}$fx'
                '${c.kind == CostKind.goodsInvoice ? ' · invoice' : ''}'
          : 'Thuế & phí',
      trailing: InvValue(
        InvUi.vnd(vnd),
        sub: planned ? 'dự kiến' : InventoryFormat.dmy(c.paidAt),
        subColor: planned ? OmniColors.warningTextOf(context) : null,
      ),
      chevron: true,
      onTap: () => openCostSheet(context, lot: lot, cost: c),
    );
  }

  /// Dòng khoản trong chế độ "Trả nhiều khoản": dự kiến bấm để chọn, đã trả
  /// mờ đi, không bấm được.
  Widget _pickCostRow(Lot lot, LotCost c) {
    final planned = c.status == CostStatus.planned;
    final row = OmniGroupRow(
      key: ValueKey('inv-cost-pick-${c.id}'),
      title: c.title,
      subtitle: c.isGoods
          ? '${InventoryFormat.yen(c.amountJpy)}'
                '${c.kind == CostKind.goodsInvoice ? ' · invoice' : ''}'
          : 'Thuế & phí',
      trailing: InvValue(
        InvUi.vnd(planned ? plannedAmount(lot, c) : c.amountVnd),
        sub: planned ? 'dự kiến' : 'đã trả',
        subColor: planned ? OmniColors.warningTextOf(context) : null,
      ),
      selected: planned && _pms.contains(c.id),
      chevron: false,
      onTap: planned
          ? () => setState(
              () => _pms.contains(c.id) ? _pms.remove(c.id) : _pms.add(c.id),
            )
          : null,
    );
    return planned ? row : Opacity(opacity: .5, child: row);
  }

  List<Widget> _unitList(
    Lot lot,
    List<InventoryUnit> units,
    AsyncValue<List<InventoryUnit>> async,
    InventoryPerms perms,
  ) {
    if (units.isEmpty) {
      return [
        if (async.isLoading)
          const InvSkeleton(count: 4)
        else if (async.hasError)
          OmniErrorView(
            error: InvUi.error(async.error!),
            onRetry: () => ref.invalidate(lotUnitsProvider(widget.lotId)),
          )
        else
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Chưa có cây')],
          ),
      ];
    }
    final held = units.where((u) => u.hasCustomer).length;
    final shown = [
      for (final u in units)
        if (_seg == _Seg.all ||
            (_seg == _Seg.held ? u.hasCustomer : !u.hasCustomer))
          u,
    ];
    final rows = <Widget>[];
    for (final g in groupByModel(shown)) {
      if (g.items.length == 1) {
        rows.add(_unitRow(g.items.first, perms, nested: false));
        continue;
      }
      final open = _open.contains(g.key);
      final u0 = g.items.first;
      final free = [
        for (final u in g.items)
          if (u.sale == UnitSale.available) u,
      ];
      rows.add(
        OmniGroupRow(
          key: ValueKey('inv-group-${g.key}'),
          title: '${g.key} × ${g.items.length}',
          subtitle: [
            if (InvUi.shortCategory(u0.category).isNotEmpty)
              InvUi.shortCategory(u0.category),
            '${g.withCustomer}/${g.items.length} đặt trước',
          ].join(' · '),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InvValue(InvUi.vnd(u0.listPrice)),
              const SizedBox(width: 6),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          chevron: false,
          onTap: () =>
              setState(() => open ? _open.remove(g.key) : _open.add(g.key)),
        ),
      );
      if (open) {
        if (perms.reserve && free.isNotEmpty) {
          rows.add(
            OmniGroupRow.add(
              key: ValueKey('inv-group-sell-${g.key}'),
              title: 'Bán / Đặt trước nhiều cây',
              onTap: () => openSellSheet(
                context,
                units: free,
                allowRetail: true,
                pickCount: 1,
              ),
            ),
          );
        }
        for (final u in g.items) {
          rows.add(_unitRow(u, perms, nested: true));
        }
      }
    }
    return [
      OmniSegmented(
        labels: [
          'Tất cả ${units.length}',
          'Chưa có khách ${units.length - held}',
          'Đặt trước $held',
        ],
        index: _seg.index,
        onChanged: (i) => setState(() => _seg = _Seg.values[i]),
      ),
      const SizedBox(height: 10),
      OmniGroupSection(
        key: const ValueKey('inv-lot-units'),
        children: rows.isEmpty
            ? const [OmniGroupRow(title: 'Không có cây')]
            : rows,
      ),
    ];
  }

  Widget _unitRow(
    InventoryUnit u,
    InventoryPerms perms, {
    required bool nested,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hold = InvUi.holdLine(u);
    final sub = [
      '#${u.lineNo}',
      if (InvUi.shortCategory(u.category).isNotEmpty)
        InvUi.shortCategory(u.category),
      ?u.color,
      if (perms.cost && u.yenPrice != null) InventoryFormat.yen(u.yenPrice),
    ].join(' · ');
    return InkWell(
      key: ValueKey('inv-lot-unit-${u.id}'),
      onTap: () => _tapUnit(u, perms),
      child: Padding(
        padding: EdgeInsets.fromLTRB(nested ? 28 : 14, 8, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!nested)
                        Text(
                          u.name,
                          style: OmniType.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      SerialField(
                        serial: u.serial,
                        editable: perms.write,
                        semanticsName: u.name,
                        onSave: (s) => _saveSerial(u, s),
                      ),
                    ],
                  ),
                  Text(sub, style: invMuted(context)),
                  if (hold != null)
                    Text(
                      hold,
                      style: OmniType.caption.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InvValue(
              InvUi.vnd(u.listPrice),
              sub: perms.cost && u.costVnd != null
                  ? 'vốn ${InvUi.vnd(u.costVnd)}'
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cây sắp về, người xem không có quyền giữ hàng: chỉ xem.
class _LotUnitInfo extends StatelessWidget {
  const _LotUnitInfo({required this.unit, required this.perms});

  final InventoryUnit unit;
  final InventoryPerms perms;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: u.name,
        subtitle: ['#${u.lineNo}', ?u.serial].join(' · '),
      ),
      children: [
        OmniGroupSection(
          children: [
            OmniGroupRow(title: 'Niêm yết', value: InvUi.vnd(u.listPrice)),
            if (perms.cost)
              OmniGroupRow(
                title: 'Giá vốn tạm',
                subtitle: InventoryFormat.yen(u.yenPrice),
                value: InvUi.vnd(u.costVnd),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(title: 'Lô', value: u.lotCode ?? '—'),
            OmniGroupRow(title: 'Khách', value: InvUi.holdLine(u) ?? 'Chưa có'),
          ],
        ),
      ],
    );
  }
}
