import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_models.dart';
import 'expense_detail_sheet.dart';
import 'expense_keypad_sheet.dart';
import 'finance_palette.dart';

/// Một dòng khoản chi trong danh sách ngày (`.row-wrap` + `.row`),
/// hỗ trợ đầy đủ:
/// - Chạm mở Sheet Chi tiết
/// - Vuốt phải (`Trả đủ`) & Vuốt trái (`Tháng sau` / `Xoá`): vòng kính hiện
///   dần theo tay; kéo trái hết cỡ để hỏi xoá ngay (expense-swipe-uiux.html B)
/// - Nhấn giữ mở iOS Context Menu
/// - Hiển thị đúng dữ liệu thực tế từ API (nguồn tiền thật, nhóm loại trừ CP, khoản hoàn/giảm trừ)
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
  bool _dragging = false;

  /// Kéo trái quá 60% bề ngang: nút Xoá đỏ đặc, thả tay là hỏi xoá ngay.
  bool _armed = false;
  double _width = 360;

  // Vuốt kiểu vòng kính (expense-swipe-uiux.html phương án B).
  static const double _actionWidth = 64;
  static const double _actionGap = 6;
  static const double _actionPad = 8;

  bool get _canPay => !widget.item.isRefund && widget.item.remainingAmount > 0;
  bool get _canDuplicate => !widget.item.isRefund;

  double get _openLeft =>
      _actionPad * 2 +
      _actionWidth * (_canDuplicate ? 2 : 1) +
      (_canDuplicate ? _actionGap : 0);
  double get _openRight => _canPay ? _actionPad * 2 + _actionWidth : 0;

  void _resetSwipe() {
    if (_dragDx != 0 || _armed) {
      setState(() {
        _dragDx = 0;
        _armed = false;
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails _) =>
      setState(() => _dragging = true);

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    var next = _dragDx + details.delta.dx;
    // Quá chỗ mở bên phải: kéo nặng dần (cao su).
    final maxRight = _openRight;
    if (next > maxRight) next = maxRight + (next - maxRight) * .2;
    if (next < -_width) next = -_width;
    final armed = -next > _width * .6;
    if (armed && !_armed) HapticFeedback.mediumImpact();
    setState(() {
      _dragDx = next;
      _armed = armed;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (_armed) {
      setState(() {
        _dragging = false;
        _dragDx = -_width;
      });
      _confirmDelete();
      return;
    }
    setState(() {
      _dragging = false;
      if ((_dragDx > _openRight * .55 || v > 600) && _canPay) {
        _dragDx = _openRight;
      } else if (_dragDx < -_openLeft * .4 || v < -600) {
        _dragDx = -_openLeft;
      } else {
        _dragDx = 0;
      }
    });
  }

  Future<void> _confirmDelete() async {
    final item = widget.item;
    final grp = ref.read(financeLedgerProvider).groupById(item.groupId);
    final ok = await showFinanceDeleteConfirmSheet(
      context: context,
      item: item,
      groupName: grp.name,
    );
    if (!mounted) return;
    _resetSwipe();
    if (ok) ref.read(financeLedgerProvider.notifier).deleteExpense(item.id);
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
        if (!item.isRefund && left > 0) ...[
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
        if (!item.isRefund) ...[
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
        ],
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
        final grp = ref.read(financeLedgerProvider).groupById(item.groupId);
        final ok = await showFinanceDeleteConfirmSheet(
          context: context,
          item: item,
          groupName: grp.name,
        );
        if (ok && mounted) {
          notifier.deleteExpense(item.id);
        }
    }
  }

  Future<void> _openPartialPayKeypad(ExpenseItem item) async {
    if (item.isRefund) return;
    final left = item.remainingAmount;
    if (left <= 0) return;
    final state = ref.read(financeLedgerProvider);
    final half = ((left / 2) / 1000).round() * 1000;
    final chips = <({String label, int amount})>[
      (label: 'Tất cả · ${FinanceMonthUtils.formatNumber(left)}', amount: left),
      if (half > 0 && half < left)
        (label: '50% · ${FinanceMonthUtils.formatNumber(half)}', amount: half),
      for (final preset in [1000000, 5000000])
        if (preset < left)
          (label: FinanceMonthUtils.formatNumber(preset), amount: preset),
    ];

    final res = await showExpenseKeypadSheet(
      context: context,
      title: 'Trả · ${item.title}',
      initialAmount: half > 0 ? half : left,
      maxAmount: left,
      initialAccountId: item.defaultPaymentAccountId(state.accounts),
      initialAccountName:
          item.effectiveAccountName ?? state.defaultPaymentAccount?.name,
      availableAccounts: state.usableAccounts,
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .recordPayment(
            item.id,
            amount: math.min(res.amount, left),
            accountId: res.accountId,
            accountName: res.accountName,
          );
    }
  }

  Future<void> _openEditAmountKeypad(ExpenseItem item) async {
    if (item.isRefund) return;
    final hist = ref.read(financeLedgerProvider).historyForTitle(item.title);
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
    final acc = item.effectiveAccountName;
    final isExcluded = !item.countsAsExpense || !grp.countsAsExpense;
    final parts = <String>[
      if (state.sortMode != ExpenseSortMode.category) grp.name,
      if (isExcluded) 'Không tính CP',
      if (acc != null && acc.isNotEmpty) acc,
      if (state.sortMode == ExpenseSortMode.createdAtDesc &&
          item.createdTimeOnly.isNotEmpty)
        'Nhập ${item.createdTimeOnly}',
      if (item.attachments.isNotEmpty) '${item.attachments.length} chứng từ',
    ];
    if (parts.isEmpty) return grp.name;
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

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth.isFinite) _width = box.maxWidth;
        // Dòng và vùng nút chạy CHUNG một giá trị: lúc lắng về, vùng nút lớn
        // đúng bằng phần dòng đã lộ — dòng không bao giờ che lên nút.
        // Kéo: bám tay; thả: lắng về chỗ mở (bật nhẹ) / đóng (êm).
        return TweenAnimationBuilder<double>(
          tween: Tween(end: _dragDx),
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: _dragDx == 0 ? Curves.easeOutCubic : Curves.easeOutBack,
          builder: (context, dx, _) {
            final revealLeft = math.max(0.0, -dx);
            final revealRight = math.max(0.0, dx);
            return ClipRect(
              child: Stack(
                children: [
                  // Nút chỉ nằm trong khoảng vừa lộ ra: hẹp thì cả cụm thu nhỏ,
                  // không nút nào bị dòng đè lên hay chồng lên nhau.
                  if (revealRight > 0 && _canPay)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: revealRight,
                      child: _SwipeActions(
                        progress: (revealRight / _openRight).clamp(0.0, 1.0),
                        children: [
                          _SwipeAction(
                            key: const ValueKey('swipe-pay'),
                            icon: Icons.check_rounded,
                            label: 'Trả đủ',
                            color: p.ok,
                            onTap: () {
                              _resetSwipe();
                              ref
                                  .read(financeLedgerProvider.notifier)
                                  .markPaidFull(item.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  if (revealLeft > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: revealLeft,
                      child: _SwipeActions(
                        progress: (revealLeft / _openLeft).clamp(0.0, 1.0),
                        children: [
                          if (_canDuplicate && !_armed)
                            _SwipeAction(
                              key: const ValueKey('swipe-dup'),
                              icon: Icons.content_copy_rounded,
                              label: 'Tháng sau',
                              color: p.primary,
                              onTap: () {
                                _resetSwipe();
                                ref
                                    .read(financeLedgerProvider.notifier)
                                    .duplicateToNextMonth(item.id);
                              },
                            ),
                          _SwipeAction(
                            key: const ValueKey('swipe-del'),
                            icon: Icons.delete_outline_rounded,
                            label: 'Xoá',
                            color: p.danger,
                            solid: _armed,
                            onTap: _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                  // Foreground row content
                  Container(
                    transform: Matrix4.translationValues(dx, 0, 0),
                    color: widget.isFlashed ? p.primarySoft : p.card,
                    child: GestureDetector(
                      key: _rowKey,
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _onHorizontalDragStart,
                      onHorizontalDragUpdate: _onHorizontalDragUpdate,
                      onHorizontalDragEnd: _onHorizontalDragEnd,
                      onLongPress: _openContextMenu,
                      onTap: () {
                        if (_dragDx != 0) {
                          _resetSwipe();
                          return;
                        }
                        showExpenseDetailSheet(
                          context: context,
                          expenseId: item.id,
                        );
                      },
                      child: Stack(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: grp.parsedColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 146,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            FinanceMonthUtils.formatVndSpace(
                                              item.amount,
                                            ),
                                            maxLines: 1,
                                            style: OmniType.body.copyWith(
                                              color: p.ink,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        _buildStatusIndicator(
                                          p,
                                          left: left,
                                          paid: paid,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.showBottomDivider)
                            Positioned(
                              left: 30,
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
          },
        );
      },
    );
  }

  Widget _buildStatusIndicator(
    FinancePalette p, {
    required int left,
    required int paid,
  }) {
    if (widget.item.isRefund) {
      return Text(
        'Hoàn/giảm',
        maxLines: 1,
        style: OmniType.micro.copyWith(
          color: p.muted,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (left <= 0) {
      return Icon(Icons.check_rounded, size: 12, color: p.ok);
    }
    if (paid > 0) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          'còn ${FinanceMonthUtils.formatVndSpace(left)}',
          maxLines: 1,
          style: OmniType.micro.copyWith(
            color: p.amber,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    if (widget.item.status == ExpenseStatus.partial) {
      return Text(
        'Trả một phần',
        maxLines: 1,
        style: OmniType.micro.copyWith(
          color: p.amber,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: p.amber, shape: BoxShape.circle),
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

/// Cụm nút vuốt nằm gọn trong khoảng đã lộ: [progress] 0→1 là mức lộ so với
/// chỗ mở; nút to dần và rõ dần theo tay. Thiếu chỗ thì thu nhỏ cả cụm.
class _SwipeActions extends StatelessWidget {
  const _SwipeActions({required this.progress, required this.children});

  final double progress;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOut.transform(progress);
    return ColoredBox(
      color: FinancePalette.of(context).card,
      child: Opacity(
        opacity: k,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _ExpenseRowTileState._actionPad,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Transform.scale(
                scale: .6 + .4 * k,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        const SizedBox(width: _ExpenseRowTileState._actionGap),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Một nút vuốt: vòng kính 40, màu chỉ ở biểu tượng, nhãn xám dưới.
/// [solid] (sắp xoá thật): vòng đặc màu nút, biểu tượng trắng.
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.solid = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _ExpenseRowTileState._actionWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                transform: Matrix4.diagonal3Values(
                  solid ? 1.12 : 1,
                  solid ? 1.12 : 1,
                  1,
                ),
                transformAlignment: Alignment.center,
                decoration: solid
                    ? BoxDecoration(color: color, shape: BoxShape.circle)
                    : OmniGlass.buttonDecoration(context, radius: 20),
                child: Icon(
                  icon,
                  size: 19,
                  color: solid ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: OmniType.micro.copyWith(
                  color: solid ? color : p.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
