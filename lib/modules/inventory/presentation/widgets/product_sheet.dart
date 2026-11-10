import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';
import 'sell_sheet.dart';

/// Mở sheet một mã hàng (Danh mục hàng, Kho Đợt B): giá theo bậc, tồn (theo
/// vị trí khi có từ hai vị trí), và với hàng số lượng: Nhập, Chuyển, Đặt số
/// thật, Bán. Sửa trên app chỉ tên và giá (`inventory.settings`).
Future<void> openProductSheet(BuildContext context, InvProduct product) =>
    showOmniSheet<void>(
      context: context,
      builder: (_) => ProductSheet(product: product),
    );

class ProductSheet extends ConsumerStatefulWidget {
  const ProductSheet({super.key, required this.product});

  final InvProduct product;

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  late InvProduct _p = widget.product;
  bool _saving = false;

  InventoryApi get _api => ref.read(inventoryApiProvider);

  Future<void> _run(Future<InvProduct> Function() write, String done) async {
    setState(() => _saving = true);
    try {
      final next = await write();
      bumpInventory(ref);
      if (!mounted) return;
      setState(() => _p = next);
      InvUi.toast(context, done);
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editName() async {
    final v = await showOmniPrompt(
      context: context,
      title: 'Tên hàng',
      confirmLabel: 'Lưu',
      initialValue: _p.name,
      maxLength: 160,
      fieldKey: const ValueKey('inv-product-name-field'),
    );
    final name = v?.trim() ?? '';
    if (name.isEmpty || name == _p.name || !mounted) return;
    await _run(() => _api.updateProduct(_p.id, name: name), 'Đã đổi tên.');
  }

  Future<void> _editPrice(PriceTier t) async {
    final v = await showMoneyKeypad(
      context: context,
      title: t.name!,
      subtitle: _p.name,
      initial: _p.priceOf(t.key),
    );
    if (v == null || !mounted) return;
    await _run(
      () => _api.updateProduct(_p.id, prices: {t.key: v > 0 ? v : null}),
      'Đã lưu ${t.name!.toLowerCase()}.',
    );
  }

  Future<void> _stock(StockAction action) async {
    final next = await openStockActionSheet(
      context,
      product: _p,
      action: action,
    );
    if (next != null && mounted) setState(() => _p = next);
  }

  Future<void> _sell() async {
    final nav = Navigator.of(context);
    final done = await openSellSheet(context, units: const [], products: [_p]);
    if (done && mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final p = _p;
    final tiers = ref.watch(priceTiersProvider).valueOrNull ?? const [];
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final locations =
        ref.watch(locationsProvider).valueOrNull ?? const <StockLocation>[];
    String locName(String id) =>
        locations.where((l) => l.id == id).firstOrNull?.name ?? 'Vị trí cũ';
    final edit = perms.editProducts && !_saving;
    final qty = p.isQty && perms.stockQty;
    final canSell = qty && perms.sell && !p.archived;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: p.name,
        subtitle: [p.code, ?p.categoryName].join(' · '),
      ),
      footer: canSell
          ? FilledButton(
              key: const ValueKey('inv-product-sell'),
              onPressed: _saving ? null : _sell,
              child: const Text('Bán'),
            )
          : null,
      children: [
        OmniGroupSection(
          key: const ValueKey('inv-product-prices'),
          title: 'Giá',
          children: [
            for (final t in tiers)
              // Cây serial: giá lẻ là giá niêm yết của từng cây.
              if (!p.isQty && t.key == PriceTierKey.retail)
                OmniGroupRow(title: t.name!, value: 'theo từng cây')
              else
                OmniGroupRow(
                  key: ValueKey('inv-product-price-${t.key.wire}'),
                  title: t.name!,
                  trailing: InvValue(
                    p.priceOf(t.key) == null
                        ? '—'
                        : InvUi.vnd(p.priceOf(t.key)),
                  ),
                  chevron: edit ? null : false,
                  onTap: edit ? () => _editPrice(t) : null,
                ),
            if (p.isQty && perms.cost)
              OmniGroupRow(
                title: 'Giá vốn',
                trailing: InvValue(
                  p.fixedCost == null ? '—' : InvUi.vnd(p.fixedCost),
                ),
              ),
          ],
        ),
        OmniGroupSection(
          key: const ValueKey('inv-product-stock'),
          title: 'Tồn',
          children: [
            OmniGroupRow(
              title: p.isQty ? 'Tổng' : 'Trong kho',
              trailing: InvValue(
                '${InventoryFormat.number(p.onHand)} ${p.unitLabel}',
              ),
            ),
            if (p.isQty && multi)
              for (final s in p.stock)
                if (s.qty != 0)
                  OmniGroupRow(
                    key: ValueKey('inv-product-loc-${s.locationId}'),
                    title: locName(s.locationId),
                    trailing: InvValue(InventoryFormat.number(s.qty)),
                  ),
          ],
        ),
        if (qty && (perms.write || perms.adjustStock))
          OmniGroupSection(
            children: [
              if (perms.write)
                OmniGroupRow(
                  key: const ValueKey('inv-product-receive'),
                  icon: Icons.add_box_outlined,
                  title: 'Nhập hàng',
                  onTap: _saving ? null : () => _stock(StockAction.receive),
                ),
              if (perms.write && multi && p.onHand > 0)
                OmniGroupRow(
                  key: const ValueKey('inv-product-transfer'),
                  icon: Icons.swap_horiz_rounded,
                  title: 'Chuyển vị trí',
                  onTap: _saving ? null : () => _stock(StockAction.transfer),
                ),
              if (perms.adjustStock)
                OmniGroupRow(
                  key: const ValueKey('inv-product-adjust'),
                  icon: Icons.fact_check_outlined,
                  title: 'Đặt số thật',
                  onTap: _saving ? null : () => _stock(StockAction.adjust),
                ),
            ],
          ),
        if (edit)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-product-rename'),
                icon: Icons.edit_outlined,
                title: 'Đổi tên',
                onTap: _editName,
              ),
            ],
          ),
      ],
    );
  }
}

