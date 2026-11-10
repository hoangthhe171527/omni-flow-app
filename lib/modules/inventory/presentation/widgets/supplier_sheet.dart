import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// Sửa hồ sơ nhà cung cấp (`PUT /inventory/suppliers/{id}`, quyền
/// `inventory.suppliers`): tên, nguồn, loại, tiền tệ, hạn trả, liên hệ, tài
/// khoản (tối đa 5), ghi chú. Mã không đổi. Trả hồ sơ đã lưu.
Future<SupplierDetail?> openSupplierSheet(
  BuildContext context, {
  required SupplierDetail supplier,
}) => showOmniSheet<SupplierDetail>(
  context: context,
  builder: (_) => SupplierSheet(supplier: supplier),
);

class SupplierSheet extends ConsumerStatefulWidget {
  const SupplierSheet({super.key, required this.supplier});

  final SupplierDetail supplier;

  @override
  ConsumerState<SupplierSheet> createState() => _SupplierSheetState();
}

typedef _BankCtl = ({
  TextEditingController bank,
  TextEditingController number,
  TextEditingController holder,
});

class _SupplierSheetState extends ConsumerState<SupplierSheet> {
  static const _maxBanks = 5;

  late final SupplierDetail _s = widget.supplier;
  late final _name = TextEditingController(text: _s.name);
  late final _tax = TextEditingController(text: _s.taxId ?? '');
  late final _phone = TextEditingController(text: _s.phone ?? '');
  late final _address = TextEditingController(text: _s.address ?? '');
  late final _note = TextEditingController(text: _s.note ?? '');
  late final _days = TextEditingController(
    text: _s.termDays == null ? '' : '${_s.termDays}',
  );
  late final List<_BankCtl> _banks = [
    for (final b in _s.bankAccounts) _bank(b),
  ];
  late bool _foreign = _s.foreign;
  late bool _person = _s.person;
  late String _currency = _s.currency;
  late PaymentTermKind _term = _s.term;
  bool _saving = false;

  static _BankCtl _bank([BankAccount? b]) => (
    bank: TextEditingController(text: b?.bank ?? ''),
    number: TextEditingController(text: b?.number ?? ''),
    holder: TextEditingController(text: b?.holder ?? ''),
  );

  @override
  void dispose() {
    for (final c in [_name, _tax, _phone, _address, _note, _days]) {
      c.dispose();
    }
    for (final b in _banks) {
      b.bank.dispose();
      b.number.dispose();
      b.holder.dispose();
    }
    super.dispose();
  }

  SupplierInput _input() => SupplierInput(
    name: _name.text,
    foreign: _foreign,
    person: _person,
    currency: _currency,
    term: _term,
    termDays: int.tryParse(_days.text.trim()),
    taxId: _tax.text,
    phone: _phone.text,
    address: _address.text,
    note: _note.text,
    bankAccounts: [
      for (final b in _banks)
        BankAccount(
          bank: b.bank.text,
          number: b.number.text,
          holder: b.holder.text,
        ),
    ],
  );

