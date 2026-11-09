import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Kiểu bán trong sheet "Bán / Đặt trước".
enum SellKind { hold, order, append }

/// Mở sheet "Bán / Đặt trước" dùng chung (artifact app bản 7): giá chốt từng
/// cây, ô khách tìm tên / SĐT + tạo nhanh khách, kiểu Đặt trước / Tạo đơn ngay
/// / Thêm vào đơn đang mở, cọc. Xong thì hiện thông báo; trả true khi đã ghi.
///
/// [pickCount] khác null: nhóm model trong lô — chọn số cây (lấy [pickCount]
/// cây đầu của [units]). [allowRetail]: có công tắc "Để bán lẻ" (lô sắp về).
Future<bool> openSellSheet(
  BuildContext context, {
  required List<InventoryUnit> units,
  String title = 'Bán / Đặt trước',
  bool allowRetail = false,
  int? pickCount,
}) async {
  final message = await showOmniSheet<String>(
    context: context,
    builder: (_) => SellSheet(
      units: units,
      title: title,
      allowRetail: allowRetail,
      pickCount: pickCount,
    ),
  );
  if (message == null) return false;
  if (context.mounted) InvUi.toast(context, message);
  return true;
}

class SellSheet extends ConsumerStatefulWidget {
  const SellSheet({
    super.key,
    required this.units,
    this.title = 'Bán / Đặt trước',
    this.allowRetail = false,
    this.pickCount,
  });

  final List<InventoryUnit> units;
  final String title;
  final bool allowRetail;
  final int? pickCount;

  @override
  ConsumerState<SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends ConsumerState<SellSheet> {
  late final Map<String, int> _prices = {
    for (final u in widget.units) u.id: u.suggestedPrice.round(),
  };
  late int? _qty = widget.pickCount;
  InventoryCustomer? _customer;
  String _query = '';
  bool _creating = false;
  InventoryCustomer? _dup;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  SellKind _kind = SellKind.hold;
  int _deposit = 0;
  late bool _retail = widget.units.length == 1 && widget.units.first.retailHold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final first = widget.units.first;
    if (widget.units.length == 1 && first.customerId != null) {
      _customer = InventoryCustomer(
        id: first.customerId!,
        name: first.customerName ?? 'Khách',
      );
      _deposit = (first.deposit ?? 0).round();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  List<InventoryUnit> get _chosen => _qty == null
      ? widget.units
      : widget.units.take(_qty!.clamp(1, widget.units.length)).toList();

  /// Hàng chưa về kho chỉ đặt trước được (API `from-units` đòi `in_stock`).
  bool get _incoming => _chosen.any((u) => u.place != UnitPlace.inStock);

  bool get _alreadyHeld =>
      widget.units.length == 1 &&
      widget.units.first.sale == UnitSale.reserved &&
      widget.pickCount == null;

  InventoryApi get _api => ref.read(inventoryApiProvider);

  List<(SellKind, String)> _kinds(List<OpenOrder> open) {
    final perms = ref.watch(inventoryPermsProvider);
    return [
      if (perms.reserve) (SellKind.hold, 'Đặt trước'),
      if (!_incoming && perms.sell) (SellKind.order, 'Tạo đơn ngay'),
      if (!_incoming && perms.sell && _customer != null && open.isNotEmpty)
        (SellKind.append, 'Thêm vào ${open.first.code}'),
    ];
  }

  Future<void> _editPrice(InventoryUnit u) async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Giá chốt',
      subtitle: u.name,
      initial: _prices[u.id],
    );
    if (v != null) setState(() => _prices[u.id] = v);
  }

