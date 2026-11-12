import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/domain/progress_level.dart';
import '../../tasks/routes.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import '../domain/order_units.dart';
import 'widgets/inventory_ui.dart';
import 'widgets/record_payment_sheet.dart';

/// Chi tiết đơn theo cây (TNP_DON_HANG_THEO_CAY §6, bản mẫu 7LZPEX "App · Đơn
/// hàng"): dòng "N/M cây xong" + vạch màu, cây gom theo trạng thái (nhóm lồng),
/// mỗi cây hai dòng. Chạm cây có việc xưởng → màn việc (công đoạn, bình luận,
/// báo vấn đề).
class OrderUnitsPage extends ConsumerWidget {
  const OrderUnitsPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(orderUnitsProvider(orderId));
    final data = res.valueOrNull;
    final bottom =
        ShellBarInset.of(context) + MediaQuery.viewPaddingOf(context).bottom;

    final title = data == null
        ? 'Đơn hàng'
        : data.customerName.isEmpty
        ? data.code
        : data.customerName;

    final List<Widget> body = switch (res) {
      AsyncValue(:final error?) when data == null => [
        OmniErrorView(
          error: InvUi.error(error),
          onRetry: () => ref.invalidate(orderUnitsProvider(orderId)),
        ),
      ],
      _ when data == null => [const InvSkeleton(count: 4, height: 64)],
      _ => _content(context, ref, data),
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: OmniAppBar(title: title, showAccount: false),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(orderUnitsProvider(orderId).future),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
          children: [
            for (var i = 0; i < body.length; i++) ...[
              if (i > 0) const SizedBox(height: OmniGroupSection.gap),
              body[i],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, OrderUnits d) {
    final router = GoRouter.maybeOf(context);
    // Ghi thu: quyền ghi đơn (`orders.write`, như web); đơn đã huỷ thì không.
    final canPay =
        ref.watch(accessProvider).can('orders.write') && !d.cancelled;
    Future<void> pay() async {
      final ok = await openRecordPaymentSheet(
        context,
        orderId: orderId,
        orderCode: d.code,
        remaining: d.remaining,
      );
      if (ok && context.mounted) InvUi.toast(context, 'Đã ghi thu.');
    }

    return [
      OmniGroupSection(
        key: const ValueKey('order-progress'),
        children: [
          _ProgressBlock(
            data: d,
            onPay: canPay && d.remaining > 0 ? pay : null,
          ),
        ],
      ),
      for (final (bucket, units) in d.groups)
        OmniGroupSection(
          key: ValueKey('order-group-${bucket.name}'),
          title: bucket.label,
          children: [
            for (final u in units)
              _UnitRow(
                unit: u,
                onTap: router != null && u.taskId != null
                    ? () => router.pushNamed(
                        TaskRoutes.detail,
                        pathParameters: {'id': u.taskId!},
                      )
                    : null,
              ),
          ],
        ),
      // Sổ thu (bản mẫu NWUQNP "Chi tiết đơn · đã thu"): mỗi đợt một dòng.
      if (d.payments.isNotEmpty || canPay)
        OmniGroupSection(
          key: const ValueKey('order-payments'),
          title: 'Đã thu',
          children: [
            for (final p in d.payments)
              OmniGroupRow(
                title: Formatters.vnd(p.amount),
                subtitle: [
                  if (p.paidAt case final at?) Formatters.date(at),
                  p.method.label,
                  ?p.note,
                ].join(' · '),
              ),
            if (canPay && d.remaining > 0)
              OmniGroupRow.add(
                key: const ValueKey('order-pay-add'),
                title: 'Ghi thu',
                onTap: pay,
              ),
          ],
        ),
      if (d.value > 0)
        OmniGroupSection(
          key: const ValueKey('order-money'),
          children: [
            OmniGroupRow(title: 'Tổng đơn', value: Formatters.vnd(d.value)),
            OmniGroupRow(title: 'Đã thu', value: Formatters.vnd(d.paid)),
          ],
        ),
    ];
  }
}

/// Khối tiến độ (bản mẫu): "N/M cây xong" · "còn X" một dòng, mã đơn, vạch gộp
/// (đã giao, sẵn sàng, có vấn đề, ở xưởng, chưa vào — theo số cây).
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.data, this.onPay});
  final OrderUnits data;

  /// Chạm "còn …" mở Ghi thu (tiền chạm để sửa). null = không ghi được.
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = OmniType.caption.copyWith(color: scheme.onSurfaceVariant);
    final parts = <(int, Color)>[
      (data.count(OrderUnitBucket.delivered), scheme.onSurfaceVariant),
      (data.count(OrderUnitBucket.ready), OmniColors.success),
      (data.count(OrderUnitBucket.issue), OmniColors.dangerTextOf(context)),
      (data.count(OrderUnitBucket.inShop), scheme.primary),
      (data.count(OrderUnitBucket.notInShop), scheme.outlineVariant),
    ];
    final barLabel = [
      for (final b in OrderUnitBucket.values)
        if (data.count(b) > 0) '${data.count(b)} ${b.label}',
    ].join(', ');
    final due = 'còn ${Formatters.vnd(data.remaining)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.total == 0
                      ? 'Chưa có cây nào'
                      : '${data.done}/${data.total} cây xong',
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                ),
              ),
              if (data.remaining > 0)
                onPay == null
                    ? Text(
                        due,
                        style: muted.copyWith(fontFeatures: OmniType.tabular),
                      )
                    : Semantics(
                        button: true,
                        label: '$due, ghi thu',
                        excludeSemantics: true,
                        child: InkWell(
                          key: const ValueKey('order-due'),
                          onTap: onPay,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 2,
                            ),
                            child: Text(
                              due,
                              style: OmniType.bodyStrong.copyWith(
                                color: scheme.primary,
                                fontFeatures: OmniType.tabular,
                              ),
                            ),
                          ),
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 2),
          Text(data.code, style: muted),
          if (data.total > 0) ...[
            const SizedBox(height: 10),
            Semantics(
              label: barLabel,
              excludeSemantics: true,
              child: _bar(parts),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(List<(int, Color)> parts) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(
      height: 6,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (n, c) in parts)
            if (n > 0)
              Expanded(
                flex: n,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: ColoredBox(color: c),
                ),
              ),
        ],
      ),
    ),
  );
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unit, this.onTap});
  final OrderUnit unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    final w = u.work;
    final String? line2 = switch (u.bucket) {
      OrderUnitBucket.issue => [
        u.issue?.note,
        ?u.issue?.byName,
      ].whereType<String>().join(' — '),
      OrderUnitBucket.inShop => [
        ?w?.sectionName,
        if (w != null && w.assigneeNames.isNotEmpty) w.assigneeNames.join(', '),
        if (w?.dueDate case final due?) 'hạn ${Formatters.dayMonth(due)}',
      ].join(' · '),
      OrderUnitBucket.ready => u.location,
      OrderUnitBucket.notInShop => [
        ?UnitCondition.parse(u.condition)?.label,
        ?u.lotCode,
      ].join(' · '),
      OrderUnitBucket.delivered =>
        u.deliveredAt == null ? null : Formatters.dayMonth(u.deliveredAt!),
    };
    final progress =
        w != null && w.total > 0 && u.bucket != OrderUnitBucket.delivered
        ? _ProgressChip(done: w.done, total: w.total)
        : null;

    return OmniGroupRow(
      key: ValueKey('order-unit-${u.id}'),
      title: [u.label.isEmpty ? '—' : u.label, ?u.serial].join(' '),
      subtitle: line2 == null || line2.isEmpty ? null : line2,
      // Cây có vấn đề: icon đỏ đầu dòng, lời báo ở dòng phụ.
      leading: u.bucket == OrderUnitBucket.issue
          ? Icon(Icons.report_outlined, color: OmniColors.dangerTextOf(context))
          : null,
      trailing: progress,
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

/// Ô `x/y` công đoạn bốn mức, cùng ngưỡng với thẻ bảng việc.
class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (progressLevelOf(done, total)) {
      ProgressLevel.low => OmniColors.dangerTextOf(context),
      ProgressLevel.mid => OmniColors.warningTextOf(context),
      ProgressLevel.near => OmniColors.byBrightness(
        context,
        OmniColors.infoText,
        OmniColors.darkInfoText,
      ),
      ProgressLevel.done => scheme.primary,
      null => scheme.onSurfaceVariant,
    };
    return Text(
      '$done/$total',
      style: OmniType.caption.copyWith(
        color: color,
        fontFeatures: OmniType.tabular,
      ),
    );
  }
}
