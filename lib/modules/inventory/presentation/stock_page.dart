import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_tab_routes.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';
import '../routes.dart';
import 'widgets/inventory_intro.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/sell_sheet.dart';
import 'widgets/serial_field.dart';
import 'widgets/unit_extras.dart';
import 'widgets/unit_sheet.dart';
import 'widgets/workshop_target.dart';

/// Tồn kho theo serial (rà soát app mobile 12/11, `#s-ton-kho`): một nút ⋯
/// trên thanh, ô tìm + nút lọc (sheet Loại · Lô · Tuổi tồn · Vị trí), dải 3 số
/// (số cây · niêm yết · tồn > 90 ngày), Còn bán / Đã có khách, danh sách nhóm
/// theo loại, serial chạm để sửa, "Chọn" ở đầu danh sách để Bán / Đặt trước,
/// Đưa vào xưởng hoặc Chuyển vị trí từ khay kính đáy.
///
/// Kho chuẩn hóa Đợt A: lọc theo vị trí và chuyển nhiều cây CHỈ khi tenant có
/// từ hai vị trí (`multi_location`); ảnh đại diện nhỏ đầu dòng khi API có ảnh.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  bool _multi = false;
  final _picked = <String>{};

  /// Đang đưa cây vào xưởng (chờ danh sách kế hoạch / API) — chặn bấm lặp.
  bool _sending = false;

  StateController<StockFilter> get _filter =>
      ref.read(stockFilterProvider.notifier);

  void _setSegment(StockSegment s) {
    _filter.update((f) => f.copyWith(segment: s));
    setState(() {
      _multi = false;
      _picked.clear();
    });
  }

  Future<void> _pickCategory(List<String> options) async {
    final f = ref.read(stockFilterProvider);
    final r = await showInvOptions<String>(
      context: context,
      title: 'Loại',
      options: [for (final c in options) (c, c)],
      selected: f.category,
      allLabel: 'Tất cả',
    );
    if (r != null) _filter.update((f) => f.copyWith(category: () => r.value));
  }

  Future<void> _pickLot() async {
    // Giữ provider tự huỷ sống trong lúc chờ (đọc `.future` trần thì nó bị
    // huỷ giữa chừng).
    final sub = ref.listenManual(lotsProvider, (_, _) {});
    final lots = await ref.read(lotsProvider.future).catchError((_) => <Lot>[]);
    sub.close();
    if (!mounted) return;
    final f = ref.read(stockFilterProvider);
    final r = await showInvOptions<String>(
      context: context,
      title: 'Lô',
      options: [
        for (final l in lots)
          if (l.inStock > 0 || l.status == LotStatus.received) (l.id, l.code),
      ],
      selected: f.lotId,
      allLabel: 'Tất cả',
    );
    if (r == null) return;
    final code = lots.where((l) => l.id == r.value).firstOrNull?.code;
    _filter.update(
      (f) => f.copyWith(lotId: () => r.value, lotCode: () => code),
    );
  }

  Future<void> _pickLocation() async {
    final sub = ref.listenManual(locationsProvider, (_, _) {});
    final locations = await ref
        .read(locationsProvider.future)
        .catchError((_) => <StockLocation>[]);
    sub.close();
    if (!mounted) return;
    final f = ref.read(stockFilterProvider);
    final r = await showInvOptions<String>(
      context: context,
      title: 'Vị trí',
      options: [for (final l in locations) (l.id, l.name)],
      selected: f.locationId,
      allLabel: 'Mọi vị trí',
    );
    if (r == null) return;
    final name = locations.where((l) => l.id == r.value).firstOrNull?.name;
    _filter.update(
      (f) => f.copyWith(locationId: () => r.value, locationName: () => name),
    );
  }

  /// Chuyển các cây đã chọn sang một vị trí (`POST /units/move`).
  Future<void> _movePicked(List<InventoryUnit> items) async {
    final ids = [
      for (final u in items)
        if (_picked.contains(u.id)) u.id,
    ];
    if (ids.isEmpty || _sending) return;
    final sub = ref.listenManual(locationsProvider, (_, _) {});
    final locations = await ref
        .read(locationsProvider.future)
        .catchError((_) => <StockLocation>[]);
    sub.close();
    if (!mounted || locations.isEmpty) return;
    final to = await showOmniSheet<StockLocation>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(title: 'Chuyển ${ids.length} cây đến'),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              for (final l in locations)
                OmniGroupRow(
                  key: ValueKey('inv-move-to-${l.id}'),
                  title: l.name,
                  value: '${InventoryFormat.number(l.unitCount)} cây',
                  chevron: false,
                  onTap: () => Navigator.of(sheet).pop(l),
                ),
            ],
          ),
        ],
      ),
    );
    if (to == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final res = await ref
          .read(inventoryApiProvider)
          .moveUnits(unitIds: ids, toLocationId: to.id);
      if (!mounted) return;
      bumpInventory(ref);
      setState(() {
        _multi = false;
        _picked.clear();
      });
      InvUi.toast(
        context,
        res.skipped > 0
            ? 'Đã chuyển ${res.moved} cây đến ${to.name}, bỏ qua ${res.skipped} cây.'
            : 'Đã chuyển ${res.moved} cây đến ${to.name}.',
      );
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAge() async {
    final f = ref.read(stockFilterProvider);
    final r = await showInvOptions<AgeBucket>(
      context: context,
      title: 'Tuổi tồn',
      options: [for (final a in AgeBucket.values) (a, a.label)],
      selected: f.age,
      allLabel: 'Tất cả',
    );
    if (r != null) _filter.update((f) => f.copyWith(age: () => r.value));
  }

  Future<void> _saveSerial(InventoryUnit u, String? serial) async {
    try {
      final res = await ref.read(inventoryApiProvider).updateUnit(u.id, {
        'serial': serial,
      });
      ref.read(stockProvider.notifier).patch([res.unit]);
      if (!mounted) return;
      final taken = res.warnings.any((w) => w.code == 'serial_taken');
      InvUi.toast(
        context,
        taken
            ? 'Serial $serial trùng một cây ${u.maker} khác · đã lưu'
            : serial == null
            ? 'Đã xoá serial.'
            : 'Đã lưu serial $serial.',
      );
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    }
  }

  void _tapUnit(InventoryUnit u) {
    if (_multi) {
      setState(
        () => _picked.contains(u.id) ? _picked.remove(u.id) : _picked.add(u.id),
      );
      return;
    }
    openUnitSheet(
      context,
      unit: u,
      onChanged: (c) => ref.read(stockProvider.notifier).patch([c]),
    );
  }

  Future<void> _sellPicked(List<InventoryUnit> items) async {
    final units = [
      for (final u in items)
        if (_picked.contains(u.id)) u,
    ];
    if (units.isEmpty) return;
    final done = await openSellSheet(context, units: units);
    if (done && mounted) {
      setState(() {
        _multi = false;
        _picked.clear();
      });
    }
  }

  /// Đưa các cây đã chọn vào xưởng: chọn kế hoạch rồi `POST /tasks/from-units`.
  /// Cây đang có việc tân trang chưa xong không gửi (server cũng bỏ qua).
  Future<void> _sendPicked(List<InventoryUnit> items) async {
    final ids = [
      for (final u in items)
        if (_picked.contains(u.id) && !u.hasOpenRefurbish) u.id,
    ];
    if (ids.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final target = await pickWorkshopTarget(context, ref);
      if (target == null || !mounted) return;
      final res = await ref
          .read(inventoryApiProvider)
          .sendToWorkshop(
            projectId: target.planId,
            sectionId: target.sectionId,
            unitIds: ids,
          );
      if (!mounted) return;
      bumpInventory(ref);
      setState(() {
        _multi = false;
        _picked.clear();
      });
      InvUi.toast(context, sendToWorkshopMessage(res));
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Menu ⋯ duy nhất trên thanh (rà soát 12/11): Hàng sắp về, Đang giữ, Danh
  /// mục hàng, Kiểm kê, Hàng đã giao (theo capability), Giới thiệu Kho.
  ///
  /// Module không được import tầng `app/` nên không biết đang ở khung ứng dụng
  /// hay giao diện cũ — gộp còn một nút cho cả hai chế độ.
  Future<void> _openMore(BuildContext btn, InventoryPerms perms) async {
    final box = btn.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final route = await showOmniAnchoredMenu<String>(
      context: context,
      anchor: anchor,
      menuKey: const ValueKey('inv-more-menu'),
      semanticsLabel: 'Thêm',
      builder: (menu) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniAnchoredMenuItem(
            key: const ValueKey('inv-open-lots'),
            icon: Icons.local_shipping_outlined,
            label: 'Hàng sắp về',
            onTap: () => Navigator.of(menu).pop(InventoryRoutes.lots),
          ),
          // Kho chuẩn hóa Đợt B — chỉ khi API có capability.
          if (perms.reservations)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-reservations'),
              icon: Icons.bookmark_border_rounded,
              label: 'Đang giữ',
              divider: true,
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.reservations),
            ),
          if (perms.products)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-catalog'),
              icon: Icons.category_outlined,
              label: 'Danh mục hàng',
              divider: true,
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.catalog),
            ),
          // Kho chuẩn hóa Đợt C.
          if (perms.counts)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-counts'),
              icon: Icons.fact_check_outlined,
              label: 'Kiểm kê',
              divider: true,
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.counts),
            ),
          if (perms.delivered)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-delivered'),
              icon: Icons.assignment_turned_in_outlined,
              label: 'Hàng đã giao',
              divider: true,
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.delivered),
            ),
          OmniAnchoredMenuItem(
            key: const ValueKey('inv-open-intro'),
            icon: Icons.lightbulb_outline_rounded,
            label: 'Giới thiệu Kho',
            divider: true,
            onTap: () => Navigator.of(menu).pop(_introRoute),
          ),
        ],
      ),
    );
    if (route == null || !mounted) return;
    if (route == _introRoute) {
      await showInventoryIntro(context);
      return;
    }
    context.pushNamed(route);
  }

  static const _introRoute = '_intro';

  /// Sheet lọc: Loại, Lô, Tuổi tồn, Vị trí (khi có từ hai vị trí). Chạm một
  /// dòng thì đóng sheet rồi mở danh sách chọn của dòng đó.
  Future<void> _openFilters(List<String> categories, bool multi) async {
    final f = ref.read(stockFilterProvider);
    final pick = await showOmniSheet<String>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Lọc',
          trailing: _activeFilters(f) > 0
              ? TextButton(
                  key: const ValueKey('inv-filter-clear'),
                  onPressed: () => Navigator.of(sheet).pop('clear'),
                  child: const Text('Bỏ lọc'),
                )
              : null,
        ),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-filter-category'),
                title: 'Loại',
                value: f.category ?? 'Tất cả',
                onTap: () => Navigator.of(sheet).pop('category'),
              ),
              OmniGroupRow(
                key: const ValueKey('inv-filter-lot'),
                title: 'Lô',
                value: f.lotCode ?? 'Tất cả',
                onTap: () => Navigator.of(sheet).pop('lot'),
              ),
              OmniGroupRow(
                key: const ValueKey('inv-filter-age'),
                title: 'Tuổi tồn',
                value: f.age?.label ?? 'Tất cả',
                onTap: () => Navigator.of(sheet).pop('age'),
              ),
              if (multi)
                OmniGroupRow(
                  key: const ValueKey('inv-filter-location'),
                  title: 'Vị trí',
                  value: f.locationName ?? 'Mọi vị trí',
                  onTap: () => Navigator.of(sheet).pop('location'),
                ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (pick) {
      case 'category':
        await _pickCategory(categories);
      case 'lot':
        await _pickLot();
      case 'age':
        await _pickAge();
      case 'location':
        await _pickLocation();
      case 'clear':
        _filter.update(
          (f) => f.copyWith(
            category: () => null,
            lotId: () => null,
            lotCode: () => null,
            age: () => null,
            locationId: () => null,
            locationName: () => null,
          ),
        );
    }
  }

  static int _activeFilters(StockFilter f) =>
      [f.category, f.lotId, f.age, f.locationId].where((x) => x != null).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowInventoryIntro(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    if (!perms.read) {
      return const Scaffold(
        appBar: OmniAppBar(title: 'Tồn kho'),
        body: OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chưa có quyền xem kho',
        ),
      );
    }
    // Bộ lọc đổi thì danh sách đổi: bỏ các cây đã chọn ở danh sách cũ.
    ref.listen(stockFilterProvider, (_, _) {
      if (_picked.isNotEmpty) setState(_picked.clear);
    });
    final f = ref.watch(stockFilterProvider);
    final stock = ref.watch(stockProvider);
    final today = ref.watch(inventoryTodayProvider);
    final nFree = ref
        .watch(stockCountProvider(StockSegment.available))
        .valueOrNull;
    final nHeld = ref
        .watch(stockCountProvider(StockSegment.reserved))
        .valueOrNull;
    // Tab "Không thấy" (`inventory.found`): cây kiểm kê không thấy.
    final nMissing = perms.missing
        ? ref.watch(stockCountProvider(StockSegment.missing)).valueOrNull
        : null;
    // Ba đoạn ở bề ngang 390: "Đã có khách 251" bị cắt — rút gọn.
    final heldLabel = perms.missing ? 'Có khách' : 'Đã có khách';
    final segments = [
      ('Còn bán', StockSegment.available, nFree),
      (heldLabel, StockSegment.reserved, nHeld),
      if (perms.missing) ('Không thấy', StockSegment.missing, nMissing),
    ];
    final segIndex = segments
        .indexWhere((s) => s.$2 == f.segment)
        .clamp(0, segments.length - 1);
    final reserved = f.segment == StockSegment.reserved;
    final lost = f.segment == StockSegment.missing;
    // Đợt A: lọc / chuyển vị trí chỉ khi có từ hai vị trí (spec §5).
    final multi = ref.watch(multiLocationProvider).valueOrNull ?? false;
    final defaultLocation = multi
        ? ref
              .watch(locationsProvider)
              .valueOrNull
              ?.where((l) => l.isDefault)
              .firstOrNull
              ?.id
        : null;

    final state = stock.valueOrNull;
    final loaded = state?.items ?? const <InventoryUnit>[];
    final items = f.age == null
        ? loaded
        : [
            for (final u in loaded)
              if (f.age!.matches(InventoryFormat.ageDays(u.receivedAt, today)))
                u,
          ];
    final pickedLoaded = loaded.where((u) => _picked.contains(u.id)).length;
    // Cây đã chọn chưa có việc tân trang đang mở — số cây sẽ vào xưởng.
    final pickedForWorkshop = loaded
        .where((u) => _picked.contains(u.id) && !u.hasOpenRefurbish)
        .length;
    final categories = {
      ...loaded.map((u) => u.category).whereType<String>(),
      ?f.category,
    }.toList()..sort();
    // Cây "Không thấy" chỉ để xem và tìm thấy từng cây — không chọn nhiều.
    final canSell = !reserved && !lost && perms.canSellOrReserve;
    final canSend = !lost && perms.workshop;
    final canMove = !lost && multi && perms.write;
    final canMulti = canSell || canSend || canMove;
    final showSell = _multi && canSell && pickedLoaded > 0;
    final showSend = _multi && canSend && pickedForWorkshop > 0;
    final showMove = _multi && canMove && pickedLoaded > 0;

    final allLoaded = state != null && !state.hasMore;
    final count = f.age != null && allLoaded
        ? items.length
        : (state?.total ?? 0);
    final sumPrice = items.fold<double>(0, (s, u) => s + (u.listPrice ?? 0));
    final sumCost = items.fold<double>(0, (s, u) => s + (u.costVnd ?? 0));
    final old = items.where((u) {
      final d = InventoryFormat.ageDays(u.receivedAt, today);
      return d != null && d > StockUnitRow.oldDays;
    }).length;

    // Khay đáy: nút chính là Bán (rồi Xưởng, rồi Chuyển vị trí); nút còn lại
    // xếp trên hàng chính.
    final moveBtn = showMove
        ? _DockButton(
            key: const ValueKey('inv-stock-move-picked'),
            label: 'Chuyển vị trí · $pickedLoaded cây',
            onPressed: _sending ? null : () => _movePicked(loaded),
          )
        : null;
    final sendBtn = showSend
        ? _DockButton(
            key: const ValueKey('inv-stock-send-picked'),
            label: 'Đưa vào xưởng · $pickedForWorkshop cây',
            onPressed: _sending ? null : () => _sendPicked(loaded),
          )
        : null;
    final sellBtn = showSell
        ? _DockButton(
            key: const ValueKey('inv-stock-sell-picked'),
            label: 'Bán / Đặt trước · $pickedLoaded cây',
            onPressed: () => _sellPicked(loaded),
          )
        : null;
    final dockButtons = [?moveBtn, ?sendBtn, ?sellBtn];
    final dock = dockButtons.isEmpty
        ? null
        : OmniBottomDock(
            key: const ValueKey('inv-stock-dock'),
            // Không dòng tóm tắt: nhãn nút đã mang số cây ("Bán / Đặt trước ·
            // 2 cây") — nút trải hết khay, chữ không gãy dòng (soát 12/11).
            action: OmniTintedButtons(child: dockButtons.last.filled()),
            extra: [
              for (final b in dockButtons.take(dockButtons.length - 1))
                OmniTintedButtons(child: b.outlined()),
            ],
          );

    // Nhóm theo loại khi dữ liệu có loại; cây không có loại vào "Khác".
    final grouped = items.any((u) => u.category != null);
    final groups = <String?, List<InventoryUnit>>{};
    for (final u in items) {
      (groups[grouped ? (u.category ?? 'Khác') : null] ??= []).add(u);
    }

    final pickToggle = canMulti
        ? TextButton(
            key: const ValueKey('inv-stock-multi'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() {
              _multi = !_multi;
              _picked.clear();
            }),
            child: Text(_multi ? 'Xong' : 'Chọn'),
          )
        : null;

    Widget row(InventoryUnit u) => StockUnitRow(
      key: ValueKey('inv-unit-${u.id}'),
      unit: u,
      today: today,
      showCustomer: reserved,
      showCategory: !grouped,
      canEditSerial: perms.write && !_multi,
      picking: _multi,
      showWorkshop: _multi && canSend,
      // Lúc chọn nhiều thì bỏ ảnh: chừa chỗ cho ô chọn và chữ.
      thumb: perms.photos && !_multi,
      // Cây ở nơi khác vị trí mặc định thì ghi nơi đó; lúc chọn để chuyển thì
      // ghi cho mọi cây.
      location: multi && (_multi && canMove || u.locationId != defaultLocation)
          ? u.locationName
          : null,
      picked: _picked.contains(u.id),
      onTap: () => _tapUnit(u),
      onSerial: (s) => _saveSerial(u, s),
    );

    final scheme = Theme.of(context).colorScheme;
    final builders = <Widget Function()>[
      () => _StatStrip(
        key: const ValueKey('inv-stock-summary'),
        countLabel: segments[segIndex].$1,
        countValue: '${InventoryFormat.number(count)} cây',
        // Tổng tiền chỉ khi đã tải hết — cộng một trang là số sai.
        priceValue: allLoaded ? InvUi.vnd(sumPrice) : '—',
        oldValue: allLoaded ? '${InventoryFormat.number(old)} cây' : '—',
        oldWarning: allLoaded && old > 0,
        activeAge: f.age != null,
        onPickAge: _pickAge,
        cost: perms.cost && allLoaded ? InvUi.vnd(sumCost) : null,
      ),
      () => const SizedBox(height: OmniGroupSection.gap),
      () => OmniSegmented(
        labels: [
          for (final (label, _, n) in segments)
            n == null ? label : '$label ${InventoryFormat.number(n)}',
        ],
        index: segIndex,
        onChanged: (i) => _setSegment(segments[i].$2),
      ),
      () => const SizedBox(height: OmniGroupSection.gap),
      ...switch (stock) {
        AsyncValue(:final error?) when state == null => [
          () => OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(stockProvider),
          ),
        ],
        _ when state == null => [() => const InvSkeleton(count: 6, height: 64)],
        _ when items.isEmpty => [
          () => OmniGroupSection(
            trailingTitle: _multi ? pickToggle : null,
            children: const [OmniGroupRow(title: 'Không có cây khớp')],
          ),
        ],
        _ => [
          for (final (groupIdx, e) in groups.entries.indexed) ...[
            if (groupIdx > 0) () => const SizedBox(height: OmniGroupSection.gap),
            if (e.key != null || (groupIdx == 0 && pickToggle != null))
              () => Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          e.key == null
                              ? ''
                              : '${e.key} · ${InventoryFormat.number(e.value.length)} cây',
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (groupIdx == 0) ?pickToggle,
                  ],
                ),
              ),
            for (var idx = 0; idx < e.value.length; idx++)
              () {
                final u = e.value[idx];
                final len = e.value.length;
                return Material(
                  key: groupIdx == 0 && idx == 0
                      ? const ValueKey('inv-stock-list')
                      : null,
                  color: scheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: idx == 0 ? const Radius.circular(18) : Radius.zero,
                    bottom: idx == len - 1
                        ? const Radius.circular(18)
                        : Radius.zero,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: OmniTintedButtons(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (idx > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 54,
                            color: scheme.outlineVariant.withValues(alpha: .7),
                          ),
                        row(u),
                      ],
                    ),
                  ),
                );
              },
          ],
          if (state.loadingMore)
            () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
        ],
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: OmniAppBar(
        title: 'Tồn kho',
        actions: [
          // Khung ứng dụng: mọi màn của Kho đã ở thanh dưới / "Thêm" — header
          // chỉ còn tên + chuông + avatar (rà soát 12/11). Giao diện cũ: một ⋯.
          if (ShellTabRoutes.of(context).isEmpty)
            Builder(
              builder: (btn) => IconButton(
                key: const ValueKey('inv-open-more'),
                tooltip: 'Thêm',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                onPressed: () => _openMore(btn, perms),
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: OmniIconSize.md,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
        ],
        bottom: _SearchBottom(
          hint: 'Tìm serial, model',
          onChanged: (v) => _filter.update((f) => f.copyWith(query: v)),
          activeFilters: _activeFilters(f),
          onFilter: () => _openFilters(categories, multi),
        ),
      ),
      body: OmniDockLayer(
        dock: dock,
        body: OmniTopBarOverlap.wrap(
          child: Builder(
            builder: (context) {
              final topInset = OmniTopBarOverlap.of(context);
              return NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 400) {
                    ref.read(stockProvider.notifier).loadMore().ignore();
                  }
                  return false;
                },
                child: RefreshIndicator(
                  edgeOffset: topInset,
                  onRefresh: () => ref.read(stockProvider.notifier).refresh(),
                  child: ListView.builder(
                    key: const ValueKey('inv-stock-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topInset + 4,
                      16,
                      dock == null
                          ? OmniFabLayer.listBottom(context, hasFab: false)
                          : OmniDockLayer.listBottom(
                              context,
                              rows: dockButtons.length,
                            ),
                    ),
                    itemCount: builders.length,
                    itemBuilder: (_, index) => builders[index](),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Một nút của khay đáy: nút chính tô (FilledButton), nút phụ viền.
class _DockButton {
  const _DockButton({
    required this.key,
    required this.label,
    required this.onPressed,
  });

  final Key key;
  final String label;
  final VoidCallback? onPressed;

  Widget filled() =>
      FilledButton(key: key, onPressed: onPressed, child: Text(label));

  Widget outlined() =>
      OutlinedButton(key: key, onPressed: onPressed, child: Text(label));
}

/// Thẻ tóm tắt tồn kho phẳng kiểu Hero dòng nhãn — số: hiển thị trọn chữ số
/// (`tabularFigures`, không `FittedBox`), giá vốn (khi có quyền) và dòng lọc
/// nhanh tồn lâu.
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    super.key,
    required this.countLabel,
    required this.countValue,
    required this.priceValue,
    required this.oldValue,
    required this.oldWarning,
    required this.activeAge,
    required this.onPickAge,
    this.cost,
  });

  final String countLabel;
  final String countValue;
  final String priceValue;
  final String oldValue;
  final bool oldWarning;
  final bool activeAge;
  final VoidCallback onPickAge;
  final String? cost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oldColor = activeAge
        ? scheme.primary
        : oldWarning
        ? OmniColors.warningTextOf(context)
        : scheme.onSurface;
    return OmniGroupSection(
      dividerIndent: 14,
      children: [
        OmniGroupRow(title: countLabel, trailing: InvValue(countValue)),
        OmniGroupRow(title: 'Niêm yết', trailing: InvValue(priceValue)),
        if (cost != null) OmniGroupRow(title: 'Vốn', trailing: InvValue(cost!)),
        OmniGroupRow(
          title: 'Tồn lâu (> ${StockUnitRow.oldDays} ngày)',
          chevron: true,
          onTap: onPickAge,
          trailing: Text(
            oldValue,
            style: OmniType.bodyStrong.copyWith(
              color: oldColor,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

/// Một cây trong danh sách tồn: tên model, dòng phụ serial · lô · tuổi tồn
/// (cam khi quá [oldDays] ngày), khách (phân đoạn Đã có khách); bên phải giá
/// niêm yết đủ số, tình trạng và vị trí. Chế độ chọn nhiều tô nền chọn mềm
/// kèm dấu ✓ cuối dòng thay vì vòng tròn radio ở đầu.
class StockUnitRow extends StatelessWidget {
  const StockUnitRow({
    super.key,
    required this.unit,
    required this.today,
    required this.onTap,
    required this.onSerial,
    this.showCustomer = false,
    this.showCategory = true,
    this.canEditSerial = false,
    this.picking = false,
    this.picked = false,
    this.showWorkshop = false,
    this.thumb = false,
    this.location,
  });

  /// Quá số ngày này thì tuổi tồn đổi màu cam ("Tồn > 90 ngày").
  static const oldDays = 90;

  final InventoryUnit unit;
  final DateTime today;
  final VoidCallback onTap;
  final Future<void> Function(String? serial) onSerial;
  final bool showCustomer;

  /// Loại ở dòng phụ — tắt khi danh sách đã nhóm theo loại.
  final bool showCategory;
  final bool canEditSerial;
  final bool picking;
  final bool picked;

  /// Đang chọn cây để đưa vào xưởng: dòng nhỏ bên phải là tình hình xưởng
  /// (`8/10`, "Xong", "Chưa vào xưởng"), tình trạng dời sang dòng phụ.
  final bool showWorkshop;

  /// Ảnh đại diện nhỏ đầu dòng (API có ảnh — Đợt A).
  final bool thumb;

  /// Tên vị trí ghi bên phải dưới giá (chỉ khi có từ hai vị trí).
  final String? location;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unit;
    final age = InventoryFormat.ageDays(u.receivedAt, today);
    final hold = showCustomer ? InvUi.holdLine(u) : null;
    final work = showWorkshop ? u.workshopLabel : null;
    final category = showCategory ? InvUi.shortCategory(u.category) : '';
    final muted = invMuted(context);
    final selected = picking && picked;
    return Semantics(
      button: true,
      selected: selected,
      child: ColoredBox(
        color: selected ? OmniGlass.selectionOf(context) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  if (thumb) ...[
                    InvUnitThumb(unit: u),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          u.name,
                          maxLines: 2,
                          style: OmniType.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        // Wrap, không Row: serial dài + lô + loại + tuổi tồn
                        // không vừa một dòng ở 390 thì xuống dòng, không tràn.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SerialField(
                              serial: u.serial,
                              editable: canEditSerial,
                              semanticsName: u.name,
                              onSave: onSerial,
                            ),
                            Text(' · ', style: muted),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 0),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: [
                                        if (work != null)
                                          UnitCondition.labelOf(u.condition),
                                        if (u.lotCode != null) u.lotCode!,
                                        if (category.isNotEmpty) category,
                                        '',
                                      ].join(' · '),
                                    ),
                                    TextSpan(
                                      text: age == null
                                          ? 'chưa có ngày'
                                          : '$age ngày',
                                      style: age != null && age > oldDays
                                          ? TextStyle(
                                              color: OmniColors.warningTextOf(
                                                context,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                style: muted,
                              ),
                            ),
                          ],
                        ),
                        if (hold != null)
                          Text(
                            hold,
                            style: OmniType.caption.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InvValue(
                        InvUi.vnd(u.listPrice),
                        sub: work ?? UnitCondition.labelOf(u.condition),
                        subColor: work != null
                            ? null
                            : InvUi.conditionColor(context, u.condition),
                      ),
                      if (location != null)
                        Text(location!, maxLines: 1, style: muted),
                    ],
                  ),
                  if (selected) ...[
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

/// Ô tìm viên kính trên thanh + nút lọc mặt kính tròn (chấm số bộ lọc đang bật).
class _SearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBottom({
    required this.hint,
    required this.onChanged,
    required this.activeFilters,
    required this.onFilter,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final int activeFilters;
  final VoidCallback onFilter;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Row(
          children: [
            Expanded(
              child: OmniGlass(
                radius: 22,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: OmniSearchField(
                    key: const ValueKey('inv-search'),
                    hint: hint,
                    flat: true,
                    dense: true,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OmniGlassCircle(
              child: IconButton(
                key: const ValueKey('inv-filter'),
                tooltip: activeFilters > 0
                    ? 'Lọc · đang bật $activeFilters'
                    : 'Lọc',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                onPressed: onFilter,
                icon: Badge(
                  isLabelVisible: activeFilters > 0,
                  label: Text('$activeFilters'),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                  child: Icon(
                    Icons.tune_rounded,
                    size: OmniIconSize.md,
                    color: activeFilters > 0
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
