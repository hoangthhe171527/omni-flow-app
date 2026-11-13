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
///
/// Đợt B (theo capability): chọn bậc giá (điền giá từng cây và từng dòng),
/// thêm dòng hàng số lượng khi tạo đơn (`items[]`), giữ hàng có ngày nhận cọc,
/// nguồn tiền, hạn giữ. [products]: mở từ Danh mục hàng với `units = []` để
/// bán riêng hàng số lượng.
Future<bool> openSellSheet(
  BuildContext context, {
  required List<InventoryUnit> units,
  String title = 'Bán / Đặt trước',
  bool allowRetail = false,
  int? pickCount,
  List<InvProduct> products = const [],
}) async {
  final message = await showOmniSheet<String>(
    context: context,
    builder: (_) => SellSheet(
      units: units,
      title: title,
      allowRetail: allowRetail,
      pickCount: pickCount,
      products: products,
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
    this.products = const [],
  });

  final List<InventoryUnit> units;
  final String title;
  final bool allowRetail;
  final int? pickCount;

  /// Dòng hàng số lượng có sẵn khi mở (bán từ Danh mục hàng).
  final List<InvProduct> products;

  @override
  ConsumerState<SellSheet> createState() => _SellSheetState();
}

/// Một dòng hàng số lượng trong sheet bán.
class _Item {
  _Item(this.product, this.price);

  final InvProduct product;
  int qty = 1;
  int? price;
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

  // ---- Đợt B ----
  PriceTierKey? _tier;
  late final List<_Item> _items = [
    for (final p in widget.products)
      _Item(p, p.priceOf(PriceTierKey.retail)?.round()),
  ];
  DateTime? _paidAt;
  String? _account;
  DateTime? _expires;

