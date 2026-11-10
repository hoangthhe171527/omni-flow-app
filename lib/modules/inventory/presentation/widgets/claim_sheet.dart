import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Sửa một khoản đòi nhà cung cấp (`PUT /inventory/claims/{id}`): cách xử lý,
/// số ¥ (lỗi + trừ tiền), đã giải quyết. Trả câu báo khi đã lưu.
Future<String?> openClaimSheet(
  BuildContext context, {
  required LotClaim claim,
  required String unitName,
}) => showOmniSheet<String>(
  context: context,
  builder: (_) => ClaimSheet(claim: claim, unitName: unitName),
);

class ClaimSheet extends ConsumerStatefulWidget {
  const ClaimSheet({super.key, required this.claim, required this.unitName});

  final LotClaim claim;
  final String unitName;

  @override
  ConsumerState<ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<ClaimSheet> {
  late ClaimResolution? _resolution = widget.claim.resolution;
  late int? _amount = widget.claim.amountJpy?.round();
  late bool _settled = widget.claim.settled;
  bool _saving = false;

  bool get _needsAmount => LotClaim.needsAmount(
    missing: widget.claim.missing,
    resolution: _resolution,
  );

  Future<void> _pickAmount() async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Số ¥ được trừ',
      subtitle: widget.unitName,
      initial: _amount,
      unit: '¥',
    );
    if (v != null && mounted) setState(() => _amount = v);
  }

  Future<void> _save() async {
    if (_needsAmount && (_amount == null || _amount! <= 0)) {
      InvUi.toast(context, 'Nhập số ¥ được trừ cho cây lỗi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryApiProvider)
          .updateClaim(
            widget.claim.id,
            ClaimInput(
              missing: widget.claim.missing,
              resolution: _resolution,
              settled: _settled,
              amountJpy: _amount,
            ),
          );
      // Lô tính lại nợ và giá vốn: tải lại lô, cây.
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop('Đã cập nhật khoản đòi.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.unitName,
        subtitle: c.missing ? 'Cây thiếu' : 'Cây lỗi',
      ),
      footer: FilledButton(
        key: const ValueKey('inv-claim-save'),
        onPressed: _saving ? null : _save,
        child: const Text('Lưu'),
      ),
      children: [
        OmniGroupSection(
          title: 'Cách xử lý',
          dividerIndent: 14,
          children: [
            if (!c.missing)
              OmniGroupRow(
                key: const ValueKey('inv-claim-undecided'),
                title: ClaimResolution.undecidedLabel,
                selected: _resolution == null,
                chevron: false,
                onTap: () => setState(() => _resolution = null),
              ),
            for (final r in ClaimResolution.values)
              OmniGroupRow(
                key: ValueKey('inv-claim-${r.wire}'),
                title: r.label,
                selected: _resolution == r,
                chevron: false,
                onTap: () => setState(() => _resolution = r),
              ),
          ],
        ),
        if (_needsAmount)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-claim-amount'),
                title: 'Số ¥ được trừ',
                trailing: InvValue(
                  _amount == null ? 'Nhập' : InventoryFormat.yen(_amount),
                ),
                chevron: true,
                onTap: _pickAmount,
              ),
            ],
          ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-claim-settled'),
              title: 'Đã giải quyết',
              trailing: Switch.adaptive(
                value: _settled,
                onChanged: (v) => setState(() => _settled = v),
              ),
              onTap: () => setState(() => _settled = !_settled),
            ),
          ],
        ),
      ],
    );
  }
}
