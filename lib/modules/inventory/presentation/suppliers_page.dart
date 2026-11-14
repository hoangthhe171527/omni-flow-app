import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../core/nav/shell_tab_routes.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../routes.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/supplier_sheet.dart';

/// Nhà cung cấp (Kho chuẩn hóa Đợt A, bản xem trước màn 4): dòng tổng nợ quá
/// hạn / tổng nợ / trả dư, danh sách nhà cung cấp với số nợ ¥ — số nợ chỉ khi
/// có quyền thanh toán lô (API bỏ hẳn khoá). API thiếu `inventory.suppliers`
/// thì không gọi gì.
class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final bottom = ShellBarInset.coveredBottom(context) + 24;
    final subPage = !ShellTabRoutes.reachable(
      context,
      InventoryRoutes.suppliers,
    );
    return Scaffold(
      appBar: OmniAppBar(
        title: 'Nhà cung cấp',
        showAccount: !subPage,
        fallbackBack: subPage
            ? () => GoRouter.maybeOf(context)?.go(InventoryRoutes.lotsPath)
            : null,
        bottom: perms.suppliers
            ? OmniSearchBottom(
                fieldKey: const ValueKey('inv-sup-search'),
                hint: 'Tìm mã, tên',
                onChanged: (v) => setState(() => _q = v),
              )
            : null,
      ),
      body: !perms.suppliers
          ? const OmniEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Chưa có màn nhà cung cấp',
            )
          : OmniAsyncView<List<SupplierDetail>>(
              value: ref.watch(supplierDetailsProvider),
              onRetry: () => ref.invalidate(supplierDetailsProvider),
              loading: const OmniSkeletonList(count: 5, height: 64),
              data: (all) {
                final q = _q.trim().toLowerCase();
                final rows = [
                  for (final s in all)
                    if (q.isEmpty ||
                        '${s.code} ${s.name}'.toLowerCase().contains(q))
                      s,
                ];
                // Số nợ: quyền thanh toán lô + API trả khoá.
                final debt = perms.pay && all.any((s) => s.hasDebt);
                double sum(double? Function(SupplierDetail) f) =>
                    all.fold<double>(0, (a, s) => a + (f(s) ?? 0));
                final late = sum((s) => s.overdueJpy);
                final prepaid = sum((s) => s.prepaidJpy);
                final open = all.fold<int>(0, (a, s) => a + (s.openLots ?? 0));
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(supplierDetailsProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
                    children: [
                      if (debt) ...[
                        OmniGroupSection(
                          key: const ValueKey('inv-sup-summary'),
                          children: [
                            OmniGroupRow(
                              title: 'Nợ quá hạn',
                              trailing: _Money(
                                InventoryFormat.yen(late),
                                danger: late > 0,
                              ),
                            ),
                            OmniGroupRow(
                              title: 'Tổng nợ',
                              subtitle: open > 0 ? '$open lô còn nợ' : null,
                              trailing: _Money(
                                InventoryFormat.yen(sum((s) => s.debtJpy)),
                              ),
                            ),
                            if (prepaid > 0)
                              OmniGroupRow(
                                title: 'Trả dư',
                                trailing: _Money(InventoryFormat.yen(prepaid)),
                              ),
                          ],
                        ),
                        const SizedBox(height: OmniGroupSection.gap),
                      ],
                      OmniGroupSection(
                        key: const ValueKey('inv-sup-list'),
                        dividerIndent: 14,
                        children: [
                          if (rows.isEmpty)
                            const InvMutedRow('Chưa có nhà cung cấp')
                          else
                            for (final s in rows)
                              _SupplierRow(
                                key: ValueKey('inv-sup-${s.id}'),
                                supplier: s,
                                debt: debt,
                                onTap: () => context.pushNamed(
                                  InventoryRoutes.supplier,
                                  pathParameters: {'supplierId': s.id},
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SupplierRow extends StatelessWidget {
  const _SupplierRow({
    super.key,
    required this.supplier,
    required this.debt,
    required this.onTap,
  });

  final SupplierDetail supplier;
  final bool debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final late = s.overdueJpy ?? 0;
    final pre = s.prepaidJpy ?? 0;
    final lots = s.openLots ?? 0;
    return OmniGroupRow(
      title: s.code,
      subtitle: [
        if (s.name.trim().isNotEmpty && s.name.trim() != s.code) s.name.trim(),
        s.originLabel,
        if (debt && lots > 0) '$lots lô còn nợ',
      ].join(' · '),
      trailing: debt
          ? InvValue(
              InventoryFormat.yen(s.debtJpy ?? 0),
              valueColor: (s.debtJpy ?? 0) > 0
                  ? OmniColors.warningTextOf(context)
                  : null,
              sub: late > 0
                  ? 'quá hạn ${InventoryFormat.yen(late)}'
                  : pre > 0
                  ? 'trả dư ${InventoryFormat.yen(pre)}'
                  : null,
              subColor: late > 0
                  ? OmniColors.dangerTextOf(context)
                  : pre > 0
                  ? OmniColors.successTextOf(context)
                  : null,
            )
          : null,
      chevron: true,
      onTap: onTap,
    );
  }
}

/// Hồ sơ và công nợ một nhà cung cấp (bản xem trước màn 5): còn nợ / trả dư /
/// hạn trả, lô còn nợ (chạm để mở lô), hồ sơ, tài khoản (chạm để chép số).
/// Sửa hồ sơ khi có quyền `inventory.suppliers`.
class SupplierDetailPage extends ConsumerWidget {
  const SupplierDetailPage({super.key, required this.supplierId});

  final String supplierId;

  Future<void> _edit(BuildContext context, SupplierDetail s) async {
    final saved = await openSupplierSheet(context, supplier: s);
    if (saved != null && context.mounted) {
      InvUi.toast(context, 'Đã lưu hồ sơ.');
    }
  }

  Future<void> _copy(BuildContext context, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) InvUi.toast(context, 'Đã chép số tài khoản.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(inventoryPermsProvider);
    final async = ref.watch(supplierProvider(supplierId));
    final s = async.valueOrNull;
    final bottom = ShellBarInset.coveredBottom(context) + 24;
    return Scaffold(
      appBar: OmniAppBar(
        title: s?.code ?? 'Nhà cung cấp',
        showAccount: false,
        fallbackBack: () =>
            GoRouter.maybeOf(context)?.go(InventoryRoutes.suppliersPath),
        actions: [
          if (s != null && perms.editSuppliers)
            IconButton(
              key: const ValueKey('inv-sup-edit'),
              tooltip: 'Sửa hồ sơ',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => _edit(context, s),
              icon: Icon(
                Icons.edit_outlined,
                size: OmniIconSize.md,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: !perms.suppliers
          ? const OmniEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Chưa có màn nhà cung cấp',
            )
          : s == null
          ? OmniAsyncView<SupplierDetail>(
              value: async,
              onRetry: () => ref.invalidate(supplierProvider(supplierId)),
              loading: const OmniSkeletonList(count: 4, height: 56),
              data: (_) => const SizedBox.shrink(),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(supplierProvider(supplierId).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
                children: _body(context, s),
              ),
            ),
    );
  }

  List<Widget> _body(BuildContext context, SupplierDetail s) {
    final late = s.overdueJpy ?? 0;
    final pre = s.prepaidJpy ?? 0;
    final lots = s.lots ?? const <SupplierLot>[];
    final profile = <Widget>[
      if (s.name.trim().isNotEmpty) OmniGroupRow(title: 'Tên', value: s.name),
      OmniGroupRow(
        title: 'Nguồn',
        value: '${s.originLabel} · ${s.person ? 'Cá nhân' : 'Tổ chức'}',
      ),
      if ((s.phone ?? '').isNotEmpty)
        OmniGroupRow(title: 'Điện thoại', value: s.phone),
      if ((s.address ?? '').isNotEmpty)
        OmniGroupRow(title: 'Địa chỉ', subtitle: s.address),
      if ((s.taxId ?? '').isNotEmpty)
        OmniGroupRow(title: 'Mã số thuế', value: s.taxId),
      OmniGroupRow(title: 'Tiền tệ', value: s.currency),
      if (!s.hasDebt) OmniGroupRow(title: 'Hạn trả', value: s.termLabel),
      if (s.customerName != null)
        OmniGroupRow(title: 'Là khách hàng', value: s.customerName),
      if ((s.note ?? '').isNotEmpty)
        OmniGroupRow(title: 'Ghi chú', subtitle: s.note),
    ];
    return [
      if (s.hasDebt) ...[
        OmniGroupSection(
          key: const ValueKey('inv-sup-debt'),
          children: [
            OmniGroupRow(
              title: 'Còn nợ',
              trailing: Text(
                InventoryFormat.yen(s.debtJpy),
                style: OmniType.bodyStrong.copyWith(
                  color: (s.debtJpy ?? 0) > 0
                      ? OmniColors.warningTextOf(context)
                      : Theme.of(context).colorScheme.onSurface,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
            if (late > 0)
              OmniGroupRow(
                title: 'Quá hạn',
                trailing: _Money(InventoryFormat.yen(late), danger: true),
              ),
            if (pre > 0)
              OmniGroupRow(
                title: 'Trả dư',
                trailing: Text(
                  InventoryFormat.yen(pre),
                  style: OmniType.bodyStrong.copyWith(
                    color: OmniColors.successTextOf(context),
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ),
            OmniGroupRow(title: 'Hạn trả', value: s.termLabel),
          ],
        ),
        if (lots.isNotEmpty) ...[
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            key: const ValueKey('inv-sup-lots'),
            title: 'Lô còn nợ',
            dividerIndent: 14,
            children: [
              for (final l in lots)
                OmniGroupRow(
                  key: ValueKey('inv-sup-lot-${l.id}'),
                  title: l.code,
                  subtitle: l.overdue
                      ? null
                      : l.receivedAt != null
                      ? 'Về kho ${InventoryFormat.dmy(l.receivedAt)}'
                      : LotStatus.parse(l.status).label,
                  trailing: InvValue(
                    l.dueJpy > 0
                        ? InventoryFormat.yen(l.dueJpy)
                        : 'trả dư ${InventoryFormat.yen(l.prepaidJpy)}',
                    sub: l.overdue ? 'Quá hạn' : null,
                    subColor: l.overdue
                        ? OmniColors.dangerTextOf(context)
                        : null,
                  ),
                  chevron: true,
                  onTap: () => context.pushNamed(
                    InventoryRoutes.lot,
                    pathParameters: {'lotId': l.id},
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: OmniGroupSection.gap),
      ],
      OmniGroupSection(
        key: const ValueKey('inv-sup-profile'),
        title: 'Hồ sơ',
        dividerIndent: 14,
        children: profile,
      ),
      if (s.bankAccounts.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          key: const ValueKey('inv-sup-banks'),
          title: 'Tài khoản',
          dividerIndent: 14,
          children: [
            for (final b in s.bankAccounts)
              OmniGroupRow(
                title: b.number,
                subtitle: [
                  b.bank,
                  if ((b.holder ?? '').isNotEmpty) b.holder!,
                ].join(' · '),
                trailing: Text(
                  'Chép',
                  style: OmniType.body.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _copy(context, b.number),
              ),
          ],
        ),
      ],
    ];
  }
}

/// Số tiền bên phải dòng: đủ số, đỏ khi quá hạn.
class _Money extends StatelessWidget {
  const _Money(this.text, {this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: OmniType.bodyStrong.copyWith(
      color: danger
          ? OmniColors.dangerTextOf(context)
          : Theme.of(context).colorScheme.onSurface,
      fontFeatures: OmniType.tabular,
    ),
  );
}


