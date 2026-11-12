import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/unit_sheet.dart';

/// Đang giữ (Kho chuẩn hóa Đợt B, theo web `reservations-page`): phiếu giữ
/// hàng lọc theo trạng thái; mỗi phiếu một dòng — khách, hàng giữ, hạn giữ,
/// giá trị và cọc. Chạm mở phiếu: từng cây (chạm mở cây), cọc, ngày nhận, nguồn
/// tiền, hạn. API thiếu `inventory.reservations` → không có gì.
class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

const _filters = <(ReservationStatus?, String)>[
  (ReservationStatus.active, 'Đang giữ'),
  (ReservationStatus.ordered, 'Vào đơn'),
  (ReservationStatus.released, 'Bỏ giữ'),
  (null, 'Tất cả'),
];

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    if (!perms.reservations) {
      return const Scaffold(
        appBar: OmniAppBar(title: 'Đang giữ'),
        body: OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chưa có phiếu giữ hàng',
        ),
      );
    }
    final status = _filters[_filter].$1;
    final res = ref.watch(reservationsProvider(status));
    final today = ref.watch(inventoryTodayProvider);
    final bottom = ShellBarInset.coveredBottom(context);

    final list = <Widget>[
      OmniSegmented(
        labels: [for (final f in _filters) f.$2],
        index: _filter,
        onChanged: (i) => setState(() => _filter = i),
      ),
      const SizedBox(height: OmniGroupSection.gap),
      ...switch (res) {
        AsyncValue(:final error?) when !res.hasValue => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(reservationsProvider(status)),
          ),
        ],
        AsyncValue(:final value?) when value.isEmpty => [
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có phiếu')],
          ),
        ],
        AsyncValue(:final value?) => [
          OmniGroupSection(
            key: const ValueKey('inv-res-list'),
            children: [
              for (final r in value)
                ReservationRow(
                  key: ValueKey('inv-res-${r.id}'),
                  reservation: r,
                  today: today,
                  showStatus: status == null,
                  onTap: () => openReservationSheet(context, r),
                ),
            ],
          ),
        ],
        _ => [const InvSkeleton(count: 4, height: 64)],
      },
    ];

    return Scaffold(
      appBar: const OmniAppBar(title: 'Đang giữ'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reservationsProvider(status));
          await ref
              .read(reservationsProvider(status).future)
              .catchError((_) => const <Reservation>[]);
        },
        child: ListView(
          key: const ValueKey('inv-res-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 24),
          children: list,
        ),
      ),
    );
  }
}

/// `YAMAHA U3H B62-2` (một – hai cây) hoặc `3 cây`.
String reservationGoods(Reservation r) {
  if (r.lines.isEmpty) return '0 cây';
  if (r.lines.length > 2) return '${r.lines.length} cây';
  return r.lines.map((l) => [l.label ?? 'Cây', ?l.serial].join(' ')).join(', ');
}

/// Một phiếu: khách, hàng giữ, hạn (vàng khi quá hạn); bên phải giá trị + cọc.
class ReservationRow extends StatelessWidget {
  const ReservationRow({
    super.key,
    required this.reservation,
    required this.today,
    required this.onTap,
    this.showStatus = false,
  });

  final Reservation reservation;
  final DateTime today;
  final VoidCallback onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = reservation;
    final expired = r.expiredOn(today);
    final meta = [
      if (showStatus) r.status.label,
      if (r.expiresAt != null) 'hạn ${InventoryFormat.dmy(r.expiresAt)}',
    ].join(' · ');
    final dep = r.deposit;
    return Semantics(
      button: true,
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
                        r.customerName ?? 'Khách',
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(reservationGoods(r), style: invMuted(context)),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: expired
                              ? invMuted(context).copyWith(
                                  color: OmniColors.warningTextOf(context),
                                )
                              : invMuted(context),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InvValue(
                  InvUi.vnd(r.total),
                  sub: dep == null || dep.amount <= 0
                      ? null
                      : 'cọc ${InvUi.vnd(dep.amount)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet một phiếu giữ: các cây (chạm mở cây), tổng, cọc, ngày nhận cọc,
/// nguồn tiền, hạn giữ, ghi chú.
Future<void> openReservationSheet(BuildContext context, Reservation r) =>
    showOmniSheet<void>(
      context: context,
      builder: (_) => ReservationSheet(reservation: r),
    );

class ReservationSheet extends ConsumerStatefulWidget {
  const ReservationSheet({super.key, required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends ConsumerState<ReservationSheet> {
  bool _opening = false;

  Future<void> _openUnit(String id) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final u = await ref.read(inventoryApiProvider).getUnit(id);
      if (!mounted) return;
      await openUnitSheet(context, unit: u, onChanged: (_) {});
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final r = widget.reservation;
    final today = ref.watch(inventoryTodayProvider);
    final dep = r.deposit;
    final accounts = dep?.moneyAccountId != null && perms.pay
        ? ref.watch(moneyAccountsProvider).valueOrNull ?? const <MoneyAccount>[]
        : const <MoneyAccount>[];
    final account = accounts
        .where((a) => a.id == dep?.moneyAccountId)
        .firstOrNull
        ?.name;
    final expired = r.expiredOn(today);

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: r.customerName ?? 'Khách',
        subtitle: r.status.label,
      ),
      children: [
        OmniGroupSection(
          key: const ValueKey('inv-res-units'),
          title: 'Hàng giữ',
          children: [
            for (final l in r.lines)
              OmniGroupRow(
                key: ValueKey('inv-res-unit-${l.unitId}'),
                title: l.label ?? 'Cây',
                subtitle: l.serial,
                trailing: InvValue(l.price == null ? '—' : InvUi.vnd(l.price)),
                onTap: _opening ? null : () => _openUnit(l.unitId),
              ),
            OmniGroupRow(title: 'Tổng', trailing: InvValue(InvUi.vnd(r.total))),
          ],
        ),
        OmniGroupSection(
          key: const ValueKey('inv-res-deposit'),
          children: [
            OmniGroupRow(
              title: 'Cọc',
              trailing: InvValue(
                dep == null || dep.amount <= 0
                    ? 'Không cọc'
                    : InvUi.vnd(dep.amount),
              ),
            ),
            if (dep?.paidAt != null)
              OmniGroupRow(
                title: 'Ngày nhận cọc',
                trailing: InvValue(InventoryFormat.dmy(dep!.paidAt)),
              ),
            if (account != null)
              OmniGroupRow(title: 'Nguồn tiền', trailing: InvValue(account)),
            if (r.expiresAt != null)
              OmniGroupRow(
                key: const ValueKey('inv-res-expires'),
                title: 'Hạn giữ',
                trailing: InvValue(
                  InventoryFormat.dmy(r.expiresAt),
                  sub: expired ? 'quá hạn' : null,
                  subColor: expired ? OmniColors.warningTextOf(context) : null,
                ),
              ),
            if (r.releasedAt != null)
              OmniGroupRow(
                title: 'Bỏ giữ',
                trailing: InvValue(InventoryFormat.dmy(r.releasedAt)),
              ),
          ],
        ),
        if ((r.note ?? '').isNotEmpty)
          OmniGroupSection(
            children: [OmniGroupRow(title: r.note!, maxTitleLines: 6)],
          ),
      ],
    );
  }
}
