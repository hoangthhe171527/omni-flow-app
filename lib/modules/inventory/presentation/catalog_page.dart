import 'package:flutter/material.dart';
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
import 'widgets/product_sheet.dart';

/// Danh mục hàng (Kho chuẩn hóa Đợt B, theo web `catalog-page`): tìm mã / tên,
/// lọc theo loại (gồm loại con), mỗi mã hàng một dòng — tên, mã · loại, giá
/// theo bậc đang dùng, tồn bên phải. Chạm mở sheet mã hàng (giá, tồn, nhập /
/// chuyển / đặt số thật / bán). API thiếu `inventory.products` → không có gì.
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  Future<void> _pickCategory(BuildContext context, WidgetRef ref) async {
    final sub = ref.listenManual(categoriesProvider, (_, _) {});
    final list = await ref
        .read(categoriesProvider.future)
        .catchError((_) => <InvCategory>[]);
    sub.close();
    if (!context.mounted) return;
    final f = ref.read(catalogFilterProvider);
    final r = await showInvOptions<String>(
      context: context,
      title: 'Loại',
      options: [for (final n in categoryTree(list)) (n.category.id, n.path)],
      selected: f.categoryId,
      allLabel: 'Tất cả loại',
    );
    if (r == null) return;
    ref.read(catalogFilterProvider.notifier).state = (
      categoryId: r.value,
      query: ref.read(catalogFilterProvider).query,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(inventoryPermsProvider);
    final subPage = !ShellTabRoutes.reachable(context, InventoryRoutes.catalog);
    void back() => GoRouter.maybeOf(context)?.go(InventoryRoutes.stockPath);
    if (!perms.products) {
      return Scaffold(
        appBar: OmniAppBar(
          title: 'Danh mục hàng',
          showAccount: !subPage,
          fallbackBack: subPage ? back : null,
        ),
        body: const OmniEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Chưa có danh mục hàng',
        ),
      );
    }
    final f = ref.watch(catalogFilterProvider);
    final products = ref.watch(productsProvider);
    final tiers = ref.watch(priceTiersProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <InvCategory>[];
    final catName = categories
        .where((c) => c.id == f.categoryId)
        .firstOrNull
        ?.name;
    final bottom = ShellBarInset.coveredBottom(context);

    final list = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: InvDropPill(
          key: const ValueKey('inv-catalog-category'),
          label: catName ?? 'Loại',
          active: f.categoryId != null,
          shrink: true,
          onTap: () => _pickCategory(context, ref),
        ),
      ),
      const SizedBox(height: OmniGroupSection.gap),
      ...switch (products) {
        AsyncValue(:final error?) when !products.hasValue => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(productsProvider),
          ),
        ],
        AsyncValue(:final value?) when value.isEmpty => [
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Không có mã hàng khớp')],
          ),
        ],
        AsyncValue(:final value?) => [
          OmniGroupSection(
            key: const ValueKey('inv-catalog-list'),
            title: '${value.length} mã hàng',
            children: [
              for (final p in value)
                ProductRow(
                  key: ValueKey('inv-product-${p.id}'),
                  product: p,
                  tiers: tiers,
                  onTap: () => openProductSheet(context, p),
                ),
            ],
          ),
        ],
        _ => [const InvSkeleton(count: 6, height: 64)],
      },
    ];

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Danh mục hàng',
        showAccount: !subPage,
        fallbackBack: subPage ? back : null,
        bottom: OmniSearchBottom(
          fieldKey: const ValueKey('inv-catalog-search'),
          hint: 'Mã, tên hàng',
          onChanged: (v) => ref.read(catalogFilterProvider.notifier).state = (
            categoryId: ref.read(catalogFilterProvider).categoryId,
            query: v,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider);
          await ref
              .read(productsProvider.future)
              .catchError((_) => const <InvProduct>[]);
        },
        child: ListView(
          key: const ValueKey('inv-catalog-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
          children: list,
        ),
      ),
    );
  }
}

/// Một mã hàng: tên, `mã · loại`, giá theo bậc (đủ số, xuống dòng khi chật);
/// bên phải tồn + đơn vị.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    required this.tiers,
    required this.onTap,
  });

  final InvProduct product;
  final List<PriceTier> tiers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    final prices = [
      for (final t in tiers)
        if (p.priceOf(t.key) case final v?)
          // Cây serial: giá lẻ theo từng cây, không lấy từ mã hàng.
          if (p.isQty || t.key != PriceTierKey.retail)
            '${t.name} ${InvUi.vnd(v)}',
    ];
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
                        p.name,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        [p.code, ?p.categoryName].join(' · '),
                        style: invMuted(context),
                      ),
                      if (prices.isNotEmpty)
                        Text(
                          prices.join(' · '),
                          style: invMuted(
                            context,
                          ).copyWith(fontFeatures: OmniType.tabular),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InvValue(InventoryFormat.number(p.onHand), sub: p.unitLabel),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: OmniTaskTones.of(context).chevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


