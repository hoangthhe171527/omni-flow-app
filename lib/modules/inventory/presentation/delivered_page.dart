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

/// Hàng đã giao (Kho chuẩn hóa Đợt C, theo web `delivered-page`): cây đã giao
/// cho khách — khách, phiếu xuất, ngày giao, giá bán, hóa đơn. Chạm mở cây:
/// xem phiếu, "Mở việc bảo hành", "Nhập lại kho". API thiếu
/// `inventory.returns` → không có gì.
class DeliveredPage extends ConsumerStatefulWidget {
  const DeliveredPage({super.key});

  @override
  ConsumerState<DeliveredPage> createState() => _DeliveredPageState();
}

const _page = 50;

class _DeliveredPageState extends ConsumerState<DeliveredPage> {
  String _q = '';
  int _limit = _page;

  /// Trang đã hiện gần nhất — giữ trong lúc tải thêm / tìm (không nháy).
  UnitPage? _last;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    if (!perms.delivered) {
      return const Scaffold(
        appBar: OmniAppBar(title: 'Hàng đã giao'),
        body: OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chưa có hàng đã giao',
        ),
      );
    }
    final query = (q: _q, limit: _limit);
    final res = ref.watch(deliveredProvider(query));
    // Đang tải trang lớn hơn: giữ danh sách cũ, không nháy khung chờ.
    if (res.hasValue) _last = res.value;
    final page = res.valueOrNull ?? (res.hasError ? null : _last);
    final bottom =
        ShellBarInset.of(context) + MediaQuery.viewPaddingOf(context).bottom;

    final list = <Widget>[
      ...switch (res) {
        AsyncValue(:final error?) when page == null => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(deliveredProvider(query)),
          ),
        ],
        _ when page == null => [const InvSkeleton(count: 5, height: 64)],
        _ when page.items.isEmpty => [
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có cây khớp')],
          ),
        ],
        _ => [
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-delivered-count'),
                title: '${InventoryFormat.number(page.total)} cây',
              ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            key: const ValueKey('inv-delivered-list'),
            children: [
              for (final u in page.items)
                DeliveredUnitRow(
                  key: ValueKey('inv-delivered-${u.id}'),
                  unit: u,
                  showInvoice: perms.invoices,
                  onTap: () =>
                      openUnitSheet(context, unit: u, onChanged: (_) {}),
                ),
              if (page.items.length < page.total)
                OmniGroupRow(
                  key: const ValueKey('inv-delivered-more'),
                  title: 'Xem thêm',
                  accent: true,
                  chevron: false,
                  onTap: () => setState(() => _limit += _page),
                ),
            ],
          ),
        ],
      },
    ];

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Hàng đã giao',
        bottom: InvSearchBottom(
          fieldKey: const ValueKey('inv-delivered-search'),
          hint: 'Serial, model',
          onChanged: (v) => setState(() {
            _q = v;
            _limit = _page;
          }),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deliveredProvider(query));
          await ref
              .read(deliveredProvider(query).future)
              .catchError((_) => const UnitPage(items: [], total: 0));
        },
        child: ListView(
          key: const ValueKey('inv-delivered-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 24),
          children: list,
        ),
      ),
    );
  }
}

/// Một cây đã giao: "Hãng Model serial", dòng phụ khách · phiếu · ngày giao;
/// bên phải giá bán + hóa đơn.
class DeliveredUnitRow extends StatelessWidget {
  const DeliveredUnitRow({
    super.key,
    required this.unit,
    required this.onTap,
    this.showInvoice = false,
  });

  final InventoryUnit unit;
  final VoidCallback onTap;
  final bool showInvoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = unit;
    final meta = [
      u.customerName ?? 'Khách',
      if (u.slipNo != null) u.slipNo!,
      if (u.deliveredAt != null) InventoryFormat.dmy(u.deliveredAt),
    ].join(' · ');
    final inv = showInvoice ? u.invoice : null;
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
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: u.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (u.serial != null)
                              TextSpan(text: '  ${u.serial}'),
                          ],
                        ),
                        style: OmniType.body.copyWith(color: scheme.onSurface),
                      ),
                      Text(meta, style: invMuted(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InvValue(
                  u.soldPrice == null ? '—' : InvUi.vnd(u.soldPrice),
                  sub: inv?.status.label,
                  subColor: inv?.status == InvoiceStatus.pending
                      ? OmniColors.warningTextOf(context)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô tìm 44 dưới thanh tiêu đề (như Tồn kho).
class InvSearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const InvSearchBottom({
    super.key,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      height: 44,
      child: OmniSearchField(
        key: fieldKey,
        hint: hint,
        flat: true,
        dense: true,
        onChanged: onChanged,
      ),
    ),
  );
}
