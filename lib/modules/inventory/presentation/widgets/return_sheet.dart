import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// "Nhập lại kho" một cây đã giao (Kho chuẩn hóa Đợt C §2.3,
/// `POST /units/{id}/return`): vị trí (khi có từ hai vị trí), tình trạng (mặc
/// định Chưa kiểm), ghi chú. Trả cây sau khi về kho; null khi đóng.
Future<InventoryUnit?> openReturnSheet(
  BuildContext context,
  InventoryUnit unit,
) => showOmniSheet<InventoryUnit>(
  context: context,
  builder: (_) => ReturnSheet(unit: unit),
);

/// "Tìm thấy" cây đã đánh Không thấy khi kiểm kê (TNP_KHO_DOT_B_C §2.9,
/// `POST /units/{id}/found`): cùng sheet với Nhập lại kho. Trả cây sau khi về
/// kho; null khi đóng.
Future<InventoryUnit?> openFoundSheet(
  BuildContext context,
  InventoryUnit unit,
) => showOmniSheet<InventoryUnit>(
  context: context,
  builder: (_) => ReturnSheet(unit: unit, found: true),
);

/// Tình trạng chọn được khi nhập lại (API không nhận `missing`).
const returnConditions = [
  UnitCondition.sealed,
  UnitCondition.refurbishing,
  UnitCondition.ready,
  UnitCondition.defective,
];

class ReturnSheet extends ConsumerStatefulWidget {
  const ReturnSheet({super.key, required this.unit, this.found = false});

  final InventoryUnit unit;

  /// Tìm thấy cây Không thấy (`/found`) thay vì nhập lại cây đã giao.
  final bool found;

  @override
  ConsumerState<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<ReturnSheet> {
  String? _location;
  UnitCondition? _condition;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(List<StockLocation> locations, String? at) async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Vị trí',
      options: [for (final l in locations) (l.id, l.name)],
      selected: at,
    );
    if (r?.value != null && mounted) setState(() => _location = r!.value);
  }

  Future<void> _pickCondition() async {
    final r = await showInvOptions<UnitCondition>(
      context: context,
      title: 'Tình trạng',
      options: [for (final c in returnConditions) (c, c.label)],
      selected: _condition,
      allLabel: UnitCondition.noneLabel,
    );
    if (r != null && mounted) setState(() => _condition = r.value);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(inventoryApiProvider);
      final u = widget.found
          ? await api.foundUnit(
              widget.unit.id,
              locationId: _location,
              condition: _condition,
              note: _note.text,
            )
          : await api.returnUnit(
              widget.unit.id,
              locationId: _location,
              condition: _condition,
              note: _note.text,
            );
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop(u);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final locations =
        ref.watch(locationsProvider).valueOrNull ?? const <StockLocation>[];
    final at =
        _location ??
        locations.where((l) => l.isDefault).firstOrNull?.id ??
        locations.firstOrNull?.id;
    final atName = locations.where((l) => l.id == at).firstOrNull?.name;

    final action = widget.found ? 'Tìm thấy' : 'Nhập lại kho';
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: action,
        subtitle: [
          widget.unit.name,
          if (widget.unit.serial != null) widget.unit.serial!,
        ].join(' · '),
      ),
      footer: FilledButton(
        key: const ValueKey('inv-return-save'),
        onPressed: _saving ? null : _save,
        child: Text(action),
      ),
      children: [
        OmniGroupSection(
          children: [
            if (multi && locations.isNotEmpty)
              OmniGroupRow(
                key: const ValueKey('inv-return-location'),
                title: 'Vị trí',
                value: atName ?? 'Chọn',
                onTap: () => _pickLocation(locations, at),
              ),
            OmniGroupRow(
              key: const ValueKey('inv-return-condition'),
              title: 'Tình trạng',
              value: UnitCondition.labelOf(_condition),
              onTap: _pickCondition,
            ),
            InvInputRow(
              label: 'Ghi chú',
              controller: _note,
              fieldKey: const ValueKey('inv-return-note'),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ],
    );
  }
}