  Future<void> _editDeposit() async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Cọc',
      initial: _deposit,
    );
    if (v != null) setState(() => _deposit = v);
  }

  void _startCreate() {
    final q = _query.trim();
    final phone = InventoryFormat.looksLikePhone(q);
    _name.text = phone ? '' : q;
    _phone.text = phone ? q : '';
    setState(() {
      _creating = true;
      _dup = null;
    });
  }

  Future<void> _createCustomer({bool force = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      InvUi.toast(context, 'Nhập tên khách.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (!force && _phone.text.trim().isNotEmpty) {
        final dup = await _api.customerByPhone(_phone.text);
        if (dup != null) {
          setState(() => _dup = dup);
          return;
        }
      }
      final c = await _api.createCustomer(name: name, phone: _phone.text);
      setState(() {
        _customer = c;
        _creating = false;
        _dup = null;
      });
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _release() async {
    setState(() => _saving = true);
    try {
      await _api.release([for (final u in widget.units) u.id]);
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop('Đã bỏ giữ.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  Future<void> _save(SellKind kind, List<OpenOrder> open) async {
    final units = _chosen;
    final ids = [for (final u in units) u.id];
    final prices = {for (final u in units) u.id: _prices[u.id] ?? 0};
    final n = units.length;
    setState(() => _saving = true);
    try {
      String msg;
      if (_retail) {
        await _api.reserve(unitIds: ids, retail: true);
        msg = 'Đã để bán lẻ $n cây.';
      } else if (kind == SellKind.hold) {
        await _api.reserve(
          unitIds: ids,
          customerId: _customer!.id,
          prices: prices,
          deposit: _deposit,
        );
        msg = 'Đã giữ $n cây cho ${_customer!.name}.';
      } else {
        final appendTo = kind == SellKind.append ? open.first : null;
        final order = await _api.sell(
          customerId: _customer!.id,
          unitIds: ids,
          prices: prices,
          orderId: appendTo?.id,
        );
        msg = appendTo != null
            ? 'Đã thêm $n cây vào đơn ${appendTo.code}.'
            : 'Đã tạo đơn ${order.code} cho ${_customer!.name}.';
      }
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop(msg);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = _chosen;
    final total = units.fold<int>(0, (s, u) => s + (_prices[u.id] ?? 0));
    final open = _customer == null || _incoming
        ? const <OpenOrder>[]
        : ref.watch(openOrdersProvider(_customer!.id)).valueOrNull ??
              const <OpenOrder>[];
    final kinds = _kinds(open);
    final kind = kinds.any((k) => k.$1 == _kind)
        ? _kind
        : (kinds.isEmpty ? SellKind.hold : kinds.first.$1);
    final label = _retail
        ? 'Để bán lẻ'
        : switch (kind) {
            SellKind.order => 'Tạo đơn',
            SellKind.append => 'Thêm vào đơn',
            SellKind.hold => 'Đặt trước',
          };
    final ready =
        !_saving && (_retail || _customer != null) && kinds.isNotEmpty;

    final main = FilledButton(
      key: const ValueKey('inv-sell-save'),
      onPressed: ready ? () => _save(kind, open) : null,
      child: Text(label),
    );

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.title,
        subtitle: '${units.length} cây',
      ),
      footer: _alreadyHeld && ref.watch(inventoryPermsProvider).reserve
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('inv-sell-release'),
                    onPressed: _saving ? null : _release,
                    child: const Text('Bỏ giữ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: main),
              ],
            )
          : main,
      children: [
        if (_qty != null && widget.units.length > 1)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Số cây',
                trailing: InvStepper(
                  value: _qty!,
                  min: 1,
                  max: widget.units.length,
                  suffix: '/${widget.units.length}',
                  onChanged: (v) => setState(() => _qty = v),
                ),
              ),
            ],
          ),
        OmniGroupSection(
          title: 'Giá chốt',
          children: [
            for (final u in units)
              OmniGroupRow(
                key: ValueKey('inv-sell-price-${u.id}'),
                title: u.name,
                subtitle:
                    u.serial ??
                    (u.lineNo > 0 ? '#${u.lineNo}' : 'chưa có serial'),
                value: InvUi.vnd(_prices[u.id]),
                onTap: () => _editPrice(u),
              ),
          ],
        ),
        if (widget.allowRetail && ref.watch(inventoryPermsProvider).reserve)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Để bán lẻ',
                trailing: Switch.adaptive(
                  key: const ValueKey('inv-sell-retail'),
                  value: _retail,
                  onChanged: (v) => setState(() => _retail = v),
                ),
              ),
            ],
          ),
        if (!_retail) ..._customerSection(),
        if (!_retail && kinds.length > 1)
          OmniSegmented(
            labels: [for (final k in kinds) k.$2],
            index: kinds.indexWhere((k) => k.$1 == kind),
            onChanged: (i) => setState(() => _kind = kinds[i].$1),
          ),
        if (!_retail && kind == SellKind.hold)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-sell-deposit'),
                title: 'Cọc',
                value: InvUi.vnd(_deposit),
                onTap: _editDeposit,
              ),
            ],
          ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              title: 'Tổng ${units.length} cây',
              trailing: InvValue(InvUi.vnd(total)),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _customerSection() {
    final c = _customer;
    if (c != null) {
      return [
        OmniGroupSection(
          title: 'Khách',
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-sell-customer'),
              icon: Icons.person_outline_rounded,
              title: c.name,
              subtitle: c.phone.isEmpty ? 'chưa có SĐT' : c.phone,
              value: 'Đổi',
              chevron: false,
              onTap: () => setState(() {
                _customer = null;
                _query = '';
              }),
            ),
          ],
        ),
      ];
    }
    if (_creating) {
      final dup = _dup;
      return [
        OmniGroupSection(
          title: 'Khách mới',
          children: [
            InvInputRow(
              label: 'Tên khách',
              controller: _name,
              fieldKey: const ValueKey('inv-new-name'),
              hint: 'Anh Bình',
            ),
            InvInputRow(
              label: 'Số điện thoại',
              controller: _phone,
              fieldKey: const ValueKey('inv-new-phone'),
              hint: '0909 …',
              phone: true,
              onChanged: (_) {
                if (_dup != null) setState(() => _dup = null);
              },
            ),
            if (dup != null) ...[
              OmniGroupRow(
                title: 'SĐT đã thuộc ${dup.name}',
                destructive: true,
                chevron: false,
              ),
              OmniGroupRow(
                icon: Icons.person_outline_rounded,
                title: 'Chọn khách này',
                onTap: () => setState(() {
                  _customer = dup;
                  _creating = false;
                  _dup = null;
                }),
              ),
              OmniGroupRow.add(
                title: 'Vẫn tạo mới',
                onTap: _saving ? () {} : () => _createCustomer(force: true),
              ),
            ] else
              OmniGroupRow.add(
                key: const ValueKey('inv-new-save'),
                title: 'Tạo khách',
                onTap: _saving ? () {} : _createCustomer,
              ),
          ],
        ),
      ];
    }
    final results = ref.watch(customerSearchProvider(_query.trim()));
    final q = _query.trim();
    return [
      OmniSearchField(
        key: const ValueKey('inv-sell-customer-search'),
        hint: 'Tên hoặc SĐT khách',
        flat: true,
        dense: true,
        onChanged: (v) => setState(() => _query = v),
      ),
      OmniGroupSection(
        children: [
          ...switch (results) {
            AsyncData(:final value) => [
              for (final c in value.take(4))
                OmniGroupRow(
                  key: ValueKey('inv-cust-${c.id}'),
                  icon: Icons.person_outline_rounded,
                  title: c.name,
                  subtitle: c.phone.isEmpty ? null : c.phone,
                  chevron: false,
                  onTap: () => setState(() => _customer = c),
                ),
              if (value.isEmpty && q.isEmpty)
                const OmniGroupRow(title: 'Không có khách khớp'),
            ],
            AsyncError() => [const OmniGroupRow(title: 'Không tải được khách')],
            _ => [const OmniGroupRow(title: 'Đang tìm…')],
          },
          OmniGroupRow.add(
            key: const ValueKey('inv-sell-new-customer'),
            title: q.isEmpty ? 'Tạo khách' : 'Tạo khách: $q',
            onTap: _startCreate,
          ),
        ],
      ),
    ];
  }
}
