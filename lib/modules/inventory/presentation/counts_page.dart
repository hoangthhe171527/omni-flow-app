import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_tab_routes.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../routes.dart';
import 'delivered_page.dart' show InvSearchBottom;
import 'widgets/inventory_ui.dart';
import 'widgets/money_keypad_sheet.dart';

/// Kiểm kê theo vị trí (Kho chuẩn hóa Đợt C §2.4, theo web `counts-page`):
/// chọn vị trí (khi có từ hai vị trí), mở phiên, gõ serial để tick (khớp đúng
/// một cây thì tick và xoá ô), chạm dòng để tick tay, đếm hàng số lượng, chốt.
/// Cây không tick khi chốt thành "Không thấy", chờ người có
/// `inventory.settings` duyệt; không tự xoá cây. Lưu ngầm sau mỗi lần tick.
class CountsPage extends ConsumerStatefulWidget {
  const CountsPage({super.key});

  @override
  ConsumerState<CountsPage> createState() => _CountsPageState();
}

/// Chuẩn hoá serial để so: bỏ khoảng trắng, chữ hoa.
String normSerial(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();

class _CountsPageState extends ConsumerState<CountsPage> {
  String? _pickedLoc;

  /// Phiên đang mở mà [_seen] / [_qty] đang giữ.
  String? _countId;
  Set<String> _seen = {};
  Map<String, int> _qty = {};
  Timer? _timer;
  bool _busy = false;

  /// Chữ đang gõ trong ô serial (lọc danh sách).
  String _query = '';

  /// Đổi để dựng lại ô serial rỗng sau khi tick bằng gõ.
  int _fieldGen = 0;

  /// Cây vừa tick bằng gõ serial (hiện dưới "Đã thấy").
  String? _lastHit;

  /// API giữ lại để lưu nốt khi rời màn trong lúc chờ lưu ngầm.
  InventoryApi? _api;

  @override
  void dispose() {
    final pending = _timer?.isActive ?? false;
    _timer?.cancel();
    final id = _countId;
    if (pending && id != null) {
      _api?.saveCount(id, seenUnitIds: _seen.toList(), qty: _qty).ignore();
    }
    super.dispose();
  }

  void _adopt(StockCount c) {
    if (_countId == c.id) return;
    _timer?.cancel();
    _countId = c.id;
    _seen = {...c.seenUnitIds};
    _qty = {...c.qty};
  }

  Future<void> _flush() async {
    _timer?.cancel();
    final id = _countId;
    if (id == null) return;
    await ref
        .read(inventoryApiProvider)
        .saveCount(id, seenUnitIds: _seen.toList(), qty: _qty);
  }

  /// Lưu ngầm sau một nhịp ngừng tick — rời màn giữa chừng vẫn còn cây đã tick.
  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      _flush().catchError((Object e) {
        if (mounted) InvUi.toast(context, InvUi.error(e));
      });
    });
  }

  void _toggle(String unitId) {
    setState(
      () => _seen.contains(unitId) ? _seen.remove(unitId) : _seen.add(unitId),
    );
    _schedule();
  }

  void _tickAll(List<InventoryUnit> units) {
    setState(() => _seen.addAll(units.map((u) => u.id)));
    _schedule();
  }

  /// Gõ serial: khớp đúng một cây ở vị trí thì tick và xoá ô.
  void _onSerial(String v, List<InventoryUnit> units, bool canEdit) {
    final key = normSerial(v);
    if (canEdit && key.isNotEmpty) {
      final hits = [
        for (final u in units)
          if (u.serial != null && normSerial(u.serial!) == key) u,
      ];
      if (hits.length == 1) {
        final u = hits.single;
        final already = _seen.contains(u.id);
        // Báo ngay trên trang (dòng Đã thấy), không bằng thông báo nổi —
        // thông báo nằm đè nút Chốt khi gõ liên tục.
        setState(() {
          _seen.add(u.id);
          _lastHit = '${u.name} ${u.serial}';
          _query = '';
          _fieldGen++;
        });
        if (!already) _schedule();
        return;
      }
    }
    setState(() => _query = v);
  }

  Future<void> _countQty(InvProduct p, String locationId) async {
    final v = await showMoneyKeypad(
      context: context,
      title: 'Đếm được',
      subtitle: '${p.name} · sổ ${p.qtyAt(locationId)} ${p.unitLabel}',
      initial: _qty[p.id],
      unit: p.unitLabel,
    );
    if (v == null || !mounted) return;
    setState(() => _qty[p.id] = v);
    _schedule();
  }

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) InvUi.toast(context, done);
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(String locationId) => _run(() async {
    await ref.read(inventoryApiProvider).openCount(locationId);
    ref.invalidate(countsProvider(locationId));
  }, 'Đã mở phiên kiểm kê.');

  Future<void> _submit(String locationId, int notSeen) async {
    final ok = await showOmniConfirm(
      context: context,
      title: 'Chốt kiểm kê',
      message: notSeen == 0
          ? 'Thấy đủ mọi cây.'
          : '$notSeen cây chưa tick sẽ ghi Không thấy.',
      confirmLabel: 'Chốt',
    );
    if (!ok || !mounted) return;
    final id = _countId;
    if (id == null) return;
    await _run(() async {
      await _flush();
      await ref.read(inventoryApiProvider).submitCount(id);
      _countId = null;
      ref.invalidate(countsProvider(locationId));
    }, 'Đã chốt, chờ duyệt.');
  }

  Future<void> _approve(StockCount c) async {
    final ok = await showOmniConfirm(
      context: context,
      title: 'Duyệt kiểm kê',
      message: c.missingUnits.isEmpty
          ? 'Ghi sổ theo kết quả đã chốt.'
          : '${c.missingUnits.length} cây ghi Không thấy.',
      confirmLabel: 'Duyệt',
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(inventoryApiProvider).approveCount(c.id);
      bumpInventory(ref);
    }, 'Đã duyệt kiểm kê.');
  }

  Future<void> _pickLocation(List<StockLocation> locations, String at) async {
    final r = await showInvOptions<String>(
      context: context,
      title: 'Vị trí',
      options: [for (final l in locations) (l.id, l.name)],
      selected: at,
    );
    final v = r?.value;
    if (v == null || v == at || !mounted) return;
    await _flush().catchError((_) {});
    setState(() {
      _pickedLoc = v;
      _countId = null;
      _query = '';
      _lastHit = null;
      _fieldGen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    _api = ref.watch(inventoryApiProvider);
    final subPage = !ShellTabRoutes.reachable(context, InventoryRoutes.counts);
    void back() => GoRouter.maybeOf(context)?.go(InventoryRoutes.stockPath);
    if (!perms.counts) {
      return Scaffold(
        appBar: OmniAppBar(
          title: 'Kiểm kê',
          showAccount: !subPage,
          fallbackBack: subPage ? back : null,
        ),
        body: const OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chưa có kiểm kê',
        ),
      );
    }
    final locs = ref.watch(locationsProvider);
    final locations = locs.valueOrNull ?? const <StockLocation>[];
    final locationId =
        (_pickedLoc != null && locations.any((l) => l.id == _pickedLoc)
            ? _pickedLoc
            : null) ??
        locations.firstOrNull?.id;
    if (locationId == null) {
      return Scaffold(
        appBar: OmniAppBar(
          title: 'Kiểm kê',
          showAccount: !subPage,
          fallbackBack: subPage ? back : null,
        ),
        body: switch (locs) {
          AsyncValue(:final error?) => OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(locationsProvider),
          ),
          AsyncValue(hasValue: true) => const OmniEmptyState(
            icon: Icons.warehouse_outlined,
            title: 'Chưa có vị trí kho',
          ),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: InvSkeleton(count: 4, height: 56),
          ),
        },
      );
    }

    final counts = ref.watch(countsProvider(locationId));
    final list = counts.valueOrNull;
    final current = list
        ?.where((c) => c.status != CountStatus.approved)
        .firstOrNull;
    final lastApproved = list
        ?.where((c) => c.status == CountStatus.approved)
        .firstOrNull;
    final open = current?.status == CountStatus.open ? current : null;
    if (open != null) _adopt(open);

    final units = open == null
        ? null
        : ref.watch(countUnitsProvider(locationId));
    final unitList = units?.valueOrNull ?? const <InventoryUnit>[];
    final qtyProducts = open == null
        ? const <InvProduct>[]
        : [
            for (final p
                in ref.watch(qtyProductsProvider).valueOrNull ??
                    const <InvProduct>[])
              if (_qty.containsKey(p.id) || p.qtyAt(locationId) != 0) p,
          ];
    final canEdit = open != null && perms.doCounts && !_busy;
    final seenHere = unitList.where((u) => _seen.contains(u.id)).length;
    final q = normSerial(_query);
    final shown = q.isEmpty
        ? unitList
        : [
            for (final u in unitList)
              if (normSerial('${u.serial ?? ''} ${u.model}').contains(q) ||
                  normSerial(u.name).contains(q))
                u,
          ];

    final locationRow = locations.length > 1
        ? OmniGroupRow(
            key: const ValueKey('inv-count-location'),
            icon: Icons.place_outlined,
            title: 'Vị trí',
            value: locations.where((l) => l.id == locationId).firstOrNull?.name,
            onTap: _busy ? null : () => _pickLocation(locations, locationId),
          )
        : null;

    Widget? action;
    final children = <Widget>[];
    switch (counts) {
      case AsyncValue(:final error?) when list == null:
        children.add(
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(countsProvider(locationId)),
          ),
        );
      case _ when list == null:
        children.add(const InvSkeleton(count: 4, height: 56));
      case _ when open != null:
        children.addAll([
          OmniGroupSection(
            key: const ValueKey('inv-count-head'),
            children: [
              ?locationRow,
              OmniGroupRow(
                key: const ValueKey('inv-count-progress'),
                title: 'Đã thấy',
                subtitle: _lastHit,
                trailing: InvValue(
                  units?.hasValue ?? false
                      ? '${InventoryFormat.number(seenHere)} / '
                            '${InventoryFormat.number(unitList.length)} cây'
                      : '—',
                ),
              ),
              if (canEdit && unitList.isNotEmpty && seenHere < unitList.length)
                OmniGroupRow(
                  key: const ValueKey('inv-count-tick-all'),
                  icon: Icons.done_all_rounded,
                  accent: true,
                  title: 'Tick tất cả',
                  chevron: false,
                  onTap: () => _tickAll(unitList),
                ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          ...switch (units!) {
            AsyncValue(:final error?) when !units.hasValue => [
              OmniErrorView(
                error: InvUi.error(error),
                onRetry: () => ref.invalidate(countUnitsProvider(locationId)),
              ),
            ],
            AsyncValue(hasValue: false) => [
              const InvSkeleton(count: 5, height: 56),
            ],
            _ when shown.isEmpty => [
              OmniGroupSection(
                children: [
                  OmniGroupRow(
                    title: unitList.isEmpty
                        ? 'Không có cây ở vị trí này'
                        : 'Không có serial này',
                  ),
                ],
              ),
            ],
            _ => [
              OmniGroupSection(
                key: const ValueKey('inv-count-units'),
                children: [
                  for (final u in shown)
                    CountUnitRow(
                      key: ValueKey('inv-count-unit-${u.id}'),
                      unit: u,
                      seen: _seen.contains(u.id),
                      onTap: canEdit ? () => _toggle(u.id) : null,
                    ),
                ],
              ),
            ],
          },
          if (qtyProducts.isNotEmpty) ...[
            const SizedBox(height: OmniGroupSection.gap),
            OmniGroupSection(
              key: const ValueKey('inv-count-qty'),
              title: 'Hàng số lượng',
              children: [
                for (final p in qtyProducts)
                  OmniGroupRow(
                    key: ValueKey('inv-count-qty-${p.id}'),
                    title: p.name,
                    subtitle:
                        'Sổ ${InventoryFormat.number(p.qtyAt(locationId))} ${p.unitLabel}',
                    value: _qty[p.id] == null
                        ? 'Đếm'
                        : '${InventoryFormat.number(_qty[p.id])} ${p.unitLabel}',
                    chevron: canEdit,
                    onTap: canEdit ? () => _countQty(p, locationId) : null,
                  ),
              ],
            ),
          ],
        ]);
        if (perms.doCounts && (units.hasValue)) {
          action = FilledButton(
            key: const ValueKey('inv-count-submit'),
            onPressed: _busy
                ? null
                : () => _submit(locationId, unitList.length - seenHere),
            child: const Text('Chốt kiểm kê'),
          );
        }
      case _ when current != null:
        children.add(
          CountResultSection(count: current, locationRow: locationRow),
        );
        if (perms.approveCounts) {
          action = FilledButton(
            key: const ValueKey('inv-count-approve'),
            onPressed: _busy ? null : () => _approve(current),
            child: const Text('Duyệt'),
          );
        }
      default:
        if (lastApproved != null) {
          children.add(
            CountResultSection(count: lastApproved, locationRow: locationRow),
          );
        } else if (locationRow != null) {
          children.add(OmniGroupSection(children: [locationRow]));
        } else {
          children.add(
            const OmniGroupSection(
              children: [OmniGroupRow(title: 'Chưa kiểm kê lần nào')],
            ),
          );
        }
        if (perms.doCounts) {
          action = FilledButton(
            key: const ValueKey('inv-count-start'),
            onPressed: _busy ? null : () => _start(locationId),
            child: const Text('Bắt đầu kiểm kê'),
          );
        }
    }

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Kiểm kê',
        showAccount: !subPage,
        fallbackBack: subPage ? back : null,
        bottom: open != null && perms.doCounts
            ? InvSearchBottom(
                key: ValueKey('inv-count-serial-$_fieldGen'),
                fieldKey: const ValueKey('inv-count-serial'),
                hint: 'Gõ serial để tick',
                onChanged: (v) => _onSerial(v, unitList, canEdit),
              )
            : null,
      ),
      // Nút chính (Bắt đầu / Chốt / Duyệt) trong khay kính đáy.
      body: OmniDockLayer(
        dock: action == null ? null : OmniBottomDock(action: action),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(countsProvider(locationId));
            ref.invalidate(countUnitsProvider(locationId));
            await ref
                .read(countsProvider(locationId).future)
                .catchError((_) => const <StockCount>[]);
          },
          child: ListView(
            key: const ValueKey('inv-count-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              action == null
                  ? OmniFabLayer.listBottom(context, hasFab: false)
                  : OmniDockLayer.listBottom(context),
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Một cây khi kiểm: nền chọn mềm + dấu ✓ bên phải, "Hãng Model", serial + lô,
/// tình trạng.
class CountUnitRow extends StatelessWidget {
  const CountUnitRow({
    super.key,
    required this.unit,
    required this.seen,
    this.onTap,
  });

  final InventoryUnit unit;
  final bool seen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unit;
    return Semantics(
      button: onTap != null,
      checked: seen,
      label: 'Thấy ${u.name} ${u.serial ?? ''}',
      excludeSemantics: true,
      child: ColoredBox(
        color: seen ? OmniGlass.selectionOf(context) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          u.name,
                          style: OmniType.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          [
                            u.serial ?? 'chưa có serial',
                            if (u.lotCode != null) u.lotCode!,
                          ].join(' · '),
                          style: invMuted(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    UnitCondition.labelOf(u.condition),
                    style: invMuted(context).copyWith(
                      color: InvUi.conditionColor(context, u.condition),
                    ),
                  ),
                  if (seen) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_rounded, size: 20, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kết quả phiên đã chốt (chờ duyệt) hoặc đã duyệt: thấy / không thấy, cây
/// không thấy, số đếm hàng số lượng (+ chênh lệch khi đã duyệt).
class CountResultSection extends ConsumerWidget {
  const CountResultSection({super.key, required this.count, this.locationRow});

  final StockCount count;
  final Widget? locationRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = count;
    final approved = c.status == CountStatus.approved;
    final danger = OmniColors.dangerTextOf(context);
    final products = c.qty.isEmpty
        ? const <InvProduct>[]
        : ref.watch(qtyProductsProvider).valueOrNull ?? const <InvProduct>[];
    String nameOf(String id) =>
        products.where((p) => p.id == id).firstOrNull?.name ?? id;
    final when = approved ? c.approvedAt : c.submittedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmniGroupSection(
          key: const ValueKey('inv-count-result'),
          children: [
            ?locationRow,
            OmniGroupRow(
              key: const ValueKey('inv-count-status'),
              title: c.status.label,
              value: when == null ? null : InventoryFormat.dmy(when),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-count-seen'),
              title: 'Thấy',
              trailing: InvValue(
                '${InventoryFormat.number(c.seenUnitIds.length)} cây',
              ),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-count-missing'),
              title: 'Không thấy',
              trailing: Text(
                '${InventoryFormat.number(c.missingUnits.length)} cây',
                style: OmniType.bodyStrong.copyWith(
                  color: c.missingUnits.isEmpty
                      ? Theme.of(context).colorScheme.onSurface
                      : danger,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
          ],
        ),
        if (c.missingUnits.isNotEmpty) ...[
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            key: const ValueKey('inv-count-missing-list'),
            title: 'Không thấy',
            children: [
              for (final m in c.missingUnits)
                OmniGroupRow(
                  key: ValueKey('inv-count-miss-${m.unitId}'),
                  title: m.label ?? 'Cây',
                  subtitle: m.serial,
                ),
            ],
          ),
        ],
        if (c.qty.isNotEmpty) ...[
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            title: 'Hàng số lượng',
            children: [
              for (final e in c.qty.entries)
                OmniGroupRow(
                  key: ValueKey('inv-count-res-qty-${e.key}'),
                  title: nameOf(e.key),
                  subtitle: switch (c.qtyDeltas[e.key]) {
                    null || 0 => null,
                    final d => d > 0 ? 'Lệch +$d' : 'Lệch −${-d}',
                  },
                  value: 'đếm ${InventoryFormat.number(e.value)}',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
