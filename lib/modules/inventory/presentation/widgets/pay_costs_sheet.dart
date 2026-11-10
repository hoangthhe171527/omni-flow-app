import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Số ₫ mặc định khi ghi đã trả một khoản dự kiến: số ₫ đã ghi, không có thì
/// ¥ × tỷ giá lần trả gần nhất (chưa có thì 166).
int plannedAmount(Lot lot, LotCost c) =>
    (c.amountVnd ?? ((c.amountJpy ?? 0) * (lot.lastFx ?? 166))).round();

/// Sheet "Ghi đã trả" nhiều khoản dự kiến: số ₫ từng khoản (sửa bằng bàn
/// phím số), ngày trả, nguồn tiền, tổng. Trả câu thông báo khi đã ghi.
Future<String?> openPayCostsSheet(
  BuildContext context, {
  required Lot lot,
  required List<LotCost> costs,
}) {
  return showOmniSheet<String>(
    context: context,
    builder: (_) => PayCostsSheet(lot: lot, costs: costs),
  );
}

class PayCostsSheet extends ConsumerStatefulWidget {
  const PayCostsSheet({super.key, required this.lot, required this.costs});

  final Lot lot;
  final List<LotCost> costs;

  @override
  ConsumerState<PayCostsSheet> createState() => _PayCostsSheetState();
}

class _PayCostsSheetState extends ConsumerState<PayCostsSheet> {
  late final Map<String, int> _amounts = {
    for (final c in widget.costs) c.id: plannedAmount(widget.lot, c),
  };
  late DateTime _date = ref.read(inventoryTodayProvider);
  String? _account;
  bool _saving = false;

  int get _total => _amounts.values.fold(0, (s, v) => s + v);

  Future<void> _money(LotCost c) async {
    final v = await showMoneyKeypad(
      context: context,
      title: c.title,
      subtitle: widget.lot.code,
      initial: _amounts[c.id],
    );
    if (v != null && mounted) setState(() => _amounts[c.id] = v);
  }

  Future<void> _pickDate() async {
    final now = ref.read(inventoryTodayProvider);
    final d = await pickOmniDate(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Ngày trả',
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _pickAccount(List<MoneyAccount> accounts) async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Nguồn tiền',
      options: [for (final a in accounts) (a.id, a.name)],
      selected: _account,
      allLabel: 'Chưa ghi nguồn',
    );
    if (r != null && mounted) setState(() => _account = r.value);
  }

  Future<void> _save() async {
    final total = _total;
    final n = widget.costs.length;
    setState(() => _saving = true);
    try {
      final lot = await ref
          .read(inventoryApiProvider)
          .payCosts(
            widget.lot.id,
            costIds: [for (final c in widget.costs) c.id],
            paidAt: InventoryFormat.isoDay(_date),
            moneyAccountId: _account,
            amounts: Map.of(_amounts),
          );
      bumpInventory(ref);
      if (!mounted) return;
      final finalized = lot.costFinal && !widget.lot.costFinal;
      final rate = lot.rateFinal ?? lot.rateApplied;
      Navigator.of(context).pop(
        finalized
            ? (rate == null
                  ? '${lot.code} đã chốt giá vốn'
                  : '${lot.code} đã chốt ${InventoryFormat.rate(rate)}')
            : 'Đã trả $n khoản · ${InvUi.vnd(total)}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(moneyAccountsProvider).valueOrNull ?? const <MoneyAccount>[];
    final accountName = accounts
        .where((a) => a.id == _account)
        .map((a) => a.name)
        .firstOrNull;
    final total = _total;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Ghi đã trả',
        subtitle: '${widget.lot.code} · ${widget.costs.length} khoản',
      ),
      footer: FilledButton(
        key: const ValueKey('inv-pay-many-save'),
        // Khoản nào cũng phải có số tiền: khoản 0 ₫ không được ghi "đã trả".
        onPressed: _amounts.values.every((v) => v > 0) && !_saving
            ? _save
            : null,
        child: const Text('Ghi đã trả'),
      ),
      children: [
        OmniGroupSection(
          title: 'Số tiền',
          children: [
            for (final c in widget.costs)
              OmniGroupRow(
                key: ValueKey('inv-pay-many-amount-${c.id}'),
                title: c.title,
                subtitle: c.isGoods
                    ? InventoryFormat.yen(c.amountJpy)
                    : 'Thuế & phí',
                value: InvUi.vnd(_amounts[c.id]),
                onTap: () => _money(c),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-pay-many-date'),
              title: 'Ngày trả',
              value: InventoryFormat.dmy(InventoryFormat.isoDay(_date)),
              onTap: _pickDate,
            ),
            OmniGroupRow(
              key: const ValueKey('inv-pay-many-account'),
              title: 'Nguồn tiền',
              value: accountName ?? 'Chọn',
              onTap: () => _pickAccount(accounts),
            ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-pay-many-total'),
              title: 'Tổng',
              trailing: InvValue(InvUi.vnd(total)),
            ),
          ],
        ),
      ],
    );
  }
}
