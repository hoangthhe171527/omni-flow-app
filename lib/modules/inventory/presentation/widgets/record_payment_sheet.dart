import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inventory_providers.dart';
import '../../domain/order_list.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Tấm "Ghi thu" (bản mẫu NWUQNP): số tiền to (mặc định = còn phải thu, chạm
/// để sửa bằng bàn phím số), "Thu đủ", hình thức, ngày, ghi chú →
/// `POST /orders/{id}/payments`. Trả `true` khi đã ghi.
Future<bool> openRecordPaymentSheet(
  BuildContext context, {
  required String orderId,
  required String orderCode,
  required double remaining,
}) async {
  final ok = await showOmniSheet<bool>(
    context: context,
    builder: (_) => RecordPaymentSheet(
      orderId: orderId,
      orderCode: orderCode,
      remaining: remaining,
    ),
  );
  return ok == true;
}

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.remaining,
  });

  final String orderId;
  final String orderCode;
  final double remaining;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late int _amount = widget.remaining.round();
  PaymentMethod _method = PaymentMethod.transfer;
  late DateTime _paidAt = ref.read(inventoryTodayProvider);
  String _note = '';
  bool _saving = false;

  int get _full => widget.remaining.round();

  Future<void> _editAmount() async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Số tiền thu',
      subtitle: 'còn phải thu ${Formatters.vnd(_full)}',
      initial: _amount,
    );
    if (v != null && mounted) setState(() => _amount = v);
  }

  Future<void> _pickDate() async {
    final today = ref.read(inventoryTodayProvider);
    final d = await pickOmniDate(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(today.year - 1),
      // Không thu ở tương lai (như web `paidAtFuture`).
      lastDate: today,
    );
    if (d != null && mounted) setState(() => _paidAt = d);
  }

  Future<void> _editNote() async {
    final v = await showOmniPrompt(
      context: context,
      title: 'Ghi chú',
      confirmLabel: 'Xong',
      initialValue: _note,
      maxLength: 500,
    );
    if (v != null && mounted) setState(() => _note = v.trim());
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryApiProvider)
          .recordPayment(
            widget.orderId,
            amount: _amount,
            paidAt: _paidAt,
            method: _method,
            note: _note,
          );
      bumpOrders(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      InvUi.toast(context, InvUi.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = ref.watch(inventoryTodayProvider);
    final isToday =
        _paidAt.year == today.year &&
        _paidAt.month == today.month &&
        _paidAt.day == today.day;
    final over = _amount > _full && _full > 0;

    return OmniSheetBody(
      header: OmniSheetHeader(title: 'Ghi thu', subtitle: widget.orderCode),
      footer: FilledButton(
        key: const ValueKey('pay-save'),
        onPressed: _amount <= 0 || over || _saving ? null : _save,
        child: const Text('Ghi thu'),
      ),
      children: [
        Semantics(
          button: true,
          label: 'Số tiền thu ${Formatters.vnd(_amount)}, chạm để sửa',
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('pay-amount'),
            borderRadius: BorderRadius.circular(18),
            onTap: _editAmount,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    Formatters.vnd(_amount),
                    textAlign: TextAlign.center,
                    style: OmniType.moneyHero.copyWith(
                      color: over
                          ? OmniColors.dangerTextOf(context)
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    over
                        ? 'Nhiều hơn số còn phải thu'
                        : 'còn phải thu ${Formatters.vnd(_full)}',
                    textAlign: TextAlign.center,
                    style: OmniType.caption.copyWith(
                      color: over
                          ? OmniColors.dangerTextOf(context)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_full > 0 && _amount != _full)
          Center(
            child: OmniChoicePill(
              key: const ValueKey('pay-full'),
              label: 'Thu đủ',
              selected: false,
              onTap: () => setState(() => _amount = _full),
            ),
          ),
        // Bốn hình thức: "Chuyển khoản" không vừa một ô của thanh chia 4 —
        // hàng nút chọn tự xuống dòng, không cắt chữ.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final m in PaymentMethod.values)
              OmniChoicePill(
                key: ValueKey('pay-method-${m.wire}'),
                label: m.label,
                selected: m == _method,
                onTap: () => setState(() => _method = m),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('pay-date'),
              title: 'Ngày thu',
              value: isToday
                  ? 'Hôm nay, ${Formatters.dayMonth(_paidAt)}'
                  : Formatters.date(_paidAt),
              onTap: _pickDate,
            ),
            OmniGroupRow(
              key: const ValueKey('pay-note'),
              title: 'Ghi chú',
              subtitle: _note.isEmpty ? null : _note,
              value: _note.isEmpty ? 'Thêm' : null,
              onTap: _editNote,
            ),
          ],
        ),
      ],
    );
  }
}