  @override
  void initState() {
    super.initState();
    final first = widget.units.firstOrNull;
    if (widget.units.length == 1 && first?.customerId != null) {
      _customer = InventoryCustomer(
        id: first!.customerId!,
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

  /// Chỉ bán hàng số lượng (mở từ Danh mục hàng): không giữ được.
  bool get _onlyItems => widget.units.isEmpty;

  /// Hàng chưa về kho chỉ đặt trước được (API `from-units` đòi `in_stock`).
  bool get _incoming => _chosen.any((u) => u.place != UnitPlace.inStock);

  bool get _alreadyHeld =>
      widget.units.length == 1 &&
      widget.units.first.sale == UnitSale.reserved &&
      widget.pickCount == null;

  InventoryApi get _api => ref.read(inventoryApiProvider);

  DateTime get _today => ref.read(inventoryTodayProvider);

  List<(SellKind, String)> _kinds(List<OpenOrder> open) {
    final perms = ref.watch(inventoryPermsProvider);
    return [
      if (perms.reserve && !_onlyItems) (SellKind.hold, 'Đặt trước'),
      if (!_incoming && perms.sell) (SellKind.order, 'Tạo đơn ngay'),
      if (!_incoming && perms.sell && _customer != null && open.isNotEmpty)
        (SellKind.append, 'Thêm vào ${open.first.code}'),
    ];
  }

  /// Dòng hàng số lượng chỉ đi kèm đơn (giữ hàng chỉ giữ cây).
  bool _canItems(SellKind kind) =>
      ref.watch(inventoryPermsProvider).stockQty &&
      !_incoming &&
      !_retail &&
      kind != SellKind.hold;

  void _pickTier(PriceTierKey k) {
    setState(() {
      _tier = k;
      for (final u in widget.units) {
        final p = u.tierPrice(k);
        if (p != null) _prices[u.id] = p.round();
      }
      for (final i in _items) {
        final p = i.product.priceOf(k);
        if (p != null) i.price = p.round();
      }
    });
  }

  Future<void> _addItem() async {
    // Giữ provider tự huỷ sống trong lúc chờ (như `_pickLot` ở Tồn kho).
    final sub = ref.listenManual(qtyProductsProvider, (_, _) {});
    final list = await ref
        .read(qtyProductsProvider.future)
        .catchError((_) => <InvProduct>[]);
    sub.close();
    if (!mounted) return;
    final taken = {for (final i in _items) i.product.id};
    final r = await showInvOptions<String>(
      context: context,
      title: 'Thêm hàng số lượng',
      options: [
        for (final p in list)
          if (!taken.contains(p.id))
            (p.id, '${p.code} · ${p.name} · ${p.onHand} ${p.unitLabel}'),
      ],
    );
    final p = list.where((x) => x.id == r?.value).firstOrNull;
    if (p == null || !mounted) return;
    final price = p.priceOf(_tier ?? PriceTierKey.retail);
    setState(() => _items.add(_Item(p, price?.round())));
  }

  Future<void> _editItemPrice(_Item i) async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Giá bán',
      subtitle: i.product.name,
      initial: i.price,
    );
    if (v != null && mounted) setState(() => i.price = v);
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

  Future<void> _pickPaidAt() async {
    final d = await pickOmniDate(
      context: context,
      initialDate: _paidAt ?? _today,
      firstDate: DateTime(2020),
      lastDate: _today,
      helpText: 'Ngày nhận cọc',
    );
    if (d != null && mounted) setState(() => _paidAt = d);
  }

  Future<void> _pickExpires() async {
    final d = await pickOmniDate(
      context: context,
      initialDate: _expires ?? _today.add(const Duration(days: 7)),
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      helpText: 'Hạn giữ',
    );
    if (d != null && mounted) setState(() => _expires = d);
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
    final items = _canItems(kind)
        ? [
            for (final i in _items)
              if (i.qty > 0)
                SellItem(productId: i.product.id, qty: i.qty, price: i.price),
          ]
        : const <SellItem>[];
    final perms = ref.read(inventoryPermsProvider);
    setState(() => _saving = true);
    try {
      String msg;
      if (_retail) {
        await _api.reserve(unitIds: ids, retail: true);
        msg = 'Đã để bán lẻ $n cây.';
      } else if (kind == SellKind.hold) {
        final paid = _deposit > 0;
        await _api.reserve(
          unitIds: ids,
          customerId: _customer!.id,
          prices: prices,
          deposit: _deposit,
          // Đợt B: chỉ gửi khi API có phiếu giữ hàng.
          depositPaidAt: perms.reservations && paid
              ? InventoryFormat.isoDay(_paidAt ?? _today)
              : null,
          moneyAccountId: perms.reservations && paid ? _account : null,
          expiresAt: perms.reservations && _expires != null
              ? InventoryFormat.isoDay(_expires!)
              : null,
        );
        msg = 'Đã giữ $n cây cho ${_customer!.name}.';
      } else {
        final appendTo = kind == SellKind.append ? open.first : null;
        final order = await _api.sell(
          customerId: _customer!.id,
          unitIds: ids,
          prices: prices,
          orderId: appendTo?.id,
          items: items,
        );
        final what = n > 0 ? '$n cây' : '${items.length} dòng';
        msg = appendTo != null
            ? 'Đã thêm $what vào đơn ${appendTo.code}.'
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
    final perms = ref.watch(inventoryPermsProvider);
    final units = _chosen;
    final open = _customer == null || _incoming
        ? const <OpenOrder>[]
        : ref.watch(openOrdersProvider(_customer!.id)).valueOrNull ??
              const <OpenOrder>[];
    final kinds = _kinds(open);
    final kind = kinds.any((k) => k.$1 == _kind)
        ? _kind
        : (kinds.isEmpty ? SellKind.hold : kinds.first.$1);
    final canItems = _canItems(kind);
    final items = canItems ? _items : const <_Item>[];
    final total =
        units.fold<int>(0, (s, u) => s + (_prices[u.id] ?? 0)) +
        items.fold<int>(0, (s, i) => s + i.qty * (i.price ?? 0));
    final tiers = perms.products
        ? ref.watch(priceTiersProvider).valueOrNull ?? const <PriceTier>[]
        : const <PriceTier>[];
    final holdExtras = !_retail && kind == SellKind.hold && perms.reservations;
    final accounts = holdExtras && _deposit > 0 && perms.pay
        ? ref.watch(moneyAccountsProvider).valueOrNull ?? const <MoneyAccount>[]
        : const <MoneyAccount>[];
    final accountName = accounts
        .where((a) => a.id == _account)
        .map((a) => a.name)
        .firstOrNull;
    final label = _retail
        ? 'Để bán lẻ'
        : switch (kind) {
            SellKind.order => 'Tạo đơn',
            SellKind.append => 'Thêm vào đơn',
            SellKind.hold => 'Đặt trước',
          };
    final hasGoods = units.isNotEmpty || items.any((i) => i.qty > 0);
    final ready =
        !_saving &&
        (_retail || _customer != null) &&
        kinds.isNotEmpty &&
        hasGoods;
    final count = [
      if (units.isNotEmpty) '${units.length} cây',
      if (items.isNotEmpty) '${items.length} dòng',
    ].join(' · ');

    final main = FilledButton(
      key: const ValueKey('inv-sell-save'),
      onPressed: ready ? () => _save(kind, open) : null,
      child: Text(label),
    );

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: _onlyItems && widget.title == 'Bán / Đặt trước'
            ? 'Bán hàng'
            : widget.title,
        subtitle: count.isEmpty ? null : count,
      ),
      footer: OmniTintedButtons(
        child: _alreadyHeld && perms.reserve
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
      ),
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
        if (tiers.isNotEmpty && !_retail)
          Wrap(
            key: const ValueKey('inv-sell-tiers'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tiers)
                OmniChoicePill(
                  key: ValueKey('inv-sell-tier-${t.key.wire}'),
                  label: t.name!,
                  selected: _tier == t.key,
                  onTap: () => _pickTier(t.key),
                ),
            ],
          ),
        if (units.isNotEmpty)
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
        if (canItems)
          OmniGroupSection(
            key: const ValueKey('inv-sell-items'),
            title: 'Hàng số lượng',
            children: [
              for (final i in _items)
                OmniGroupRow(
                  key: ValueKey('inv-sell-item-${i.product.id}'),
                  title: i.product.name,
                  subtitle:
                      '${InvUi.vnd(i.price)} / ${i.product.unitLabel} · '
                      'còn ${i.product.onHand}',
                  chevron: false,
                  onTap: () => _editItemPrice(i),
                  trailing: InvStepper(
                    value: i.qty,
                    // Về 0 là bỏ dòng.
                    min: 0,
                    max: 100000,
                    onChanged: (v) => setState(() {
                      if (v <= 0) {
                        _items.remove(i);
                      } else {
                        i.qty = v;
                      }
                    }),
                  ),
                ),
              OmniGroupRow.add(
                key: const ValueKey('inv-sell-add-item'),
                title: 'Thêm hàng số lượng',
                onTap: _addItem,
              ),
            ],
          ),
        if (widget.allowRetail && perms.reserve)
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
              if (holdExtras && _deposit > 0)
                OmniGroupRow(
                  key: const ValueKey('inv-sell-paid-at'),
                  title: 'Ngày nhận cọc',
                  value: InventoryFormat.dmy(
                    InventoryFormat.isoDay(_paidAt ?? _today),
                  ),
                  onTap: _pickPaidAt,
                ),
              if (holdExtras && _deposit > 0 && perms.pay)
                OmniGroupRow(
                  key: const ValueKey('inv-sell-account'),
                  title: 'Nguồn tiền',
                  value: accountName ?? 'Chọn',
                  onTap: () => _pickAccount(accounts),
                ),
              if (holdExtras)
                OmniGroupRow(
                  key: const ValueKey('inv-sell-expires'),
                  title: 'Hạn giữ',
                  value: _expires == null
                      ? 'Chọn'
                      : InventoryFormat.dmy(InventoryFormat.isoDay(_expires!)),
                  onTap: _pickExpires,
                ),
            ],
          ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-sell-total'),
              title: units.isNotEmpty && items.isEmpty
                  ? 'Tổng ${units.length} cây'
                  : 'Tổng',
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
      OmniGlass(
        blur: false,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: OmniSearchField(
            key: const ValueKey('inv-sell-customer-search'),
            hint: 'Tên hoặc SĐT khách',
            flat: true,
            dense: true,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
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