  Future<void> _pick<T>(
    String title,
    List<(T, String)> options,
    T current,
    ValueChanged<T> set,
  ) async {
    final r = await showInvOptions<T>(
      context: context,
      title: title,
      options: options,
      selected: current,
    );
    final v = r?.value;
    if (v != null && mounted) setState(() => set(v));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      InvUi.toast(context, 'Nhập tên nhà cung cấp.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(inventoryApiProvider)
          .updateSupplier(_s.id, _input());
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OmniSheetBody(
      header: OmniSheetHeader(title: 'Sửa hồ sơ', subtitle: _s.code),
      footer: FilledButton(
        key: const ValueKey('inv-sup-save'),
        onPressed: _saving ? null : _save,
        child: const Text('Lưu'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            InvInputRow(
              label: 'Tên',
              controller: _name,
              fieldKey: const ValueKey('inv-sup-name'),
            ),
            InvInputRow(
              label: 'Điện thoại',
              controller: _phone,
              phone: true,
              fieldKey: const ValueKey('inv-sup-phone'),
            ),
            InvInputRow(
              label: 'Địa chỉ',
              controller: _address,
              fieldKey: const ValueKey('inv-sup-address'),
            ),
            InvInputRow(
              label: 'Mã số thuế / CCCD',
              controller: _tax,
              keyboardType: TextInputType.text,
              fieldKey: const ValueKey('inv-sup-tax'),
            ),
          ],
        ),
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-sup-origin'),
              title: 'Nguồn',
              value: _foreign ? 'Nước ngoài' : 'Trong nước',
              onTap: () => _pick<bool>(
                'Nguồn',
                const [(true, 'Nước ngoài'), (false, 'Trong nước')],
                _foreign,
                (v) => _foreign = v,
              ),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-sup-party'),
              title: 'Loại',
              value: _person ? 'Cá nhân' : 'Tổ chức',
              onTap: () => _pick<bool>(
                'Loại',
                const [(false, 'Tổ chức'), (true, 'Cá nhân')],
                _person,
                (v) => _person = v,
              ),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-sup-currency'),
              title: 'Tiền tệ',
              value: _currency,
              onTap: () => _pick<String>(
                'Tiền tệ',
                const [('JPY', 'JPY'), ('VND', 'VND')],
                _currency,
                (v) => _currency = v,
              ),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-sup-term'),
              title: 'Hạn trả',
              value: _term.label,
              onTap: () => _pick<PaymentTermKind>(
                'Hạn trả',
                [for (final t in PaymentTermKind.values) (t, t.label)],
                _term,
                (v) => _term = v,
              ),
            ),
            if (_term == PaymentTermKind.days) _DaysRow(controller: _days),
          ],
        ),
        for (var i = 0; i < _banks.length; i++)
          OmniGroupSection(
            key: ValueKey('inv-sup-bank-$i'),
            title: i == 0 ? 'Tài khoản' : null,
            dividerIndent: 14,
            children: [
              InvInputRow(
                label: 'Ngân hàng',
                controller: _banks[i].bank,
                fieldKey: ValueKey('inv-sup-bank-name-$i'),
              ),
              InvInputRow(
                label: 'Số tài khoản',
                controller: _banks[i].number,
                keyboardType: TextInputType.text,
                fieldKey: ValueKey('inv-sup-bank-number-$i'),
              ),
              InvInputRow(
                label: 'Chủ tài khoản',
                controller: _banks[i].holder,
                fieldKey: ValueKey('inv-sup-bank-holder-$i'),
              ),
              OmniGroupRow(
                key: ValueKey('inv-sup-bank-remove-$i'),
                title: 'Bỏ tài khoản',
                destructive: true,
                onTap: () => setState(() {
                  final b = _banks.removeAt(i);
                  // Huỷ sau khung hình: ô nhập còn đang gỡ khỏi cây widget.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    b.bank.dispose();
                    b.number.dispose();
                    b.holder.dispose();
                  });
                }),
              ),
            ],
          ),
        if (_banks.length < _maxBanks)
          OmniGroupSection(
            children: [
              OmniGroupRow.add(
                key: const ValueKey('inv-sup-bank-add'),
                title: 'Thêm tài khoản',
                onTap: () => setState(() => _banks.add(_bank())),
              ),
            ],
          ),
        OmniGroupSection(
          children: [
            InvInputRow(
              label: 'Ghi chú',
              controller: _note,
              keyboardType: TextInputType.multiline,
              fieldKey: const ValueKey('inv-sup-note'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ô số ngày của hạn "Trả sau số ngày" (1–365).
class _DaysRow extends StatelessWidget {
  const _DaysRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => InvInputRow(
    label: 'Số ngày',
    controller: controller,
    hint: '30',
    keyboardType: TextInputType.number,
    fieldKey: const ValueKey('inv-sup-days'),
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(3),
    ],
  );
}
