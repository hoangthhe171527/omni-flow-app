import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/components.dart';
import '../../../../security/session/session_controller.dart';
import '../../../tasks/domain/task_permissions.dart';
import '../../../tasks/routes.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';
import 'return_sheet.dart';
import 'sell_sheet.dart';
import 'serial_field.dart';
import 'slip_sheet.dart';
import 'unit_extras.dart';

/// Sheet "Chi tiết cây" của Tồn kho: serial chạm để sửa / thêm, tình trạng,
/// giá, Bán / Đặt trước, Bỏ giữ, Đổi khách, Tạo đơn — theo quyền.
///
/// [onChanged] nhận cây sau mỗi lần sửa (để màn danh sách thay tại chỗ).
///
/// Nhóm "Xưởng" (Kho nối Xưởng): mỗi việc xưởng của cây một dòng, chạm để mở
/// việc. Sheet nằm ở navigator gốc nên đóng sheet trước rồi mới mở việc.
///
/// Kho chuẩn hóa Đợt A (mỗi phần theo capability riêng): Ảnh, Lỗi, Ghi chú
/// (`inventory.photos`); Vị trí — chạm để chuyển khi có từ hai vị trí — và
/// Thẻ kho (`inventory.locations`); nút Đã giao cho cây đã vào đơn.
///
/// Đợt C: cây đã giao có nhóm phiếu xuất (chạm xem phiếu), giá bán, hóa đơn
/// (chỉ xem); nút "Mở việc bảo hành" và "Nhập lại kho".
Future<void> openUnitSheet(
  BuildContext context, {
  required InventoryUnit unit,
  required ValueChanged<InventoryUnit> onChanged,
}) {
  final router = GoRouter.maybeOf(context);
  return showOmniSheet<void>(
    context: context,
    builder: (sheet) => UnitSheet(
      unit: unit,
      onChanged: onChanged,
      onOpenTask: router == null
          ? null
          : (taskId) {
              Navigator.of(sheet).pop();
              router.pushNamed(
                TaskRoutes.detail,
                pathParameters: {'id': taskId},
              );
            },
    ),
  );
}

class UnitSheet extends ConsumerStatefulWidget {
  const UnitSheet({
    super.key,
    required this.unit,
    required this.onChanged,
    this.onOpenTask,
  });

  final InventoryUnit unit;
  final ValueChanged<InventoryUnit> onChanged;

  /// Mở chi tiết việc xưởng theo id. null = không có lối mở (không mũi tên).
  final ValueChanged<String>? onOpenTask;

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

