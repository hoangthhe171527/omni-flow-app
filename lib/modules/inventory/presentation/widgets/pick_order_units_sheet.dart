import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// Cây chọn được cho đơn mới: còn bán, đang trong kho, chưa thuộc đơn nào
/// (server đòi `in_stock`, như web `pickableFor`). Cây đang giữ cho khách thì
/// tấm Bán tự hỏi tiếp.
bool pickableForOrder(InventoryUnit u) =>
    u.place == UnitPlace.inStock &&
    u.orderId == null &&
    u.sale != UnitSale.sold;

/// Tạo đơn · Chọn đàn (bản mẫu NWUQNP): ô tìm, nhóm lồng, ✓ màu chính, giá
/// niêm yết, nút đáy "Thêm N cây". Trả các cây đã chọn.
Future<List<InventoryUnit>?> pickOrderUnits(BuildContext context) =>
    showOmniSheet<List<InventoryUnit>>(
      context: context,
      builder: (_) => const _PickOrderUnitsSheet(),
    );

class _PickOrderUnitsSheet extends ConsumerStatefulWidget {
  const _PickOrderUnitsSheet();

  @override
  ConsumerState<_PickOrderUnitsSheet> createState() =>
      _PickOrderUnitsSheetState();
}

class _PickOrderUnitsSheetState extends ConsumerState<_PickOrderUnitsSheet> {
  final _picked = <String, InventoryUnit>{};
  List<InventoryUnit> _rows = const [];
  bool _loading = true;
  Object? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  Future<void> _load(String q) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(inventoryApiProvider)
          .listUnits(
            place: UnitPlace.inStock.wire,
            q: q.trim().isEmpty ? null : q.trim(),
            limit: 50,
          );
      if (!mounted || seq != _seq) return;
      setState(() => _rows = page.items);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e);
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  void _toggle(InventoryUnit u) => setState(() {
    if (_picked.remove(u.id) == null) _picked[u.id] = u;
  });

  @override
  Widget build(BuildContext context) {
    // Đã chọn lên đầu, giữ khi đổi từ khoá; cây chọn được trước cây mờ.
    final rows = [
      ..._picked.values,
      for (final u in _rows)
        if (!_picked.containsKey(u.id) && pickableForOrder(u)) u,
      for (final u in _rows)
        if (!_picked.containsKey(u.id) && !pickableForOrder(u)) u,
    ];
    final n = _picked.length;

    return OmniSheetBody(
      header: const OmniSheetHeader(title: 'Chọn đàn'),
      footer: FilledButton(
        key: const ValueKey('pick-order-units-done'),
        onPressed: n == 0
            ? null
            : () => Navigator.of(context).pop(_picked.values.toList()),
        child: Text(n == 0 ? 'Chọn đàn' : 'Thêm $n cây'),
      ),
      children: [
        OmniSearchField(
          key: const ValueKey('pick-order-units-search'),
          hint: 'Tìm serial, model',
          onChanged: _load,
        ),
        if (rows.isNotEmpty)
          OmniGroupSection(
            children: [
              for (final u in rows)
                OmniGroupRow(
                  key: ValueKey('pick-order-unit-${u.id}'),
                  title: [u.name, ?u.serial].join(' '),
                  subtitle: pickableForOrder(u)
                      ? [
                          u.condition?.label ?? 'Chưa kiểm',
                          ?u.lotCode,
                          if (u.sale == UnitSale.reserved) ?u.customerName,
                        ].join(' · ')
                      : u.sale == UnitSale.sold || u.orderId != null
                      ? 'Đã vào đơn'
                      : 'Không chọn được',
                  value: u.listPrice == null
                      ? null
                      : Formatters.vnd(u.listPrice),
                  selected: _picked.containsKey(u.id),
                  chevron: false,
                  onTap: pickableForOrder(u) ? () => _toggle(u) : null,
                ),
            ],
          )
        else if (_loading)
          const InvSkeleton(count: 3, height: 56)
        else if (_error != null)
          OmniGroupSection(
            children: [OmniGroupRow(title: InvUi.error(_error!))],
          )
        else
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có cây khớp')],
          ),
      ],
    );
  }
}
