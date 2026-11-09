import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';
import 'sell_sheet.dart';
import 'serial_field.dart';

/// Sheet "Chi tiết cây" của Tồn kho: serial chạm để sửa / thêm, tình trạng,
/// giá, Bán / Đặt trước, Bỏ giữ, Đổi khách, Tạo đơn — theo quyền.
///
/// [onChanged] nhận cây sau mỗi lần sửa (để màn danh sách thay tại chỗ).
Future<void> openUnitSheet(
  BuildContext context, {
  required InventoryUnit unit,
  required ValueChanged<InventoryUnit> onChanged,
}) {
  return showOmniSheet<void>(
    context: context,
    builder: (_) => UnitSheet(unit: unit, onChanged: onChanged),
  );
}

class UnitSheet extends ConsumerStatefulWidget {
  const UnitSheet({super.key, required this.unit, required this.onChanged});

  final InventoryUnit unit;
  final ValueChanged<InventoryUnit> onChanged;

  @override
  ConsumerState<UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends ConsumerState<UnitSheet> {
  late InventoryUnit _u = widget.unit;
  bool _busy = false;

  Future<void> _update(Map<String, Object?> fields, {String? done}) async {
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(inventoryApiProvider)
          .updateUnit(_u.id, fields);
      if (!mounted) return;
      setState(() => _u = res.unit);
      widget.onChanged(res.unit);
      final taken = res.warnings.where((w) => w.code == 'serial_taken');
      if (taken.isNotEmpty) {
        InvUi.toast(
          context,
          'Serial ${taken.first.serial ?? ''} trùng một cây ${_u.maker} khác · đã lưu',
        );
      } else if (done != null) {
        InvUi.toast(context, done);
      }
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPrice() async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Niêm yết',
      subtitle: _u.name,
      initial: _u.listPrice,
    );
    if (v != null && v != _u.listPrice?.round()) {
      await _update({'list_price': v}, done: 'Đã đổi giá niêm yết.');
    }
  }

  Future<void> _editCondition() async {
    final picked = await showInvOptions<UnitCondition>(
      context: context,
      title: 'Tình trạng',
      options: [for (final c in UnitCondition.values) (c, c.label)],
      selected: _u.condition,
      allLabel: UnitCondition.noneLabel,
    );
    if (picked == null || picked.value == _u.condition) return;
    await _update({
      'condition': picked.value?.wire,
    }, done: 'Đã đổi tình trạng.');
  }

  Future<void> _release() async {
    setState(() => _busy = true);
    try {
      final out = await ref.read(inventoryApiProvider).release([_u.id]);
      bumpInventory(ref);
      if (out.isNotEmpty) widget.onChanged(out.first);
      if (mounted) {
        InvUi.toast(context, 'Đã bỏ giữ.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  Future<void> _orderNow() async {
    final cid = _u.customerId;
    if (cid == null) return;
    setState(() => _busy = true);
    try {
      final order = await ref
          .read(inventoryApiProvider)
          .sell(
            customerId: cid,
            unitIds: [_u.id],
            prices: {_u.id: _u.suggestedPrice},
          );
      bumpInventory(ref);
      if (mounted) {
        InvUi.toast(
          context,
          'Đã tạo đơn ${order.code} · ${_u.customerName ?? ''} · ${InvUi.vnd(_u.suggestedPrice)}',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  Future<void> _sell({String title = 'Bán / Đặt trước'}) async {
    final nav = Navigator.of(context);
    final done = await openSellSheet(context, units: [_u], title: title);
    if (done && mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final today = ref.watch(inventoryTodayProvider);
    final u = _u;
    final age = InventoryFormat.ageDays(u.receivedAt, today);
    final hold = InvUi.holdLine(u);

    final buttons = <Widget>[
      if (u.sale == UnitSale.available && perms.canSellOrReserve)
        FilledButton(
          key: const ValueKey('inv-unit-sell'),
          onPressed: _busy ? null : _sell,
          child: const Text('Bán / Đặt trước'),
        ),
      if (u.sale == UnitSale.reserved && perms.reserve) ...[
        OutlinedButton(
          key: const ValueKey('inv-unit-release'),
          onPressed: _busy ? null : _release,
          child: const Text('Bỏ giữ'),
        ),
        OutlinedButton(
          key: const ValueKey('inv-unit-change'),
          onPressed: _busy ? null : () => _sell(title: 'Đổi khách'),
          child: const Text('Đổi khách'),
        ),
      ],
      if (u.sale == UnitSale.reserved &&
          perms.sell &&
          !u.retailHold &&
          u.customerId != null &&
          u.place == UnitPlace.inStock)
        FilledButton(
          key: const ValueKey('inv-unit-order'),
          onPressed: _busy ? null : _orderNow,
          child: const Text('Tạo đơn'),
        ),
    ];

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: u.name,
        subtitle: [
          if (u.color != null) u.color!,
          if (u.lotCode != null) u.lotCode!,
        ].join(' · '),
      ),
      footer: buttons.isEmpty
          ? null
          : Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: buttons[i]),
                ],
              ],
            ),
      children: [
        OmniGroupSection(
          children: [
            OmniGroupRow(
              title: 'Serial',
              trailing: SerialField(
                key: ValueKey('inv-unit-serial-${u.id}'),
                serial: u.serial,
                editable: perms.write,
                semanticsName: u.name,
                onSave: (s) => _update({
                  'serial': s,
                }, done: s == null ? 'Đã xoá serial.' : 'Đã lưu serial $s.'),
              ),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-unit-price'),
              title: 'Niêm yết',
              value: InvUi.vnd(u.listPrice),
              chevron: perms.write,
              onTap: perms.write && !_busy ? _editPrice : null,
            ),
            if (perms.cost)
              OmniGroupRow(
                title: 'Giá vốn',
                subtitle: u.yenPrice != null && u.yenPrice! > 0
                    ? '${InventoryFormat.yen(u.yenPrice)} · theo lô ${u.lotCode ?? ''}'
                    : 'theo lô ${u.lotCode ?? ''}',
                value: InvUi.vnd(u.costVnd),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(title: 'Lô', value: u.lotCode ?? '—'),
            OmniGroupRow(title: 'Loại', value: u.category ?? '—'),
            OmniGroupRow(
              title: 'Nhập kho',
              value: u.receivedAt == null
                  ? 'chưa ghi'
                  : '${InventoryFormat.dmy(u.receivedAt)} · $age ngày',
            ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-unit-condition'),
              title: 'Tình trạng',
              trailing: Text(
                UnitCondition.labelOf(u.condition),
                style: invMuted(
                  context,
                ).copyWith(color: InvUi.conditionColor(context, u.condition)),
              ),
              chevron: perms.write,
              onTap: perms.write && !_busy ? _editCondition : null,
            ),
            OmniGroupRow(
              title: 'Bán',
              subtitle: hold,
              value: switch (u.sale) {
                UnitSale.available => 'Còn bán',
                UnitSale.reserved => 'Đang giữ',
                UnitSale.sold => 'Trong đơn',
              },
            ),
          ],
        ),
      ],
    );
  }
}