  /// Chuyển cây sang vị trí khác (một cây — `POST /units/move`).
  Future<void> _move() async {
    final sub = ref.listenManual(locationsProvider, (_, _) {});
    final List<StockLocation> locations;
    try {
      locations = await ref.read(locationsProvider.future);
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
      return;
    } finally {
      sub.close();
    }
    if (!mounted) return;
    final r = await showInvOptions<String>(
      context: context,
      title: 'Chuyển đến',
      options: [for (final l in locations) (l.id, l.name)],
      selected: _u.locationId,
    );
    final to = r?.value;
    if (to == null || to == _u.locationId || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(inventoryApiProvider)
          .moveUnits(unitIds: [_u.id], toLocationId: to);
      bumpInventory(ref);
      if (!mounted) return;
      final moved = res.units.where((x) => x.id == _u.id).firstOrNull;
      if (moved != null) {
        setState(() => _u = moved);
        widget.onChanged(moved);
      }
      final name = locations.where((l) => l.id == to).firstOrNull?.name;
      InvUi.toast(
        context,
        res.moved > 0
            ? 'Đã chuyển đến ${name ?? 'vị trí mới'}.'
            : 'Cây không chuyển được.',
      );
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNote() async {
    final v = await showOmniPrompt(
      context: context,
      title: 'Ghi chú',
      confirmLabel: 'Lưu',
      initialValue: _u.note ?? '',
      maxLength: 500,
      fieldKey: const ValueKey('inv-unit-note-field'),
    );
    if (v == null || v.trim() == (_u.note ?? '').trim()) return;
    await _update({
      'note': v.trim().isEmpty ? null : v.trim(),
    }, done: 'Đã lưu ghi chú.');
  }

  Future<void> _deliver() async {
    final nav = Navigator.of(context);
    await _update({'place': UnitPlace.delivered.wire}, done: 'Đã giao.');
    if (mounted && _u.place == UnitPlace.delivered) nav.pop();
  }

  /// Nhập lại kho cây đã giao (Đợt C §2.3).
  Future<void> _return() async {
    final nav = Navigator.of(context);
    final back = await openReturnSheet(context, _u);
    if (back == null || !mounted) return;
    widget.onChanged(back);
    InvUi.toast(context, 'Đã nhập lại kho.');
    nav.pop();
  }

  /// Bảo hành = việc xưởng gắn cây, cây vẫn của khách (Đợt C §2.3): chọn kế
  /// hoạch rồi `POST /tasks/from-units`.
  Future<void> _warranty() async {
    setState(() => _busy = true);
    try {
      final sub = ref.listenManual(workshopPlansProvider, (_, _) {});
      final List<WorkshopPlan> plans;
      try {
        plans = await ref.read(workshopPlansProvider.future);
      } finally {
        sub.close();
      }
      if (!mounted) return;
      if (plans.isEmpty) {
        InvUi.toast(
          context,
          'Chưa có kế hoạch đang chạy nào bạn quản lý được.',
        );
        return;
      }
      final r = await showInvOptions<String>(
        context: context,
        title: 'Chọn kế hoạch',
        options: [for (final p in plans) (p.id, p.name)],
      );
      final planId = r?.value;
      if (planId == null || !mounted) return;
      final res = await ref
          .read(inventoryApiProvider)
          .sendToWorkshop(projectId: planId, unitIds: [_u.id]);
      bumpInventory(ref);
      if (!mounted) return;
      InvUi.toast(
        context,
        res.created > 0 ? 'Đã mở việc bảo hành.' : sendToWorkshopMessage(res),
      );
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final workshop = u.workshop;
    // Màn chi tiết việc đòi `tasks.read` — thiếu thì dòng chỉ để đọc.
    final openTask = ref.watch(accessProvider).can(TaskPermissions.read)
        ? widget.onOpenTask
        : null;
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final canMove = multi && perms.write && u.place == UnitPlace.inStock;
    final delivered = u.place == UnitPlace.delivered;
    final invoice = perms.invoices ? u.invoice : null;

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
      // Cây đã vào đơn mà còn trong kho: giao xong thì rời Tồn kho.
      if (perms.write &&
          u.sale == UnitSale.sold &&
          u.place == UnitPlace.inStock)
        OutlinedButton(
          key: const ValueKey('inv-unit-deliver'),
          onPressed: _busy ? null : _deliver,
          child: const Text('Đã giao'),
        ),
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
      // Đợt C: cây đã giao — bảo hành (cây vẫn của khách) hoặc nhập lại kho.
      if (delivered && perms.delivered && perms.workshop)
        OutlinedButton(
          key: const ValueKey('inv-unit-warranty'),
          onPressed: _busy ? null : _warranty,
          // "Mở việc bảo hành" xuống hai dòng ở nửa bề ngang 390.
          child: const Text('Bảo hành'),
        ),
      if (delivered && perms.returns)
        FilledButton(
          key: const ValueKey('inv-unit-return'),
          onPressed: _busy ? null : _return,
          child: const Text('Nhập lại kho'),
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
        if (perms.photos) UnitPhotosSection(unit: u),
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
            // Vị trí chỉ khi có từ hai vị trí (spec §5) — một vị trí thì thừa.
            if (perms.locations &&
                multi &&
                u.locationName != null &&
                u.place != UnitPlace.delivered)
              OmniGroupRow(
                key: const ValueKey('inv-unit-location'),
                title: 'Vị trí',
                value: u.locationName,
                chevron: canMove,
                onTap: canMove && !_busy ? _move : null,
              ),
            OmniGroupRow(
              title: 'Bán',
              subtitle: delivered ? u.customerName : hold,
              value: delivered
                  ? 'Đã giao'
                  : switch (u.sale) {
                      UnitSale.available => 'Còn bán',
                      UnitSale.reserved => 'Đang giữ',
                      UnitSale.sold => 'Trong đơn',
                    },
            ),
          ],
        ),
        // Đợt C: lần giao gần nhất — phiếu xuất, giá bán, hóa đơn (chỉ xem).
        if (u.slipNo != null || u.soldPrice != null || invoice != null)
          OmniGroupSection(
            key: const ValueKey('inv-unit-sale'),
            children: [
              if (delivered && u.deliveredAt != null)
                OmniGroupRow(
                  title: 'Giao',
                  value: InventoryFormat.dmy(u.deliveredAt),
                ),
              if (u.slipNo != null)
                OmniGroupRow(
                  key: const ValueKey('inv-unit-slip'),
                  title: 'Phiếu xuất',
                  value: u.slipNo,
                  chevron: perms.slips,
                  onTap: perms.slips
                      ? () => openSlipSheet(context, u.slipNo!)
                      : null,
                ),
              if (u.soldPrice != null)
                OmniGroupRow(
                  key: const ValueKey('inv-unit-sold-price'),
                  title: 'Giá bán',
                  trailing: InvValue(InvUi.vnd(u.soldPrice)),
                ),
              if (invoice != null)
                OmniGroupRow(
                  key: const ValueKey('inv-unit-invoice'),
                  title: 'Hóa đơn',
                  subtitle: invoice.no == null && invoice.date == null
                      ? null
                      : [
                          if (invoice.no != null) invoice.no!,
                          if (invoice.date != null)
                            InventoryFormat.dmy(invoice.date),
                        ].join(' · '),
                  value: invoice.status.label,
                ),
            ],
          ),
        if (perms.photos)
          UnitDefectSection(
            unit: u,
            enabled: perms.write && !_busy,
            onChanged: (tags) =>
                _update({'defect_tags': tags}, done: 'Đã lưu nhãn lỗi.'),
          ),
        if (perms.photos && (perms.write || (u.note ?? '').isNotEmpty))
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-unit-note'),
                title: 'Ghi chú',
                subtitle: (u.note ?? '').isEmpty ? null : u.note,
                value: (u.note ?? '').isEmpty && perms.write ? 'Thêm' : null,
                chevron: perms.write,
                onTap: perms.write && !_busy ? _editNote : null,
              ),
            ],
          ),
        // API cũ không gửi `workshop`: không có nhóm, không đoán "chưa vào".
        if (workshop != null)
          OmniGroupSection(
            key: const ValueKey('inv-unit-workshop'),
            title: 'Xưởng',
            children: [
              if (workshop.isEmpty) const InvMutedRow('Chưa vào xưởng'),
              for (final w in workshop)
                InvWorkRow(
                  key: ValueKey('inv-unit-work-${w.taskId}'),
                  work: w,
                  onTap: openTask == null || w.taskId.isEmpty
                      ? null
                      : () => openTask(w.taskId),
                ),
            ],
          ),
        if (perms.locations) UnitLedgerSection(unitId: u.id),
      ],
    );
  }
}
