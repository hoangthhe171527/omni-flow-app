import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// Phiếu xuất kho (Kho chuẩn hóa Đợt C §2.5) — chỉ xem trên app: khách,
/// ngày, từng dòng hàng (serial, số lượng + ĐVT, đơn giá, thành tiền), tổng.
/// In phiếu làm ở web.
Future<void> openSlipSheet(BuildContext context, String no) =>
    showOmniSheet<void>(
      context: context,
      builder: (_) => SlipSheet(no: no),
    );

class SlipSheet extends ConsumerWidget {
  const SlipSheet({super.key, required this.no});

  final String no;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slip = ref.watch(slipProvider(no));
    final s = slip.valueOrNull;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: no,
        subtitle: s == null
            ? null
            : [
                if (s.customerName != null) s.customerName!,
                if (s.date != null) InventoryFormat.dmy(s.date),
              ].join(' · '),
      ),
      children: switch (slip) {
        AsyncValue(:final error?) when s == null => [
          OmniErrorView(
            error: InvUi.error(error),
            onRetry: () => ref.invalidate(slipProvider(no)),
          ),
        ],
        _ when s == null => [const InvSkeleton(count: 3, height: 56)],
        _ => [
          OmniGroupSection(
            key: const ValueKey('inv-slip-lines'),
            children: [
              for (final (i, l) in s.lines.indexed)
                OmniGroupRow(
                  key: ValueKey('inv-slip-line-$i'),
                  title: l.name.isEmpty ? (l.code ?? 'Hàng') : l.name,
                  subtitle: slipLineDetail(l),
                  trailing: InvValue(InvUi.vnd(l.amount)),
                ),
            ],
          ),
          OmniGroupSection(
            children: [
              OmniGroupRow(
                key: const ValueKey('inv-slip-total'),
                title: 'Tổng',
                trailing: InvValue(InvUi.vnd(s.total)),
              ),
            ],
          ),
        ],
      },
    );
  }
}

/// `B62-2 · 1 Chiếc × 52.000.000đ`.
String slipLineDetail(SlipLine l) => [
  if (l.serial != null && l.serial!.isNotEmpty) l.serial!,
  [
    '${InventoryFormat.number(l.qty)} ${l.unit}',
    if (l.price != null) InvUi.vnd(l.price),
  ].join(' × '),
].join(' · ');