enum StockAction { receive, transfer, adjust }

/// Sheet nhập / chuyển / đặt số thật một mã hàng số lượng. Trả mã hàng sau
/// khi ghi (null = đóng không ghi).
Future<InvProduct?> openStockActionSheet(
  BuildContext context, {
  required InvProduct product,
  required StockAction action,
}) async {
  final out = await showOmniSheet<(InvProduct, String)>(
    context: context,
    builder: (_) => StockActionSheet(product: product, action: action),
  );
  if (out == null) return null;
  if (context.mounted) InvUi.toast(context, out.$2);
  return out.$1;
}

class StockActionSheet extends ConsumerStatefulWidget {
  const StockActionSheet({
    super.key,
    required this.product,
    required this.action,
  });

  final InvProduct product;
  final StockAction action;

  @override
  ConsumerState<StockActionSheet> createState() => _StockActionSheetState();
}

class _StockActionSheetState extends ConsumerState<StockActionSheet> {
  int? _qty;
  int? _cost;
  String? _from;
  String? _to;
  String? _at;
  final _note = TextEditingController();
  bool _saving = false;

  InvProduct get _p => widget.product;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickQty({int? initial}) async {
    final v = await showMoneyKeypad(
      context: context,
      title: widget.action == StockAction.adjust ? 'Số thật' : 'Số lượng',
      subtitle: _p.name,
      initial: initial,
      unit: _p.unitLabel,
    );
    if (v != null && mounted) setState(() => _qty = v);
  }

