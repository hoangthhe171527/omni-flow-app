import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/receive.dart';
import 'delivered_page.dart' show InvSearchBottom;
import 'widgets/inventory_ui.dart';
import 'widgets/money_keypad_sheet.dart';
import 'widgets/serial_field.dart';

/// Nhận hàng một lô: mặc định mọi cây Đã nhận — chỉ bấm Thiếu / Lỗi; gõ serial
/// hoặc model để dòng khớp lên đầu; cây chưa có serial nhập tại dòng. Xong thì
/// sheet tạo đơn cho cây đặt trước, gom theo khách.
///
/// Đợt A: cây thiếu / lỗi chọn cách xử lý với nhà cung cấp (trừ tiền / bù lô
/// sau / mình chịu; lỗi + trừ tiền cần số ¥) khi API có `inventory.claims`;
/// chọn vị trí nhận khi tenant có từ hai vị trí.
class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key, required this.lotId});

  final String lotId;

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage> {
  final _results = <String, ReceiveResult>{};
  final _serials = <String, String?>{};
  final _claims = <String, ReceiveClaim>{};

  /// Vị trí nhận đã chọn; null = vị trí mặc định.
  String? _locationId;
  String _q = '';
  UnitCondition? _condition;
  late DateTime _date = ref.read(inventoryTodayProvider);
  bool _saving = false;

  ReceiveResult _res(String id) => _results[id] ?? ReceiveResult.ok;

  void _toggle(String id, ReceiveResult r) => setState(() {
    if (_res(id) == r) {
      _results.remove(id);
    } else {
      _results[id] = r;
    }
    // Đổi Thiếu ↔ Lỗi thì cách xử lý về mặc định của loại mới.
    _claims.remove(id);
  });

  ReceiveClaim _claimOf(String id) =>
      _claims[id] ?? ReceiveClaim.defaultFor(_res(id));

  Future<void> _pickClaim(InventoryUnit u) async {
    final defect = _res(u.id) == ReceiveResult.defect;
    final cur = _claimOf(u.id);
    final r = await showInvOptions<ClaimResolution>(
      context: context,
      title: 'Xử lý ${u.name}',
      options: [for (final c in ClaimResolution.values) (c, c.label)],
      selected: cur.resolution,
      // Cây thiếu luôn có khoản đòi: không có "Chưa quyết".
      allLabel: defect ? ClaimResolution.undecidedLabel : null,
    );
    if (r == null || !mounted) return;
    setState(() => _claims[u.id] = cur.copyWith(resolution: () => r.value));
  }

  Future<void> _pickClaimAmount(InventoryUnit u) async {
    final cur = _claimOf(u.id);
    final v = await showMoneyKeypad(
      context: context,
      title: 'Số ¥ được trừ',
      subtitle: u.name,
      initial: cur.amountJpy,
      unit: '¥',
    );
    if (v == null || !mounted) return;
    setState(() => _claims[u.id] = cur.copyWith(amountJpy: () => v));
  }

  Future<void> _pickLocation(List<StockLocation> locations) async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Nhận vào',
      options: [for (final l in locations) (l.id, l.name)],
      selected: _locationId ?? locations.firstOrNull?.id,
    );
    if (r?.value != null && mounted) setState(() => _locationId = r!.value);
  }

  Future<void> _pickCondition() async {
    final r = await showInvOptions<UnitCondition>(
      context: context,
      title: 'Tình trạng ban đầu',
      options: [for (final c in UnitCondition.receivable) (c, c.label)],
      selected: _condition,
      allLabel: UnitCondition.noneLabel,
    );
    if (r != null) setState(() => _condition = r.value);
  }

  Future<void> _pickDate() async {
    final d = await pickOmniDate(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Ngày nhập kho',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _finish(
    Lot lot,
    List<InventoryUnit> units, {
    StockLocation? location,
  }) async {
    final lines = buildReceiveLines(
      units,
      result: _res,
      serials: _serials,
      claims: _claims,
      withClaims: ref.read(inventoryPermsProvider).claims,
    );
    if (missingDeductAmount(lines)) {
      InvUi.toast(context, 'Nhập số ¥ được trừ cho cây lỗi.');
      return;
    }
    setState(() => _saving = true);
    final count = {for (final r in ReceiveResult.values) r: 0};
    for (final u in units) {
      count[_res(u.id)] = count[_res(u.id)]! + 1;
    }
    try {
      await ref
          .read(inventoryApiProvider)
          .receive(
            lot.id,
            receivedAt: InventoryFormat.isoDay(_date),
            condition: _condition,
            results: lines,
            locationId: location?.id,
          );
      bumpInventory(ref);
      if (!mounted) return;
      InvUi.toast(
        context,
        '${lot.code} đã về ${location?.name ?? 'kho'} · '
        '${count[ReceiveResult.ok]} nhận, '
        '${count[ReceiveResult.missing]} thiếu, ${count[ReceiveResult.defect]} lỗi.',
      );
      final groups = groupReservedByCustomer(units, _results);
      final retail = units
          .where((u) => u.retailHold && _res(u.id) != ReceiveResult.missing)
          .length;
      if (ref.read(inventoryPermsProvider).sell && groups.isNotEmpty) {
        await showOmniSheet<void>(
          context: context,
          builder: (_) => ReceiveOrdersSheet(
            groups: groups,
            retail: retail,
            inStock: units.length - count[ReceiveResult.missing]!,
          ),
        );
      }
      if (mounted) Navigator.of(context).maybePop();
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
    final lot = ref.watch(lotProvider(widget.lotId)).valueOrNull;
    final unitsAsync = ref.watch(lotUnitsProvider(widget.lotId));
    final units = unitsAsync.valueOrNull ?? const <InventoryUnit>[];
    final needle = _q.trim().toLowerCase();
    bool hit(InventoryUnit u) =>
        needle.isNotEmpty &&
        '${u.maker} ${u.model} ${u.serial ?? ''} ${_serials[u.id] ?? ''}'
            .toLowerCase()
            .contains(needle);
    final ordered = needle.isEmpty
        ? units
        : [...units.where(hit), ...units.where((u) => !hit(u))];
    int n(ReceiveResult r) => units.where((u) => _res(u.id) == r).length;
    // Chọn nơi nhận chỉ khi tenant có từ hai vị trí (spec §5).
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final locations = multi
        ? ref.watch(locationsProvider).valueOrNull ?? const <StockLocation>[]
        : const <StockLocation>[];
    final location = locations.isEmpty
        ? null
        : locations.firstWhere(
            (l) => l.id == _locationId,
            orElse: () => locations.first,
          );

    void backToLot() =>
        GoRouter.maybeOf(context)?.go('/inventory/lots/${widget.lotId}');

    if (!perms.write) {
      return Scaffold(
        appBar: OmniAppBar(
          title: 'Nhận hàng',
          showAccount: false,
          fallbackBack: backToLot,
        ),
        body: const OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Cần quyền tạo lô, nhận hàng',
        ),
      );
    }

    return Scaffold(
      appBar: OmniAppBar(
        title: lot == null ? 'Nhận hàng' : 'Nhận hàng · ${lot.code}',
        close: true,
        showAccount: false,
        fallbackBack: backToLot,
        bottom: InvSearchBottom(
          fieldKey: const ValueKey('inv-receive-search'),
          hint: 'Gõ serial hoặc model',
          debounce: const Duration(milliseconds: 150),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      // Nút chính trong khay kính đáy (rà soát 12/11) kèm tóm tắt kết quả,
      // không treo lơ lửng trên danh sách.
      body: OmniDockLayer(
        dock: OmniBottomDock(
          title: units.isEmpty
              ? null
              : '${units.where((u) => _res(u.id) == ReceiveResult.ok).length}/${units.length} cây đã nhận',
          subtitle: () {
            final miss = units
                .where((u) => _res(u.id) == ReceiveResult.missing)
                .length;
            final bad = units
                .where((u) => _res(u.id) == ReceiveResult.defect)
                .length;
            if (miss == 0 && bad == 0) return null;
            return [
              if (miss > 0) '$miss thiếu',
              if (bad > 0) '$bad lỗi',
            ].join(' · ');
          }(),
          action: FilledButton(
            key: const ValueKey('inv-receive-finish'),
            onPressed: lot == null || units.isEmpty || _saving
                ? null
                : () => _finish(lot, units, location: location),
            child: const Text('Hoàn tất'),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  OmniDockLayer.listBottom(context),
                ),
                children: [
                  OmniGroupSection(
                    children: [
                      OmniGroupRow(
                        key: const ValueKey('inv-receive-counts'),
                        title:
                            '${n(ReceiveResult.ok)} nhận · ${n(ReceiveResult.missing)} thiếu · ${n(ReceiveResult.defect)} lỗi',
                      ),
                      OmniGroupRow(
                        title: 'Ngày nhập kho',
                        value: InventoryFormat.dmy(
                          InventoryFormat.isoDay(_date),
                        ),
                        onTap: _pickDate,
                      ),
                      OmniGroupRow(
                        title: 'Tình trạng ban đầu',
                        value: UnitCondition.labelOf(_condition),
                        onTap: _pickCondition,
                      ),
                      if (location != null)
                        OmniGroupRow(
                          key: const ValueKey('inv-receive-location'),
                          title: 'Nhận vào',
                          value: location.name,
                          onTap: () => _pickLocation(locations),
                        ),
                    ],
                  ),
                  const SizedBox(height: OmniGroupSection.gap),
                  if (units.isEmpty)
                    unitsAsync.isLoading
                        ? const InvSkeleton()
                        : const OmniGroupSection(
                            children: [OmniGroupRow(title: 'Chưa có cây')],
                          )
                  else
                    OmniGroupSection(
                      children: [
                        for (final u in ordered) ...[
                          _ReceiveRow(
                            key: ValueKey('inv-recv-${u.id}'),
                            unit: u,
                            serial: _serials[u.id] ?? u.serial,
                            hit: hit(u),
                            result: _res(u.id),
                            onToggle: (r) => _toggle(u.id, r),
                            onSerial: (s) async =>
                                setState(() => _serials[u.id] = s),
                          ),
                          if (perms.claims && _res(u.id) != ReceiveResult.ok)
                            ..._claimRows(u),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ReceivePageState {
  /// Dòng lồng dưới cây thiếu / lỗi: cách xử lý, và số ¥ khi lỗi + trừ tiền.
  List<Widget> _claimRows(InventoryUnit u) {
    final c = _claimOf(u.id);
    final needAmount = LotClaim.needsAmount(
      missing: _res(u.id) == ReceiveResult.missing,
      resolution: c.resolution,
    );
    return [
      OmniGroupRow(
        key: ValueKey('inv-recv-claim-${u.id}'),
        leading: const SizedBox(width: 16),
        // Cách xử lý là chữ chính của dòng lồng: đủ chỗ, không xuống dòng.
        title: ClaimResolution.labelOf(c.resolution),
        onTap: () => _pickClaim(u),
      ),
      if (needAmount)
        OmniGroupRow(
          key: ValueKey('inv-recv-amount-${u.id}'),
          leading: const SizedBox(width: 16),
          title: 'Số ¥ được trừ',
          trailing: c.amountJpy == null
              ? Text(
                  'Nhập',
                  style: invMuted(
                    context,
                  ).copyWith(color: OmniColors.warningTextOf(context)),
                )
              : InvValue(InventoryFormat.yen(c.amountJpy)),
          chevron: true,
          onTap: () => _pickClaimAmount(u),
        ),
    ];
  }
}

class _ReceiveRow extends StatelessWidget {
  const _ReceiveRow({
    super.key,
    required this.unit,
    required this.serial,
    required this.hit,
    required this.result,
    required this.onToggle,
    required this.onSerial,
  });

  final InventoryUnit unit;
  final String? serial;
  final bool hit;
  final ReceiveResult result;
  final ValueChanged<ReceiveResult> onToggle;
  final Future<void> Function(String?) onSerial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unit;
    // Cây đã có serial thì API không ghi đè — chỉ cho nhập khi còn trống.
    final canType = u.serial == null || u.serial!.isEmpty;
    return Container(
      color: hit ? scheme.primary.withValues(alpha: .06) : null,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      u.name,
                      style: OmniType.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    SerialField(
                      serial: serial,
                      editable: canType,
                      semanticsName: u.name,
                      onSave: onSerial,
                    ),
                  ],
                ),
                Text(
                  ['#${u.lineNo}', ?u.color].join(' · '),
                  style: invMuted(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OmniChoicePill(
            key: ValueKey('inv-recv-missing-${u.id}'),
            label: 'Thiếu',
            selected: result == ReceiveResult.missing,
            onTap: () => onToggle(ReceiveResult.missing),
          ),
          const SizedBox(width: 6),
          OmniChoicePill(
            key: ValueKey('inv-recv-defect-${u.id}'),
            label: 'Lỗi',
            selected: result == ReceiveResult.defect,
            onTap: () => onToggle(ReceiveResult.defect),
          ),
        ],
      ),
    );
  }
}

/// Sau khi nhận hàng: tạo đơn cho cây đặt trước, mỗi khách một đơn (giá vốn
/// lấy từ kho). Mặc định chọn hết; bỏ chọn khách nào thì không tạo đơn.
class ReceiveOrdersSheet extends ConsumerStatefulWidget {
  const ReceiveOrdersSheet({
    super.key,
    required this.groups,
    required this.retail,
    required this.inStock,
  });

  final List<CustomerOrderGroup> groups;
  final int retail;
  final int inStock;

  @override
  ConsumerState<ReceiveOrdersSheet> createState() => _ReceiveOrdersSheetState();
}

class _ReceiveOrdersSheetState extends ConsumerState<ReceiveOrdersSheet> {
  late final _sel = {for (final g in widget.groups) g.customerId};
  bool _saving = false;

  Future<void> _create() async {
    setState(() => _saving = true);
    var made = 0;
    final errors = <String>[];
    // Lấy API trước vòng lặp: sheet có thể bị đóng giữa các lượt chờ.
    final api = ref.read(inventoryApiProvider);
    for (final g in widget.groups.where((g) => _sel.contains(g.customerId))) {
      try {
        await api.sell(
          customerId: g.customerId,
          unitIds: [for (final u in g.units) u.id],
        );
        made++;
      } catch (e) {
        errors.add('${g.customerName}: ${InvUi.error(e)}');
      }
    }
    bumpInventory(ref);
    if (!mounted) return;
    InvUi.toast(
      context,
      errors.isEmpty
          ? 'Đã tạo $made đơn.'
          : 'Đã tạo $made đơn · ${errors.first}',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final held = widget.groups.fold<int>(0, (s, g) => s + g.units.length);
    final k = _sel.length;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Tạo đơn cho cây đặt trước',
        subtitle: '$held cây đặt trước · ${widget.inStock} cây vào kho',
      ),
      footer: FilledButton(
        key: const ValueKey('inv-receive-orders'),
        onPressed: k == 0 || _saving ? null : _create,
        child: Text('Tạo $k đơn'),
      ),
      children: [
        OmniGroupSection(
          children: [
            for (final g in widget.groups)
              OmniGroupRow(
                key: ValueKey('inv-ord-${g.customerId}'),
                title: g.customerName,
                subtitle: '${g.units.length} cây',
                value: InvUi.vnd(g.total),
                selected: _sel.contains(g.customerId),
                chevron: false,
                onTap: () => setState(
                  () => _sel.contains(g.customerId)
                      ? _sel.remove(g.customerId)
                      : _sel.add(g.customerId),
                ),
              ),
          ],
        ),
        if (widget.retail > 0)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Để bán lẻ',
                subtitle: '${widget.retail} cây',
                value: 'Không tạo đơn',
              ),
            ],
          ),
      ],
    );
  }
}
