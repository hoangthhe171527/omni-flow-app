import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';
import 'money_keypad_sheet.dart';

/// Sheet "Thêm cây" vào lô: hãng, model gợi ý từ cây đã có (chọn là tự điền
/// loại + giá), loại, màu, serial, số lượng, giá ¥ (quyền giá), giá niêm yết,
/// "Thêm & nhập tiếp".
///
/// [known]: cây đã biết (của lô + tồn kho đã tải) — nguồn gợi ý model và kiểm
/// trùng serial tại chỗ (API vẫn kiểm lại).
Future<void> openAddUnitSheet(
  BuildContext context, {
  required Lot lot,
  required List<InventoryUnit> known,
}) {
  return showOmniSheet<void>(
    context: context,
    builder: (_) => AddUnitSheet(lot: lot, known: known),
  );
}

class AddUnitSheet extends ConsumerStatefulWidget {
  const AddUnitSheet({super.key, required this.lot, required this.known});

  final Lot lot;
  final List<InventoryUnit> known;

  @override
  ConsumerState<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<AddUnitSheet> {
  /// Dòng "Loại khác…" trong sheet chọn loại — mở ô gõ tay.
  static const _otherCategory = '__other__';

  final _maker = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _serial = TextEditingController();
  late final List<ModelSuggestion> _catalog = modelCatalog(widget.known);
  late final List<String> _categories = {
    for (final u in widget.known) ?u.category,
  }.toList()..sort();
  String? _category;
  int _qty = 1;
  int _yen = 0;
  int _price = 0;
  String _picked = '';
  bool _saving = false;
  int _added = 0;

  @override
  void dispose() {
    _maker.dispose();
    _model.dispose();
    _color.dispose();
    _serial.dispose();
    super.dispose();
  }

  void _pick(ModelSuggestion s) {
    setState(() {
      _maker.text = s.maker;
      _model.text = s.model;
      _category = s.category ?? _category;
      if ((s.yenPrice ?? 0) > 0) _yen = s.yenPrice!.round();
      if ((s.listPrice ?? 0) > 0) _price = s.listPrice!.round();
      _picked = s.key;
    });
  }

  Future<void> _pickCategory() async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Loại',
      options: [
        for (final c in _categories) (c, c),
        (_otherCategory, 'Loại khác…'),
      ],
      selected: _category,
    );
    if (r == null || !mounted) return;
    if (r.value == _otherCategory) {
      final typed = await showOmniPrompt(
        context: context,
        title: 'Loại',
        confirmLabel: 'Xong',
        hintText: 'Piano điện cũ',
        maxLength: 60,
      );
      if (typed != null && typed.trim().isNotEmpty) {
        setState(() => _category = typed.trim());
      }
      return;
    }
    setState(() => _category = r.value);
  }

  Future<void> _money(bool yen) async {
    final v = await showMoneyKeypad(
      context: context,
      title: yen ? 'Giá nhập ¥' : 'Niêm yết',
      subtitle: '${_maker.text} ${_model.text}'.trim(),
      initial: yen ? _yen : _price,
      unit: yen ? '¥' : 'đ',
    );
    if (v != null) setState(() => yen ? _yen = v : _price = v);
  }

  bool get _valid =>
      _maker.text.trim().isNotEmpty && _model.text.trim().isNotEmpty;

  String? get _dupSerial {
    if (_qty != 1) return null;
    final sn = InventoryFormat.normalizeSerial(_serial.text);
    final mk = _maker.text.trim().toUpperCase();
    if (sn == null || mk.isEmpty) return null;
    final hit = widget.known.any(
      (u) => u.maker.toUpperCase() == mk && u.serial?.toUpperCase() == sn,
    );
    return hit ? sn : null;
  }

  Future<void> _save({required bool more}) async {
    final perms = ref.read(inventoryPermsProvider);
    final maker = _maker.text.trim().toUpperCase();
    final model = _model.text.trim();
    setState(() => _saving = true);
    try {
      final res = await ref.read(inventoryApiProvider).addUnits(widget.lot.id, [
        NewUnitInput(
          maker: maker,
          model: model,
          category: _category,
          serial: _qty == 1
              ? InventoryFormat.normalizeSerial(_serial.text)
              : null,
          color: _color.text,
          yenPrice: perms.cost && _yen > 0 ? _yen.toDouble() : null,
          listPrice: _price > 0 ? _price.toDouble() : null,
          qty: _qty,
        ),
      ]);
      bumpInventory(ref);
      if (!mounted) return;
      final n = res.created == 0 ? _qty : res.created;
      final dup = res.warnings.where((w) => w.code == 'serial_taken');
      InvUi.toast(
        context,
        dup.isNotEmpty
            ? 'Đã thêm · serial ${dup.first.serial ?? ''} trùng cây khác, nhờ kiểm lại.'
            : 'Đã thêm $n cây $maker $model vào ${widget.lot.code}.',
      );
      if (more) {
        setState(() {
          _added += n;
          _serial.clear();
          _qty = 1;
          _saving = false;
        });
      } else {
        Navigator.of(context).pop();
      }
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
    final query = '${_maker.text} ${_model.text}'.trim();
    final sugg =
        _picked == '${_maker.text}|${_model.text}' || _model.text.trim().isEmpty
        ? const <ModelSuggestion>[]
        : suggestModels(_catalog, query);
    final rate = widget.lot.rateApplied;
    final dup = _dupSerial;
    final ok = _valid && !_saving;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Thêm cây',
        subtitle: [
          widget.lot.title,
          if (_added > 0) 'vừa thêm $_added',
        ].join(' · '),
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('inv-add-more'),
              onPressed: ok ? () => _save(more: true) : null,
              child: const Text('Thêm & nhập tiếp'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              key: const ValueKey('inv-add-one'),
              onPressed: ok ? () => _save(more: false) : null,
              child: const Text('Thêm'),
            ),
          ),
        ],
      ),
      children: [
        OmniGroupSection(
          children: [
            InvInputRow(
              key: const ValueKey('inv-add-maker'),
              label: 'Hãng',
              controller: _maker,
              fieldKey: const ValueKey('inv-add-maker-field'),
              hint: 'YAMAHA',
              caps: true,
              onChanged: (_) => setState(() => _picked = ''),
            ),
            InvInputRow(
              key: const ValueKey('inv-add-model'),
              label: 'Model',
              controller: _model,
              fieldKey: const ValueKey('inv-add-model-field'),
              hint: 'U3H',
              caps: true,
              onChanged: (_) => setState(() => _picked = ''),
            ),
            for (final s in sugg)
              OmniGroupRow(
                key: ValueKey('inv-add-sugg-${s.key}'),
                icon: Icons.search_rounded,
                title: '${s.maker} ${s.model}',
                subtitle: [
                  if (s.category != null) InvUi.shortCategory(s.category),
                  if (perms.cost && (s.yenPrice ?? 0) > 0)
                    InventoryFormat.yen(s.yenPrice),
                ].join(' · '),
                value: (s.listPrice ?? 0) > 0 ? InvUi.vnd(s.listPrice) : null,
                chevron: false,
                onTap: () => _pick(s),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-add-category'),
              title: 'Loại',
              value: _category ?? 'Chọn',
              onTap: _pickCategory,
            ),
            InvInputRow(
              label: 'Màu',
              controller: _color,
              fieldKey: const ValueKey('inv-add-color-field'),
              hint: 'Đen, BLK…',
              caps: true,
            ),
            if (_qty == 1)
              InvInputRow(
                label: 'Serial',
                controller: _serial,
                fieldKey: const ValueKey('inv-add-serial-field'),
                hint: 'Để trống nếu chưa có',
                caps: true,
                onChanged: (_) => setState(() {}),
              ),
            OmniGroupRow(
              title: 'Số lượng',
              subtitle: _qty > 1 ? 'cây giống nhau, chưa serial' : null,
              trailing: InvStepper(
                value: _qty,
                min: 1,
                max: 50,
                onChanged: (v) => setState(() {
                  _qty = v;
                  if (v > 1) _serial.clear();
                }),
              ),
            ),
          ],
        ),
        OmniGroupSection(
          children: [
            if (perms.cost)
              OmniGroupRow(
                key: const ValueKey('inv-add-yen'),
                title: 'Giá nhập ¥',
                value: InventoryFormat.yen(_yen),
                onTap: () => _money(true),
              ),
            OmniGroupRow(
              key: const ValueKey('inv-add-price'),
              title: 'Niêm yết',
              value: InvUi.vnd(_price),
              onTap: () => _money(false),
            ),
            if (perms.cost && _yen > 0 && rate != null)
              OmniGroupRow(
                title: 'Giá vốn tạm',
                subtitle:
                    '${InventoryFormat.yen(_yen)} × ${InventoryFormat.rate(rate)}',
                value: InvUi.vnd(_yen * rate * _qty),
              ),
            if (dup != null)
              OmniGroupRow(
                title:
                    'Serial $dup đã có ở cây ${_maker.text.trim().toUpperCase()} khác',
                destructive: true,
                chevron: false,
              ),
          ],
        ),
      ],
    );
  }
}
