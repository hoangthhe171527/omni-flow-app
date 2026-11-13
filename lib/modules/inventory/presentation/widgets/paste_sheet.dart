import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import '../../domain/inventory_permissions.dart';
import '../../domain/packing_list.dart';
import 'inventory_ui.dart';

/// Sheet "Dán packing list": bước 1 dán vùng ô copy từ Excel (kèm dòng tiêu
/// đề), bước 2 xem trước (số cây, serial đã sửa, thiếu ¥, thiếu model, cột
/// nhận được) rồi "Thêm N cây".
Future<void> openPasteSheet(BuildContext context, {required Lot lot}) {
  return showOmniSheet<void>(
    context: context,
    expand: true,
    builder: (_) => PasteSheet(lot: lot),
  );
}

class PasteSheet extends ConsumerStatefulWidget {
  const PasteSheet({super.key, required this.lot});

  final Lot lot;

  @override
  ConsumerState<PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends ConsumerState<PasteSheet> {
  final _text = TextEditingController();
  PackingList? _preview;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _next() {
    if (_text.text.trim().isEmpty) {
      InvUi.toast(context, 'Chưa có dòng nào');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _preview = parsePackingList(_text.text));
  }

  Future<void> _save(PackingList pl) async {
    final perms = ref.read(inventoryPermsProvider);
    final rows = pl.valid;
    setState(() => _saving = true);
    try {
      final api = ref.read(inventoryApiProvider);
      final inputs = [for (final r in rows) r.toInput(withYen: perms.cost)];
      // Máy chủ nhận tối đa 500 cây một lượt: packing list dài hơn gửi từng đợt.
      var created = 0;
      var dup = 0;
      for (var i = 0; i < inputs.length; i += 500) {
        final end = i + 500 < inputs.length ? i + 500 : inputs.length;
        final res = await api.addUnits(widget.lot.id, inputs.sublist(i, end));
        created += res.created;
        dup += res.warnings.length;
      }
      bumpInventory(ref);
      if (!mounted) return;
      final n = created == 0 ? rows.length : created;
      InvUi.toast(
        context,
        'Đã thêm $n cây vào ${widget.lot.code}'
        '${dup > 0 ? ' · $dup serial trùng cây khác, nhờ kiểm lại' : ''}',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pl = _preview;
    return pl == null ? _input(context) : _review(context, pl);
  }

  Widget _input(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Dán packing list',
        subtitle: widget.lot.title,
      ),
      footer: OmniTintedButtons(
        child: FilledButton(
          key: const ValueKey('inv-paste-next'),
          onPressed: _next,
          child: const Text('Xem trước'),
        ),
      ),
      children: [
        OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: TextField(
                key: const ValueKey('inv-paste-text'),
                controller: _text,
                minLines: 12,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: OmniType.caption.copyWith(
                  color: scheme.onSurface,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const [OmniType.family],
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Dán các dòng copy từ Excel, gồm cả dòng tiêu đề',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _review(BuildContext context, PackingList pl) {
    final perms = ref.watch(inventoryPermsProvider);
    final scheme = Theme.of(context).colorScheme;
    final valid = pl.valid;
    final fixed = pl.count(PastedIssue.serialFixed);
    final noYen = pl.count(PastedIssue.noYen);
    final noModel = pl.count(PastedIssue.noModel);
    final yenSum = valid.fold<double>(0, (s, r) => s + (r.yenPrice ?? 0));
    final hasCustomer = pl.rows.any((r) => r.customer.isNotEmpty);

    String colsLine() {
      if (pl.columns.isEmpty) return 'Không thấy dòng tiêu đề có MAKER';
      String c(String label, PastedColumn k) =>
          '$label: ${pl.columns[k] ?? 'không có'}';
      return [
        c('Hãng', PastedColumn.maker),
        c('Model', PastedColumn.model),
        c('Serial', PastedColumn.serial),
        if (perms.cost) c('¥', PastedColumn.yenPrice),
        c('Niêm yết', PastedColumn.listPrice),
      ].join(' · ');
    }

    Widget count(String key, String title, int n, {Color? color}) =>
        OmniGroupRow(
          key: ValueKey(key),
          title: title,
          trailing: Text(
            '$n',
            style: OmniType.bodyStrong.copyWith(
              color: color ?? scheme.onSurfaceVariant,
              fontFeatures: OmniType.tabular,
            ),
          ),
        );

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Xem trước · ${pl.rows.length} dòng',
        subtitle: widget.lot.title,
      ),
      footer: OmniTintedButtons(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('inv-paste-back'),
                onPressed: _saving
                    ? null
                    : () => setState(() => _preview = null),
                child: const Text('Sửa lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('inv-paste-save'),
                onPressed: valid.isEmpty || _saving ? null : () => _save(pl),
                child: Text('Thêm ${valid.length} cây'),
              ),
            ),
          ],
        ),
      ),
      children: [
        OmniGroupSection(
          key: const ValueKey('inv-paste-summary'),
          footer: colsLine(),
          children: [
            OmniGroupRow(
              title: '${valid.length} cây',
              value: perms.cost ? InventoryFormat.yen(yenSum) : null,
            ),
            if (fixed > 0) count('inv-paste-fixed', 'Serial đã bỏ “.0”', fixed),
            if (noYen > 0 && perms.cost)
              count(
                'inv-paste-noyen',
                'Thiếu giá ¥',
                noYen,
                color: OmniColors.warningTextOf(context),
              ),
            if (noModel > 0)
              count(
                'inv-paste-nomodel',
                'Thiếu model · bỏ qua',
                noModel,
                color: OmniColors.dangerTextOf(context),
              ),
          ],
        ),
        if (pl.rows.isNotEmpty)
          OmniGroupSection(
            key: const ValueKey('inv-paste-rows'),
            dividerIndent: 14,
            footer: hasCustomer
                ? 'Tên khách chỉ để xem · đặt trước sau khi thêm'
                : null,
            children: [for (final r in pl.rows) _row(context, r, perms)],
          ),
      ],
    );
  }

  Widget _row(BuildContext context, PastedRow r, InventoryPerms perms) {
    final scheme = Theme.of(context).colorScheme;
    final sub = [
      r.serial ?? 'chưa có serial',
      if (InvUi.shortCategory(r.category).isNotEmpty)
        InvUi.shortCategory(r.category),
      ?r.color,
    ].join(' · ');
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.maker} ${r.model.isEmpty ? '—' : r.model}'.trim(),
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(sub, style: invMuted(context)),
                if (r.customer.isNotEmpty)
                  Text(
                    r.customer,
                    style: OmniType.caption.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InvValue(
            (r.listPrice ?? 0) > 0 ? InvUi.vnd(r.listPrice) : '—',
            sub: perms.cost
                ? (r.yenPrice != null
                      ? InventoryFormat.yen(r.yenPrice)
                      : 'thiếu ¥')
                : null,
            subColor: perms.cost && r.yenPrice == null
                ? OmniColors.warningTextOf(context)
                : null,
          ),
        ],
      ),
    );
    return r.skipped ? Opacity(opacity: .5, child: row) : row;
  }
}
