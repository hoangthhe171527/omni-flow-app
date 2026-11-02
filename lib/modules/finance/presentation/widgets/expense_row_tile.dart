import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_models.dart';
import 'expense_detail_sheet.dart';
import 'expense_keypad_sheet.dart';
import 'finance_palette.dart';

/// Một dòng khoản chi trong danh sách ngày (`.row-wrap` + `.row` trong `so-chi-phi-mobile.html`),
/// hỗ trợ đầy đủ:
/// - Chạm mở Sheet Chi tiết
/// - Vuốt phải (`Trả đủ`) & Vuốt trái (`Tháng sau` / `Xoá`) chuẩn iOS
/// - Nhấn giữ mở iOS Context Menu
/// - Hiển thị chứng từ đính kèm (`📎 N`) và giờ nhập khi sắp xếp theo thời gian nhập
class ExpenseRowTile extends ConsumerStatefulWidget {
  const ExpenseRowTile({
    super.key,
    required this.item,
    required this.showBottomDivider,
    required this.isFlashed,
  });

  final ExpenseItem item;
  final bool showBottomDivider;
  final bool isFlashed;

  @override
  ConsumerState<ExpenseRowTile> createState() => _ExpenseRowTileState();
}

class _ExpenseRowTileState extends ConsumerState<ExpenseRowTile> {
  final GlobalKey _rowKey = GlobalKey();
  double _dragDx = 0;

  bool get _canPay => widget.item.remainingAmount > 0;

  void _resetSwipe() {
    if (_dragDx != 0) {
      setState(() => _dragDx = 0);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      final next = _dragDx + details.delta.dx;
      final maxRight = _canPay ? 88.0 : 0.0;
      _dragDx = next.clamp(-160.0, maxRight);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragDx > 52 && _canPay) {
      setState(() => _dragDx = 78);
    } else if (_dragDx < -52) {
      setState(() => _dragDx = -152);
    } else {
      setState(() => _dragDx = 0);
    }
  }

