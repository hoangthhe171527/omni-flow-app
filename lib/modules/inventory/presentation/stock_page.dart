import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';
import '../routes.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/sell_sheet.dart';
import 'widgets/serial_field.dart';
import 'widgets/unit_extras.dart';
import 'widgets/unit_sheet.dart';

/// Tồn kho theo serial (artifact app bản 7): tìm serial / model, Còn bán / Đã
/// có khách, hàng lọc một dòng thả xuống (Loại · Lô · Tuổi tồn), dòng tổng
/// ngắn, serial chạm để sửa, chọn nhiều cây để Bán / Đặt trước hoặc Đưa vào
/// xưởng (Kho nối Xưởng: mỗi cây một việc của kế hoạch được chọn).
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

  /// Lần tự tải thêm (khi lọc tuổi tồn) vừa lỗi — không thử lại liên tục.
  bool _autoLoadFailed = false;

  StateController<StockFilter> get _filter =>
      ref.read(stockFilterProvider.notifier);

  void _setSegment(int i) {
    _filter.update(
      (f) => f.copyWith(
        segment: i == 0 ? StockSegment.available : StockSegment.reserved,
      ),
    );
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
      // Giữ provider tự huỷ sống trong lúc chờ (như `_pickLot`).
      final sub = ref.listenManual(workshopPlansProvider, (_, _) {});
      final List<WorkshopPlan> plans;
      try {
        plans = await ref.read(workshopPlansProvider.future);
      } finally {
        sub.close();
      }
      if (!mounted) return;
      if (plans.isEmpty) {
        InvUi.toast(
          context,
          'Chưa có kế hoạch đang chạy nào bạn quản lý được.',
        );
        return;
      }
      final r = await showInvOptions<String>(
        context: context,
        title: 'Chọn kế hoạch',
        options: [for (final p in plans) (p.id, p.name)],
      );
      final planId = r?.value;
      if (planId == null || !mounted) return;
      final res = await ref
          .read(inventoryApiProvider)
          .sendToWorkshop(projectId: planId, unitIds: ids);
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

  /// Menu ⋯ trên thanh: Kiểm kê, Hàng đã giao (Đợt C, theo capability).
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
          if (perms.counts)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-counts'),
              icon: Icons.fact_check_outlined,
              label: 'Kiểm kê',
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.counts),
            ),
          if (perms.delivered)
            OmniAnchoredMenuItem(
              key: const ValueKey('inv-open-delivered'),
              icon: Icons.assignment_turned_in_outlined,
              label: 'Hàng đã giao',
              divider: perms.counts,
              onTap: () => Navigator.of(menu).pop(InventoryRoutes.delivered),
            ),
        ],
      ),
    );
    if (route != null && mounted) context.pushNamed(route);
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
      _autoLoadFailed = false;
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
    final reserved = f.segment == StockSegment.reserved;
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
    // Tuổi tồn lọc trên máy: phải tải hết các trang, không thì cây khớp ở
    // trang chưa tải bị coi như không có.
    if (f.age != null &&
        state != null &&
        state.hasMore &&
        !state.loadingMore &&
        !_autoLoadFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(stockProvider.notifier).loadMore().catchError((Object _) {
          _autoLoadFailed = true;
        });
      });
    }
    final pickedLoaded = loaded.where((u) => _picked.contains(u.id)).length;
    // Cây đã chọn chưa có việc tân trang đang mở — số cây sẽ vào xưởng.
    final pickedForWorkshop = loaded
        .where((u) => _picked.contains(u.id) && !u.hasOpenRefurbish)
        .length;
    final categories = {
      ...loaded.map((u) => u.category).whereType<String>(),
      ?f.category,
    }.toList()..sort();
    final canSell = !reserved && perms.canSellOrReserve;
    final canSend = perms.workshop;
    final canMove = multi && perms.write;
    final canMulti = canSell || canSend || canMove;
    final showSell = _multi && canSell && pickedLoaded > 0;
    final showSend = _multi && canSend && pickedForWorkshop > 0;
    final showMove = _multi && canMove && pickedLoaded > 0;
    // Chỉ có chuyển vị trí: nút ở vùng ngón cái (bản xem trước). Có thêm
    // Bán / Xưởng thì chuyển vị trí là một dòng ngay dưới "Đã chọn" — không
    // xếp ba nút chồng nhau che danh sách.
    final moveInBar = showMove && !showSend && !showSell;
    final actions = [moveInBar, showSend, showSell].where((x) => x).length;
    final bottomPad =
        ShellBarInset.of(context) + MediaQuery.viewPaddingOf(context).bottom;

    final allLoaded = state != null && !state.hasMore;
    final count = f.age != null && allLoaded
        ? items.length
        : (state?.total ?? 0);
    final sumPrice = items.fold<double>(0, (s, u) => s + (u.listPrice ?? 0));
    final sumCost = items.fold<double>(0, (s, u) => s + (u.costVnd ?? 0));

    final list = <Widget>[
      OmniSegmented(
        labels: [
          nFree == null
              ? 'Còn bán'
              : 'Còn bán ${InventoryFormat.number(nFree)}',
          nHeld == null
              ? 'Đã có khách'
              : 'Đã có khách ${InventoryFormat.number(nHeld)}',
        ],
        index: reserved ? 1 : 0,
        onChanged: _setSegment,
      ),
      const SizedBox(height: 10),
      _FilterRow(
        // Bốn ô (có Vị trí) không đủ chỗ chia đều 390px: cuộn ngang, mỗi ô
        // vừa chữ — không xuống dòng.
        scroll: multi,
        pills: [
          InvDropPill(
            key: const ValueKey('inv-filter-category'),
            label: f.category ?? 'Loại',
            active: f.category != null,
            shrink: multi,
            onTap: () => _pickCategory(categories),
          ),
          InvDropPill(
            key: const ValueKey('inv-filter-lot'),
            label: f.lotCode ?? 'Lô',
            active: f.lotId != null,
            shrink: multi,
            onTap: _pickLot,
          ),
          InvDropPill(
            key: const ValueKey('inv-filter-age'),
            label: f.age?.label ?? 'Tuổi tồn',
            active: f.age != null,
            shrink: multi,
            onTap: _pickAge,
          ),
          if (multi)
            InvDropPill(
              key: const ValueKey('inv-filter-location'),
              label: f.locationName ?? 'Vị trí',
              active: f.locationId != null,
              shrink: true,
              onTap: _pickLocation,
            ),
        ],
      ),
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        key: const ValueKey('inv-stock-summary'),
        children: [
          OmniGroupRow(
            title: '${InventoryFormat.number(count)} cây',
            // Tổng tiền chỉ khi đã tải hết — cộng một trang là số sai.
            trailing: allLoaded
                ? InvValue(InvUi.vnd(sumPrice), sub: 'niêm yết')
                : null,
          ),
          if (perms.cost && allLoaded)
            OmniGroupRow(title: 'Vốn', trailing: InvValue(InvUi.vnd(sumCost))),
          if (canMulti)
            OmniGroupRow(
              key: const ValueKey('inv-stock-multi'),
              icon: Icons.checklist_rounded,
              title: _multi
                  ? 'Đã chọn ${_picked.length} cây'
                  : 'Chọn nhiều cây',
              value: _multi ? 'Xong' : null,
              chevron: false,
              onTap: () => setState(() {
                _multi = !_multi;
                _picked.clear();
              }),
            ),
          if (showMove && !moveInBar)
            OmniGroupRow(
              key: const ValueKey('inv-stock-move-picked'),
              icon: Icons.swap_horiz_rounded,
              accent: true,
              title: 'Chuyển vị trí · $pickedLoaded cây',
              onTap: _sending ? null : () => _movePicked(loaded),
            ),
        ],
      ),
      const SizedBox(height: OmniGroupSection.gap),
      ...switch (stock) {
        AsyncValue(:final error?) when state == null => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(stockProvider),
          ),
        ],
        _ when state == null => [const InvSkeleton(count: 6, height: 64)],
        _ when items.isEmpty => [
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có cây khớp')],
          ),
        ],
        _ => [
          OmniGroupSection(
            key: const ValueKey('inv-stock-list'),
            children: [
              for (final u in items)
                StockUnitRow(
                  key: ValueKey('inv-unit-${u.id}'),
                  unit: u,
                  today: today,
                  showCustomer: reserved,
                  canEditSerial: perms.write && !_multi,
                  picking: _multi,
                  showWorkshop: _multi && canSend,
                  // Lúc chọn nhiều thì bỏ ảnh: chừa chỗ cho ô chọn và chữ.
                  thumb: perms.photos && !_multi,
                  // Cây ở nơi khác vị trí mặc định thì ghi nơi đó; lúc chọn
                  // để chuyển thì ghi cho mọi cây.
                  location:
                      multi &&
                          (_multi && canMove || u.locationId != defaultLocation)
                      ? u.locationName
                      : null,
                  picked: _picked.contains(u.id),
                  onTap: () => _tapUnit(u),
                  onSerial: (s) => _saveSerial(u, s),
                ),
            ],
          ),
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
        ],
      },
    ];

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Tồn kho',
        actions: [
          // Kho chuẩn hóa Đợt B — chỉ khi API có capability.
          if (perms.reservations)
            _BarIcon(
              key: const ValueKey('inv-open-reservations'),
              tooltip: 'Đang giữ',
              icon: Icons.bookmark_border_rounded,
              onPressed: () => context.pushNamed(InventoryRoutes.reservations),
            ),
          if (perms.products)
            _BarIcon(
              key: const ValueKey('inv-open-catalog'),
              tooltip: 'Danh mục hàng',
              icon: Icons.category_outlined,
              onPressed: () => context.pushNamed(InventoryRoutes.catalog),
            ),
          // Kho chuẩn hóa Đợt C — Kiểm kê, Hàng đã giao trong menu ⋯ (thanh
          // tiêu đề không đủ chỗ cho thêm hai nút).
          if (perms.counts || perms.delivered)
            Builder(
              builder: (btn) => _BarIcon(
                key: const ValueKey('inv-open-more'),
                tooltip: 'Thêm',
                icon: Icons.more_horiz_rounded,
                onPressed: () => _openMore(btn, perms),
              ),
            ),
          IconButton(
            key: const ValueKey('inv-open-lots'),
            tooltip: 'Hàng sắp về',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            onPressed: () => context.pushNamed(InventoryRoutes.lots),
            icon: Icon(
              Icons.local_shipping_outlined,
              size: OmniIconSize.md,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
        bottom: _SearchBottom(
          hint: 'Serial, model',
          onChanged: (v) => _filter.update((f) => f.copyWith(query: v)),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 400) {
                  ref.read(stockProvider.notifier).loadMore().ignore();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () => ref.read(stockProvider.notifier).refresh(),
                child: ListView(
                  key: const ValueKey('inv-stock-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    bottomPad + 88 + (actions > 1 ? 56 * (actions - 1) : 0),
                  ),
                  children: list,
                ),
              ),
            ),
          ),
          if (actions > 0)
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomPad + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (moveInBar)
                    FilledButton(
                      key: const ValueKey('inv-stock-move-picked'),
                      onPressed: _sending ? null : () => _movePicked(loaded),
                      child: Text('Chuyển vị trí · $pickedLoaded cây'),
                    ),
                  if (showSend && showSell)
                    OutlinedButton(
                      key: const ValueKey('inv-stock-send-picked'),
                      onPressed: _sending ? null : () => _sendPicked(loaded),
                      child: Text('Đưa vào xưởng · $pickedForWorkshop cây'),
                    )
                  else if (showSend)
                    FilledButton(
                      key: const ValueKey('inv-stock-send-picked'),
                      onPressed: _sending ? null : () => _sendPicked(loaded),
                      child: Text('Đưa vào xưởng · $pickedForWorkshop cây'),
                    ),
                  if (showSend && showSell) const SizedBox(height: 8),
                  if (showSell)
                    FilledButton(
                      key: const ValueKey('inv-stock-sell-picked'),
                      onPressed: () => _sellPicked(loaded),
                      child: Text('Bán / Đặt trước · $pickedLoaded cây'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Một cây trong danh sách tồn: "Hãng Model [serial]", dòng phụ lô · loại ·
/// tuổi tồn, khách (phân đoạn Đã có khách), bên phải giá niêm yết + tình trạng.
class StockUnitRow extends StatelessWidget {
  const StockUnitRow({
    super.key,
    required this.unit,
    required this.today,
    required this.onTap,
    required this.onSerial,
    this.showCustomer = false,
    this.canEditSerial = false,
    this.picking = false,
    this.picked = false,
    this.showWorkshop = false,
    this.thumb = false,
    this.location,
  });

  final InventoryUnit unit;
  final DateTime today;
  final VoidCallback onTap;
  final Future<void> Function(String? serial) onSerial;
  final bool showCustomer;
  final bool canEditSerial;
  final bool picking;
  final bool picked;

  /// Đang chọn cây để đưa vào xưởng: dòng nhỏ bên phải là tình hình xưởng
  /// (`8/10`, "Xong", "Chưa vào xưởng"), tình trạng dời sang dòng phụ.
  final bool showWorkshop;

  /// Ảnh đại diện nhỏ đầu dòng (API có ảnh — Đợt A).
  final bool thumb;

  /// Tên vị trí ghi ở dòng phụ (chỉ khi có từ hai vị trí).
  final String? location;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unit;
    final age = InventoryFormat.ageDays(u.receivedAt, today);
    final hold = showCustomer ? InvUi.holdLine(u) : null;
    final work = showWorkshop ? u.workshopLabel : null;
    return Semantics(
      button: true,
      selected: picking && picked,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                if (picking) ...[
                  Icon(
                    picked
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: picked ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
                if (thumb) ...[
                  InvUnitThumb(unit: u),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            u.name,
                            style: OmniType.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          SerialField(
                            serial: u.serial,
                            editable: canEditSerial,
                            semanticsName: u.name,
                            onSave: onSerial,
                          ),
                        ],
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: [
                                if (work != null)
                                  UnitCondition.labelOf(u.condition),
                                ?location,
                                if (u.lotCode != null) u.lotCode!,
                                if (InvUi.shortCategory(u.category).isNotEmpty)
                                  InvUi.shortCategory(u.category),
                              ].join(' · '),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: age == null ? 'chưa có ngày' : '$age ngày',
                              style: age != null && age > 180
                                  ? TextStyle(
                                      color: OmniColors.warningTextOf(context),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        style: invMuted(context),
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
                InvValue(
                  InvUi.vnd(u.listPrice),
                  sub: work ?? UnitCondition.labelOf(u.condition),
                  subColor: work != null
                      ? null
                      : InvUi.conditionColor(context, u.condition),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút biểu tượng 44×44 trên thanh tiêu đề (cùng kiểu nút Hàng sắp về).
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    onPressed: onPressed,
    icon: Icon(
      icon,
      size: OmniIconSize.md,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

/// Hàng lọc: chia đều khi ít ô, cuộn ngang khi có thêm ô Vị trí.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.pills, required this.scroll});

  final List<Widget> pills;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    if (!scroll) {
      return Row(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: pills[i]),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 200),
              child: pills[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const _SearchBottom({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 44,
        child: OmniSearchField(
          key: const ValueKey('inv-search'),
          hint: hint,
          flat: true,
          dense: true,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