  Future<void> _pickCost() async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Giá nhập',
      subtitle: _p.name,
      initial: _cost ?? _p.fixedCost,
    );
    if (v != null && mounted) setState(() => _cost = v > 0 ? v : null);
  }

  Future<void> _pickLocation(
    String title,
    List<(String, String)> options,
    String? selected,
    ValueChanged<String> set,
  ) async {
    final r = await showInvOptions<String>(
      context: context,
      title: title,
      options: options,
      selected: selected,
    );
    final v = r?.value;
    if (v != null && mounted) setState(() => set(v));
  }

  Future<void> _save(String? defaultLoc) async {
    final api = ref.read(inventoryApiProvider);
    final qty = _qty;
    if (qty == null) return;
    setState(() => _saving = true);
    try {
      final (InvProduct, String) out;
      switch (widget.action) {
        case StockAction.receive:
          final p = await api.receiveStock(
            productId: _p.id,
            qty: qty,
            locationId: _at,
            unitCost: _cost,
          );
          out = (p, 'Đã nhập $qty ${_p.unitLabel}.');
        case StockAction.transfer:
          final p = await api.transferStock(
            productId: _p.id,
            from: _from!,
            to: _to!,
            qty: qty,
          );
          out = (p, 'Đã chuyển $qty ${_p.unitLabel}.');
        case StockAction.adjust:
          final r = await api.adjustStock(
            productId: _p.id,
            locationId: _at ?? defaultLoc!,
            qty: qty,
            note: _note.text,
          );
          final d = r.delta;
          out = (
            r.product,
            d == 0
                ? 'Số thật khớp sổ.'
                : 'Đã đặt số thật · ${d > 0 ? '+' : ''}$d ${_p.unitLabel}.',
          );
      }
      bumpInventory(ref);
      if (mounted) Navigator.of(context).pop(out);
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
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final locations =
        ref.watch(locationsProvider).valueOrNull ?? const <StockLocation>[];
    final defaultLoc =
        locations.where((l) => l.isDefault).firstOrNull?.id ??
        _p.stock.firstOrNull?.locationId;
    String name(String? id) =>
        locations.where((l) => l.id == id).firstOrNull?.name ?? 'Vị trí cũ';
    final unit = _p.unitLabel;
    final action = widget.action;

    final title = switch (action) {
      StockAction.receive => 'Nhập hàng',
      StockAction.transfer => 'Chuyển vị trí',
      StockAction.adjust => 'Đặt số thật',
    };
    final atLoc = _at ?? defaultLoc;
    final ready =
        !_saving &&
        _qty != null &&
        switch (action) {
          StockAction.receive => _qty! > 0,
          StockAction.transfer =>
            _qty! > 0 &&
                _from != null &&
                _to != null &&
                _from != _to &&
                _qty! <= _p.qtyAt(_from!),
          StockAction.adjust => atLoc != null && _note.text.trim().isNotEmpty,
        };

    final rows = <Widget>[
      if (action == StockAction.transfer) ...[
        OmniGroupRow(
          key: const ValueKey('inv-stock-from'),
          title: 'Từ',
          value: _from == null
              ? 'Chọn'
              : '${name(_from)} · ${_p.qtyAt(_from!)}',
          onTap: () => _pickLocation(
            'Từ',
            [
              for (final s in _p.stock)
                if (s.qty > 0)
                  (s.locationId, '${name(s.locationId)} · ${s.qty} $unit'),
            ],
            _from,
            (v) => _from = v,
          ),
        ),
        OmniGroupRow(
          key: const ValueKey('inv-stock-to'),
          title: 'Đến',
          value: _to == null ? 'Chọn' : name(_to),
          onTap: () => _pickLocation(
            'Đến',
            [
              for (final l in locations)
                if (l.id != _from) (l.id, l.name),
            ],
            _to,
            (v) => _to = v,
          ),
        ),
      ] else if (multi)
        OmniGroupRow(
          key: const ValueKey('inv-stock-at'),
          title: 'Vị trí',
          value: name(atLoc),
          onTap: () => _pickLocation(
            'Vị trí',
            [for (final l in locations) (l.id, l.name)],
            atLoc,
            (v) => _at = v,
          ),
        ),
      OmniGroupRow(
        key: const ValueKey('inv-stock-qty'),
        title: action == StockAction.adjust ? 'Số thật' : 'Số lượng',
        subtitle: action == StockAction.adjust && atLoc != null
            ? 'Sổ: ${_p.qtyAt(atLoc)} $unit'
            : null,
        value: _qty == null ? 'Nhập' : '${InventoryFormat.number(_qty)} $unit',
        onTap: () => _pickQty(
          initial:
              _qty ??
              (action == StockAction.adjust && atLoc != null
                  ? _p.qtyAt(atLoc)
                  : null),
        ),
      ),
      if (action == StockAction.receive && perms.cost)
        OmniGroupRow(
          key: const ValueKey('inv-stock-cost'),
          title: 'Giá nhập',
          value: _cost == null ? 'Không đổi' : InvUi.vnd(_cost),
          onTap: _pickCost,
        ),
      if (action == StockAction.adjust)
        InvInputRow(
          label: 'Ghi chú',
          controller: _note,
          fieldKey: const ValueKey('inv-stock-note'),
          keyboardType: TextInputType.text,
          onChanged: (_) => setState(() {}),
        ),
    ];

    return OmniSheetBody(
      header: OmniSheetHeader(title: title, subtitle: _p.name),
      footer: FilledButton(
        key: const ValueKey('inv-stock-save'),
        onPressed: ready ? () => _save(defaultLoc) : null,
        child: Text(switch (action) {
          StockAction.receive => 'Nhập',
          StockAction.transfer => 'Chuyển',
          StockAction.adjust => 'Lưu',
        }),
      ),
      children: [OmniGroupSection(children: rows)],
    );
  }
}