  Future<void> _openContextMenu() async {
    _resetSwipe();
    final item = widget.item;
    final left = item.remainingAmount;

    final action = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _rowKey.currentContext,
      header: item.title,
      width: 248,
      items: [
        if (left > 0) ...[
          const FinancePopoverItem<String>(
            value: 'pay_full',
            label: 'Đánh dấu Đã trả đủ',
            icon: Icons.check_rounded,
          ),
          const FinancePopoverItem<String>(
            value: 'pay_part',
            label: 'Trả một phần…',
            icon: Icons.payments_outlined,
          ),
        ],
        const FinancePopoverItem<String>(
          value: 'edit_amount',
          label: 'Sửa số tiền…',
          icon: Icons.edit_outlined,
        ),
        const FinancePopoverItem<String>(
          value: 'dup_next',
          label: 'Sao chép sang tháng sau',
          icon: Icons.content_copy_rounded,
        ),
        const FinancePopoverItem<String>(
          value: 'delete',
          label: 'Xoá khoản này',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );

    if (action == null || !mounted) return;
    final notifier = ref.read(financeLedgerProvider.notifier);

    switch (action) {
      case 'pay_full':
        notifier.markPaidFull(item.id);
      case 'pay_part':
        await _openPartialPayKeypad(item);
      case 'edit_amount':
        await _openEditAmountKeypad(item);
      case 'dup_next':
        notifier.duplicateToNextMonth(item.id);
      case 'delete':
        notifier.deleteExpense(item.id);
    }
  }

  Future<void> _openPartialPayKeypad(ExpenseItem item) async {
    final left = item.remainingAmount;
    if (left <= 0) return;
    final half = ((left / 2) / 1000).round() * 1000;
    final chips = <({String label, int amount})>[
      (
        label: 'Tất cả · ${FinanceMonthUtils.formatNumber(left)}',
        amount: left,
      ),
      if (half > 0 && half < left)
        (
          label: '50% · ${FinanceMonthUtils.formatNumber(half)}',
          amount: half,
        ),
      for (final preset in [1000000, 5000000])
        if (preset < left)
          (
            label: FinanceMonthUtils.formatNumber(preset),
            amount: preset,
          ),
    ];

    final res = await showExpenseKeypadSheet(
      context: context,
      title: 'Trả · ${item.title}',
      initialAmount: half > 0 ? half : left,
      maxAmount: left,
      initialAccountName: item.effectiveAccountName ?? 'TK ngân hàng',
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      ref.read(financeLedgerProvider.notifier).recordPayment(
        item.id,
        amount: math.min(res.amount, left),
        accountName: res.accountName,
      );
    }
  }

  Future<void> _openEditAmountKeypad(ExpenseItem item) async {
    final hist = FinanceSeedCatalog.historyForTitle(item.title);
    final chips = FinanceSeedCatalog.buildHistoryChips(hist);
    final res = await showExpenseKeypadSheet(
      context: context,
      title: 'Sửa số tiền · ${item.title}',
      initialAmount: item.amount,
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseAmount(item.id, res.amount);
    }
  }

  String _buildSubtitleText(FinanceLedgerState state, ExpenseGroup grp) {
    final item = widget.item;
    final acc = item.effectiveAccountName ?? 'TK ngân hàng';
    final parts = <String>[
      if (state.sortMode != ExpenseSortMode.category) grp.name,
      acc,
      if (state.sortMode == ExpenseSortMode.createdAtDesc)
        'Nhập ${item.createdTimeOnly}',
      if (item.attachments.isNotEmpty) '${item.attachments.length} chứng từ',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    final item = widget.item;
    final state = ref.watch(financeLedgerProvider);
    final grp = state.groupById(item.groupId);
    final left = item.remainingAmount;
    final paid = item.paidTotal;

    return ClipRect(
      child: Stack(
        children: [
          // Background swipe actions
          Positioned.fill(
            child: Row(
              children: [
                if (_canPay)
                  GestureDetector(
                    onTap: () {
                      _resetSwipe();
                      ref
                          .read(financeLedgerProvider.notifier)
                          .markPaidFull(item.id);
                    },
                    child: Container(
                      width: 78,
                      color: p.ok,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Trả đủ',
                            style: OmniType.micro.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _resetSwipe();
                    ref
                        .read(financeLedgerProvider.notifier)
                        .duplicateToNextMonth(item.id);
                  },
                  child: Container(
                    width: 76,
                    color: p.primary,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_copy_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tháng sau',
                          style: OmniType.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _resetSwipe();
                    ref
                        .read(financeLedgerProvider.notifier)
                        .deleteExpense(item.id);
                  },
                  child: Container(
                    width: 76,
                    color: p.danger,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Xoá',
                          style: OmniType.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Foreground row content
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragDx, 0, 0),
            color: widget.isFlashed ? p.primarySoft : p.card,
            child: GestureDetector(
              key: _rowKey,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onLongPress: _openContextMenu,
              onTap: () {
                if (_dragDx != 0) {
                  _resetSwipe();
                  return;
                }
                showExpenseDetailSheet(context: context, expenseId: item.id);
              },
              child: Stack(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 58),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: grp.parsedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OmniType.body.copyWith(
                                    color: p.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _buildSubtitleText(state, grp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OmniType.caption.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 11),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                FinanceMonthUtils.formatVndSpace(item.amount),
                                style: OmniType.body.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildStatusIndicator(p, left: left, paid: paid),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showBottomDivider)
                    Positioned(
                      left: 36,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 0.5, color: p.divider),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    FinancePalette p, {
    required int left,
    required int paid,
  }) {
    if (left <= 0) {
      return Icon(Icons.check_rounded, size: 12, color: p.ok);
    }
    if (paid > 0) {
      return Text(
        'còn ${FinanceMonthUtils.formatVndSpace(left)}',
        style: OmniType.micro.copyWith(
          color: p.amber,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: p.amber,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Chưa trả',
          style: OmniType.micro.copyWith(
            color: p.amber,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
