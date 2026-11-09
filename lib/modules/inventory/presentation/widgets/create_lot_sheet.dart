import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// Sheet "Tạo lô": mã lô (cảnh báo trùng), nhà cung cấp (chọn hoặc tạo mới),
/// ngày đặt (hôm nay), dự kiến về, tỷ lệ tạm và thuế phí dự kiến theo lô trước
/// cùng nhà cung cấp (quyền thanh toán lô). Trả lô vừa tạo, null khi đóng.
///
/// [lots]: các lô đã tải — kiểm trùng mã tại chỗ (API vẫn kiểm lại) và tìm lô
/// trước cùng nhà cung cấp.
Future<Lot?> openCreateLotSheet(
  BuildContext context, {
  required List<Lot> lots,
}) {
  return showOmniSheet<Lot>(
    context: context,
    builder: (_) => CreateLotSheet(lots: lots),
  );
}

class CreateLotSheet extends ConsumerStatefulWidget {
  const CreateLotSheet({super.key, required this.lots});

  final List<Lot> lots;

  @override
  ConsumerState<CreateLotSheet> createState() => _CreateLotSheetState();
}

/// Lựa chọn "Nhà cung cấp mới" trong sheet chọn.
const _newSupplier = '__new';

class _CreateLotSheetState extends ConsumerState<CreateLotSheet> {
  final _code = TextEditingController();
  final _newName = TextEditingController();
  final _rate = TextEditingController();
  String? _supplier;
  DateTime? _eta;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _newName.dispose();
    _rate.dispose();
    super.dispose();
  }

  String? get _dupCode {
    final c = _code.text.trim();
    if (c.isEmpty) return null;
    final key = c.toLowerCase();
    return widget.lots.any((l) => l.code.trim().toLowerCase() == key)
        ? c
        : null;
  }

  /// Có lô trước cùng nhà cung cấp → máy chủ chép thuế phí của lô đó sang
  /// (`fees_from_previous`). Danh sách lô không có chi tiết khoản nên không
  /// đoán số tiền ở đây — số thật hiện trong lô sau khi tạo.
  bool get _copiesFees {
    final sid = _supplier;
    if (sid == null || sid == _newSupplier) return false;
    return widget.lots.any((l) => l.supplierId == sid);
  }

  Future<void> _pickSupplier(List<Supplier> suppliers) async {
    final picked = await showOmniSheet<String>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: const OmniSheetHeader(title: 'Nhà cung cấp'),
        children: [
          OmniGroupSection(
            children: [
              for (final s in suppliers)
                OmniGroupRow(
                  key: ValueKey('inv-nl-sup-${s.id}'),
                  title: s.name,
                  selected: s.id == _supplier,
                  chevron: false,
                  onTap: () => Navigator.of(sheet).pop(s.id),
                ),
              OmniGroupRow.add(
                key: const ValueKey('inv-nl-sup-new'),
                title: 'Nhà cung cấp mới',
                onTap: () => Navigator.of(sheet).pop(_newSupplier),
              ),
            ],
          ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _supplier = picked);
  }

  Future<void> _pickEta(DateTime today) async {
    final d = await pickOmniDate(
      context: context,
      initialDate: _eta ?? today.add(const Duration(days: 21)),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: 'Dự kiến về',
    );
    if (d != null && mounted) setState(() => _eta = d);
  }

  Future<void> _save(DateTime today) async {
    final perms = ref.read(inventoryPermsProvider);
    final rawRate = _rate.text.trim().replaceAll(',', '.');
    double? rate;
    if (perms.pay && rawRate.isNotEmpty) {
      rate = double.tryParse(rawRate);
      if (rate == null || rate < 1 || rate > 1000) {
        InvUi.toast(context, 'Tỷ lệ không hợp lệ.');
        return;
      }
    }
    setState(() => _saving = true);
    final api = ref.read(inventoryApiProvider);
    try {
      String? sid = _supplier;
      if (sid == _newSupplier) {
        final name = _newName.text.trim();
        sid = name.isEmpty ? null : (await api.createSupplier(name)).id;
      }
      final lot = await api.createLot(
        code: _code.text.trim(),
        supplierId: sid,
        orderedAt: InventoryFormat.isoDay(today),
        eta: _eta == null ? null : InventoryFormat.isoDay(_eta!),
        rate: rate,
      );
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop(lot);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final today = ref.watch(inventoryTodayProvider);
    final suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];
    final supplierName = _supplier == _newSupplier
        ? 'Mới'
        : suppliers.where((s) => s.id == _supplier).firstOrNull?.name;
    final dup = _dupCode;
    final copiesFees = perms.pay && _copiesFees;
    final ok = _code.text.trim().isNotEmpty && dup == null && !_saving;

    return OmniSheetBody(
      header: const OmniSheetHeader(title: 'Tạo lô'),
      footer: FilledButton(
        key: const ValueKey('inv-nl-save'),
        onPressed: ok ? () => _save(today) : null,
        child: const Text('Tạo lô'),
      ),
      children: [
        OmniGroupSection(
          children: [
            InvInputRow(
              label: 'Mã lô',
              controller: _code,
              fieldKey: const ValueKey('inv-nl-code'),
              hint: 'Ep 67',
              caps: true,
              onChanged: (_) => setState(() {}),
            ),
            if (dup != null)
              OmniGroupRow(
                key: const ValueKey('inv-nl-dup'),
                title: 'Đã có lô $dup',
                destructive: true,
                chevron: false,
              ),
            OmniGroupRow(
              key: const ValueKey('inv-nl-supplier'),
              title: 'Nhà cung cấp',
              value: supplierName ?? 'Chọn',
              onTap: () => _pickSupplier(suppliers),
            ),
            if (_supplier == _newSupplier)
              InvInputRow(
                label: 'Tên nhà cung cấp',
                controller: _newName,
                fieldKey: const ValueKey('inv-nl-new-supplier'),
                hint: 'Hamana',
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              title: 'Ngày đặt',
              value: InventoryFormat.dmy(InventoryFormat.isoDay(today)),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-nl-eta'),
              title: 'Dự kiến về',
              value: _eta == null
                  ? 'Chọn'
                  : InventoryFormat.dmy(InventoryFormat.isoDay(_eta!)),
              onTap: () => _pickEta(today),
            ),
            if (perms.pay)
              InvInputRow(
                label: 'Tỷ lệ tạm',
                controller: _rate,
                fieldKey: const ValueKey('inv-nl-rate'),
                hint: 'Tự tính',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
          ],
        ),
        if (copiesFees)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-nl-prev-fees'),
                title: 'Thuế phí dự kiến',
                value: 'Chép từ lô trước',
              ),
            ],
          ),
      ],
    );
  }
}
