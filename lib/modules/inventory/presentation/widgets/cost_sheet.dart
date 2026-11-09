import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Thêm / sửa một khoản trả lô — hai loại: Trả tiền hàng (¥ + ₫, tỷ giá tự
/// tính, theo invoice) và Thuế & phí (chỉ ₫). Trả true khi đã ghi.
Future<bool> openCostSheet(
  BuildContext context, {
  required Lot lot,
  LotCost? cost,
}) async {
  final msg = await showOmniSheet<String>(
    context: context,
    builder: (_) => CostSheet(lot: lot, cost: cost),
  );
  if (msg == null) return false;
  if (context.mounted) InvUi.toast(context, msg);
  return true;
}

class CostSheet extends ConsumerStatefulWidget {
  const CostSheet({super.key, required this.lot, this.cost});

  final Lot lot;
  final LotCost? cost;

  @override
  ConsumerState<CostSheet> createState() => _CostSheetState();
}

class _CostSheetState extends ConsumerState<CostSheet> {
  late bool _goods = widget.cost?.isGoods ?? false;
  late bool _invoice = widget.cost?.kind == CostKind.goodsInvoice;
  late CostKind _fee = widget.cost != null && !widget.cost!.isGoods
      ? widget.cost!.kind
      : CostKind.importTax;
  late int _jpy = (widget.cost?.amountJpy ?? 0).round();
  late int _vnd = (widget.cost?.amountVnd ?? _suggestVnd()).round();

  /// Khoản dự kiến mở ra để ghi đã trả: mặc định Đã trả.
  CostStatus _status = CostStatus.paid;
  late DateTime _date = _parse(widget.cost?.paidAt) ?? DateTime.now();
  late String? _account = widget.cost?.moneyAccountId;
  bool _saving = false;

  double _suggestVnd() {
    final c = widget.cost;
    if (c == null || !c.isGoods || c.amountVnd != null) return 0;
    return (c.amountJpy ?? 0) * (widget.lot.lastFx ?? 0);
  }

  static DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  bool get _valid => _goods
      ? _jpy > 0 && (_status == CostStatus.planned || _vnd > 0)
      : _vnd > 0;

  Future<void> _save() async {
    final input = CostInput(
      kind: _goods
          ? (_invoice ? CostKind.goodsInvoice : CostKind.goodsOutside)
          : _fee,
      status: _status,
      label: _goods ? 'Trả tiền hàng' : _fee.label,
      amountJpy: _goods ? _jpy.toDouble() : null,
      amountVnd: _vnd > 0 ? _vnd.toDouble() : null,
      paidAt: InventoryFormat.isoDay(_date),
      moneyAccountId: _account,
    );
    setState(() => _saving = true);
    try {
      final api = ref.read(inventoryApiProvider);
      if (widget.cost == null) {
        await api.addCost(widget.lot.id, input);
      } else {
        await api.updateCost(widget.cost!.id, input);
      }
      bumpInventory(ref);
      if (mounted) {
        Navigator.of(context).pop(
          _status == CostStatus.paid
              ? 'Đã trả ${InvUi.vnd(_vnd)}'
              : 'Đã ghi dự kiến.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showOmniConfirm(
      context: context,
      title: 'Xoá khoản?',
      message: widget.cost!.title,
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(inventoryApiProvider).deleteCost(widget.cost!.id);
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop('Đã xoá khoản.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  Future<void> _pickFee() async {
    final r = await showInvOptions<CostKind>(
      context: context,
      title: 'Khoản',
      options: [for (final k in CostKind.fees) (k, k.label)],
      selected: _fee,
    );
    if (r?.value != null) setState(() => _fee = r!.value!);
  }

  Future<void> _pickAccount(List<MoneyAccount> accounts) async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Nguồn tiền',
      options: [for (final a in accounts) (a.id, a.name)],
      selected: _account,
      allLabel: 'Chưa ghi nguồn',
    );
    if (r != null) setState(() => _account = r.value);
  }

  Future<void> _pickDate() async {
    final d = await pickOmniDate(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _money(bool yen) async {
    final v = await showMoneyKeypad(
      context: context,
      title: yen ? 'Số ¥' : 'Số ₫',
      initial: yen ? _jpy : _vnd,
      unit: yen ? '¥' : 'đ',
    );
    if (v != null) setState(() => yen ? _jpy = v : _vnd = v);
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(moneyAccountsProvider).valueOrNull ?? const <MoneyAccount>[];
    final accountName = accounts
        .where((a) => a.id == _account)
        .map((a) => a.name)
        .firstOrNull;
    final editing = widget.cost != null;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: editing ? 'Khoản trả' : 'Thêm khoản',
        subtitle: widget.lot.code,
      ),
      footer: FilledButton(
        key: const ValueKey('inv-cost-save'),
        onPressed: _valid && !_saving ? _save : null,
        child: const Text('Lưu'),
      ),
      children: [
        OmniSegmented(
          labels: const ['Trả tiền hàng', 'Thuế & phí'],
          index: _goods ? 0 : 1,
          onChanged: editing ? (_) {} : (i) => setState(() => _goods = i == 0),
        ),
        OmniGroupSection(
          children: _goods
              ? [
                  OmniGroupRow(
                    key: const ValueKey('inv-cost-jpy'),
                    title: 'Số ¥',
                    value: InventoryFormat.yen(_jpy),
                    onTap: () => _money(true),
                  ),
                  OmniGroupRow(
                    key: const ValueKey('inv-cost-vnd'),
                    title: 'Số ₫',
                    value: InvUi.vnd(_vnd),
                    onTap: () => _money(false),
                  ),
                  OmniGroupRow(
                    title: 'Tỷ giá',
                    value: _jpy > 0 && _vnd > 0
                        ? InventoryFormat.rate(_vnd / _jpy)
                        : '—',
                  ),
                  OmniGroupRow(
                    title: 'Theo invoice',
                    trailing: Switch.adaptive(
                      value: _invoice,
                      onChanged: (v) => setState(() => _invoice = v),
                    ),
                  ),
                ]
              : [
                  OmniGroupRow(
                    key: const ValueKey('inv-cost-fee'),
                    title: 'Khoản',
                    value: _fee.label,
                    onTap: _pickFee,
                  ),
                  OmniGroupRow(
                    key: const ValueKey('inv-cost-vnd'),
                    title: 'Số ₫',
                    value: InvUi.vnd(_vnd),
                    onTap: () => _money(false),
                  ),
                ],
        ),
        OmniSegmented(
          labels: const ['Đã trả', 'Dự kiến'],
          index: _status == CostStatus.paid ? 0 : 1,
          onChanged: (i) => setState(
            () => _status = i == 0 ? CostStatus.paid : CostStatus.planned,
          ),
        ),
        OmniGroupSection(
          children: [
            if (_status == CostStatus.paid)
              OmniGroupRow(
                title: 'Ngày',
                value: InventoryFormat.dmy(InventoryFormat.isoDay(_date)),
                onTap: _pickDate,
              ),
            OmniGroupRow(
              title: 'Nguồn tiền',
              value: accountName ?? 'Chọn',
              onTap: () => _pickAccount(accounts),
            ),
          ],
        ),
        if (editing)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Xoá khoản',
                destructive: true,
                onTap: _saving ? null : _delete,
              ),
            ],
          ),
      ],
    );
  }
}
