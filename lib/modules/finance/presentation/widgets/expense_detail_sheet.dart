import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../data/finance_api.dart';
import '../../domain/finance_models.dart';
import 'expense_keypad_sheet.dart';
import 'finance_attachment_picker.dart';
import 'finance_palette.dart';

/// Hiển thị Sheet xác nhận xoá 2 bước chuẩn công thái học 1 tay (`Thumb-Zone`).
Future<bool> showFinanceDeleteConfirmSheet({
  required BuildContext context,
  required ExpenseItem item,
  required String groupName,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetCtx) {
      return _FinanceTwoStepDeleteSheet(
        item: item,
        groupName: groupName,
      );
    },
  );
  return confirmed == true;
}

class _FinanceTwoStepDeleteSheet extends StatefulWidget {
  const _FinanceTwoStepDeleteSheet({
    required this.item,
    required this.groupName,
  });

  final ExpenseItem item;
  final String groupName;

  @override
  State<_FinanceTwoStepDeleteSheet> createState() =>
      _FinanceTwoStepDeleteSheetState();
}

class _FinanceTwoStepDeleteSheetState
    extends State<_FinanceTwoStepDeleteSheet> {
  int _step = 1;

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        math.max(20, bottomInset + 14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: p.muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.dangerSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _step == 1
                    ? 'Bước 1/2 · Kiểm tra mục sắp xoá'
                    : 'Bước 2/2 · Xác nhận xoá vĩnh viễn',
                style: OmniType.caption.copyWith(
                  color: p.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Xoá khoản chi?',
            style: OmniType.section.copyWith(
              color: p.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: OmniType.bodyStrong.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${FinanceMonthUtils.formatVndSpace(item.amount)} · ${widget.groupName}',
                  style: OmniType.bodySm.copyWith(
                    color: p.danger,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (_step == 2) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: p.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Xác nhận bước cuối: Chọn "Xác nhận xoá" bên dưới để xoá khoản chi này khỏi sổ.',
                style: OmniType.caption.copyWith(
                  color: p.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      if (_step == 2) {
                        setState(() => _step = 1);
                      } else {
                        Navigator.of(context).pop(false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.ink,
                      side: BorderSide(color: p.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_step == 2 ? 'Quay lại' : 'Huỷ'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: ValueKey(
                      _step == 1
                          ? 'finance-delete-step1-btn'
                          : 'finance-delete-step2-btn',
                    ),
                    onPressed: () {
                      if (_step == 1) {
                        setState(() => _step = 2);
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: p.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _step == 1 ? 'Tiếp tục xoá' : 'Xác nhận xoá',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hiển thị Sheet Chi tiết khoản chi (`fillDetail`),
/// đồng bộ trực tiếp với API chứng từ, đợt thanh toán và thời gian nhập.
Future<void> showExpenseDetailSheet({
  required BuildContext context,
  required String expenseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.36),
    builder: (sheetContext) {
      return _ExpenseDetailSheet(expenseId: expenseId);
    },
  );
}

class _ExpenseDetailSheet extends ConsumerStatefulWidget {
  const _ExpenseDetailSheet({required this.expenseId});

  final String expenseId;

  @override
  ConsumerState<_ExpenseDetailSheet> createState() =>
      _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<_ExpenseDetailSheet> {
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;
  String? _lastSyncedTitle;
  bool _editingTitle = false;
  bool _uploadingAttachment = false;

  final GlobalKey _grpBtnKey = GlobalKey();
  final GlobalKey _dateChipKey = GlobalKey();
  final GlobalKey _accChipKey = GlobalKey();
  final GlobalKey _attChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final item = ref.read(financeLedgerProvider).findItemById(widget.expenseId);
    _lastSyncedTitle = item?.title ?? '';
    _titleCtrl = TextEditingController(text: _lastSyncedTitle);
    _titleFocus = FocusNode()
      ..addListener(() {
        if (!_titleFocus.hasFocus) {
          _commitTitle();
          if (mounted && _editingTitle) {
            setState(() => _editingTitle = false);
          }
        }
      });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _commitTitle() {
    final text = _titleCtrl.text.trim();
    final item = ref.read(financeLedgerProvider).findItemById(widget.expenseId);
    if (item == null) return;
    if (text.isEmpty) {
      _titleCtrl.text = item.title;
      return;
    }
    if (text != item.title) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseTitle(widget.expenseId, text);
    }
  }

  Future<void> _openGroupMenu(ExpenseItem item) async {
    final groups = ref.read(financeLedgerProvider).groups;
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _grpBtnKey.currentContext,
      header: 'Chuyển sang nhóm',
      width: 248,
      items: [
        for (final g in groups)
          if (!g.archived || g.id == item.groupId)
            FinancePopoverItem<String>(
              value: g.id,
              label: g.name,
              dotColor: g.parsedColor,
              selected: g.id == item.groupId,
            ),
      ],
    );
    if (picked != null && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseGroup(item.id, picked);
    }
  }

  Future<void> _openDateMenu(ExpenseItem item) async {
    final state = ref.read(financeLedgerProvider);
    final picked = await showFinanceDateSelector(
      context: context,
      anchorContext: _dateChipKey.currentContext,
      currentIsoDate: item.spentOn,
      monthYm: item.month,
      clock: state.clock,
    );
    if (picked != null && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseDate(item.id, picked);
    }
  }

  Future<void> _openAccountMenu(ExpenseItem item) async {
    final state = ref.read(financeLedgerProvider);
    final accounts = state.usableAccounts;
    if (accounts.isEmpty) return;
    final currentAccId = item.defaultPaymentAccountId(state.accounts);
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _accChipKey.currentContext,
      header: 'Nguồn tiền',
      width: 236,
      items: [
        for (final acc in accounts)
          FinancePopoverItem<String>(
            value: acc.id,
            label: acc.name,
            selected: acc.id == currentAccId,
          ),
      ],
    );
    if (picked != null && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseAccount(item.id, picked);
    }
  }

  Future<void> _openAttachmentMenu(ExpenseItem item) async {
    if (_uploadingAttachment) return;
    setState(() => _uploadingAttachment = true);
    try {
      final att = await pickAndUploadFinanceAttachment(
        context: context,
        anchorContext: _attChipKey.currentContext,
        api: ref.read(financeApiProvider),
        onError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
      if (att != null && mounted) {
        await ref
            .read(financeLedgerProvider.notifier)
            .addAttachmentToExpense(item.id, att);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _previewAttachment(
    ExpenseItem item,
    ExpenseAttachment att,
  ) async {
    await showFinanceAttachmentPreviewDialog(
      context: context,
      att: att,
      expenseTitle: item.title,
      expenseAmount: item.amount,
      accountName: item.effectiveAccountName,
    );
  }

  Future<void> _openPaymentDateMenu(
    ExpenseItem item, {
    int paymentIndex = 0,
  }) async {
    if (item.isRefund || item.payments.isEmpty) return;
    final state = ref.read(financeLedgerProvider);
    final currentPaidOn = item.payments[paymentIndex].paidOn;
    final picked = await showFinanceDateSelector(
      context: context,
      anchorContext: null,
      currentIsoDate: currentPaidOn,
      monthYm: item.month,
      header: 'Ngày thanh toán',
      clock: state.clock,
    );
    if (picked != null && mounted) {
      await ref
          .read(financeLedgerProvider.notifier)
          .updateExpensePaymentDate(
            item.id,
            picked,
            paymentIndex: paymentIndex,
          );
    }
  }

  Future<void> _openAmountKeypad(ExpenseItem item) async {
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

  Future<void> _openPayKeypad(ExpenseItem item) async {
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
      initialAmount: left,
      maxAmount: left,
      initialAccountId: item.defaultPaymentAccountId(state.accounts),
      initialAccountName:
          item.effectiveAccountName ?? state.defaultPaymentAccount?.name,
      availableAccounts: state.usableAccounts,
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      final add = math.min(res.amount, left);
      ref
          .read(financeLedgerProvider.notifier)
          .recordPayment(
            item.id,
            amount: add,
            accountId: res.accountId,
            accountName: res.accountName,
          );
      if (add >= left && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeLedgerProvider);
    final item = state.findItemById(widget.expenseId);
    final p = FinancePalette.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (item == null) {
      return const SizedBox.shrink();
    }

    if (!_titleFocus.hasFocus && _lastSyncedTitle != item.title) {
      _lastSyncedTitle = item.title;
      _titleCtrl.text = item.title;
    }

    final grp = state.groupById(item.groupId);
    final paid = item.paidTotal;
    final left = item.remainingAmount;
    final pct = item.amount > 0 ? (paid / item.amount).clamp(0.0, 1.0) : 1.0;
    final accName = item.effectiveAccountName ?? 'Chọn nguồn tiền';
    final isSingleFull = item.isSingleFullPayment;
    final paidDateDm = item.payments.isNotEmpty
        ? FinanceMonthUtils.shortDayMonth(item.payments.first.paidOn)
        : FinanceMonthUtils.shortDayMonth(item.spentOn);
    final paidDateFull = item.payments.isNotEmpty
        ? FinanceMonthUtils.fullDayMonthYear(
            item.payments.first.paidOn,
            fallbackMonth: item.month,
          )
        : 'Chưa trả';

    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        math.max(20, bottomInset + 14) +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: p.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // 1. Thanh Header cân đối 2 đầu Trái - Phải
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết khoản chi',
                          style: OmniType.bodySm.copyWith(
                            color: p.ink2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.createdAt.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            'Nhập lúc ${item.createdAt}',
                            style: OmniType.micro.copyWith(color: p.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!item.isRefund) ...[
                    _buildCircleIconBtn(
                      p,
                      tooltip: 'Sao chép sang tháng sau',
                      icon: Icons.content_copy_rounded,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(financeLedgerProvider.notifier)
                            .duplicateToNextMonth(item.id);
                      },
                    ),
                    const SizedBox(width: 7),
                  ],
                  _buildCircleIconBtn(
                    p,
                    tooltip: 'Xoá khoản chi',
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: () async {
                      final ok = await showFinanceDeleteConfirmSheet(
                        context: context,
                        item: item,
                        groupName: grp.name,
                      );
                      if (!ok || !context.mounted) return;
                      Navigator.of(context).pop();
                      ref
                          .read(financeLedgerProvider.notifier)
                          .deleteExpense(item.id);
                    },
                  ),
                  const SizedBox(width: 7),
                  _buildCircleIconBtn(
                    p,
                    tooltip: 'Đóng',
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Khối Tâm điểm (Hero Card): Tên khoản chi + Số tiền lớn + Trạng thái
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.line, width: 0.5),
              ),
              child: Column(
                children: [
                  if (_editingTitle)
                    TextField(
                      controller: _titleCtrl,
                      focusNode: _titleFocus,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        _commitTitle();
                        setState(() => _editingTitle = false);
                      },
                      style: OmniType.section.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: p.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: p.primary, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: p.primary, width: 1.2),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      key: const ValueKey('finance-detail-title-btn'),
                      onTap: () {
                        setState(() => _editingTitle = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _titleFocus.requestFocus();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: OmniType.section.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: p.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Số tiền lớn — FittedBox đảm bảo hiển thị đủ 100%, không cắt "..."
                  InkWell(
                    onTap: item.isRefund ? null : () => _openAmountKeypad(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              FinanceMonthUtils.formatNumber(item.amount),
                              maxLines: 1,
                              style: OmniType.displayLg.copyWith(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'đ',
                              style: OmniType.title.copyWith(
                                color: p.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!item.isRefund) ...[
                              const SizedBox(width: 5),
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: p.muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (item.isRefund)
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: p.control,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_rounded, size: 14, color: p.muted),
                          const SizedBox(width: 5),
                          Text(
                            'Khoản hoàn / giảm trừ',
                            style: OmniType.caption.copyWith(
                              color: p.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isSingleFull)
                    InkWell(
                      key: const ValueKey('finance-detail-paid-date-pill'),
                      onTap: () => _openPaymentDateMenu(item, paymentIndex: 0),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: p.okSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: p.ok),
                            const SizedBox(width: 5),
                            Text(
                              'Đã trả đủ · $paidDateDm',
                              style: OmniType.caption.copyWith(
                                color: p.ok,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: left > 0 ? p.amberSoft : p.okSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            left > 0
                                ? Icons.schedule_rounded
                                : Icons.check_rounded,
                            size: 14,
                            color: left > 0 ? p.amber : p.ok,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            left > 0
                                ? (paid > 0
                                      ? 'Trả một phần · Còn ${FinanceMonthUtils.formatVndSpace(left)}'
                                      : 'Chưa thanh toán')
                                : 'Đã trả đủ (${item.payments.length} lần)',
                            style: OmniType.caption.copyWith(
                              color: left > 0 ? p.amber : p.ok,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Thẻ Thông tin Chuẩn hoá (Inset Grouped Card)
            Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.line, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hàng 1: Chia 2 cột Ngày ghi nhận | Ngày thanh toán
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: _dateChipKey,
                            onTap: () => _openDateMenu(item),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: p.muted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Ngày ghi nhận',
                                        style: OmniType.micro.copyWith(
                                          color: p.muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          FinanceMonthUtils.fullDayMonthYear(
                                            item.spentOn,
                                            fallbackMonth: item.month,
                                          ),
                                          style: OmniType.bodySm.copyWith(
                                            color: p.ink,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 15,
                                        color: p.muted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!item.isRefund) ...[
                          VerticalDivider(
                            width: 1,
                            thickness: 0.5,
                            color: p.divider,
                          ),
                          Expanded(
                            child: InkWell(
                              key: const ValueKey(
                                'finance-detail-paid-date-cell',
                              ),
                              onTap: item.payments.isNotEmpty
                                  ? () => _openPaymentDateMenu(
                                        item,
                                        paymentIndex: 0,
                                      )
                                  : () => _openPayKeypad(item),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event_available_outlined,
                                          size: 12,
                                          color: p.muted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Ngày thanh toán',
                                          style: OmniType.micro.copyWith(
                                            color: p.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            paidDateFull,
                                            style: OmniType.bodySm.copyWith(
                                              color: item.payments.isNotEmpty
                                                  ? p.ok
                                                  : p.amber,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 15,
                                          color: p.muted,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 0.5, color: p.divider),

                  // Hàng 2: Nhóm chi phí
                  InkWell(
                    key: _grpBtnKey,
                    onTap: () => _openGroupMenu(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Nhóm chi phí',
                            style: OmniType.bodySm.copyWith(
                              color: p.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: grp.parsedColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    grp.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: OmniType.bodySm.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: p.muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hàng 3: Nguồn tiền
                  if (!item.isRefund) ...[
                    Divider(height: 1, thickness: 0.5, color: p.divider),
                    InkWell(
                      key: _accChipKey,
                      onTap: () => _openAccountMenu(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Nguồn tiền',
                              style: OmniType.bodySm.copyWith(
                                color: p.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 14,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      accName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OmniType.bodySm.copyWith(
                                        color: p.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: p.muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Hàng 4: Chứng từ đính kèm
                  Divider(height: 1, thickness: 0.5, color: p.divider),
                  InkWell(
                    key: _attChipKey,
                    onTap: () => _openAttachmentMenu(item),
                    borderRadius: item.attachments.isEmpty
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Chứng từ',
                            style: OmniType.bodySm.copyWith(
                              color: p.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.attachments.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.primarySoft,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${item.attachments.length} chứng từ',
                                style: OmniType.micro.copyWith(
                                  color: p.primaryInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 13,
                                  color: p.primaryInk,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _uploadingAttachment
                                      ? 'Đang tải…'
                                      : (item.attachments.isNotEmpty
                                            ? '+ Thêm tệp'
                                            : 'Đính kèm'),
                                  style: OmniType.caption.copyWith(
                                    color: p.primaryInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ảnh thu nhỏ xem trực tiếp ngay trong thẻ
                  if (item.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final att in item.attachments)
                            FinanceAttachmentInlineThumb(
                              attachment: att,
                              expenseTitle: item.title,
                              expenseAmount: item.amount,
                              accountName: item.effectiveAccountName,
                              width: 78,
                              height: 54,
                              onTap: () => _previewAttachment(item, att),
                              onRemove: () {
                                ref
                                    .read(financeLedgerProvider.notifier)
                                    .removeAttachmentFromExpense(
                                      item.id,
                                      att.id,
                                    );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 4. Khi chưa trả hoặc trả nhiều đợt: hiện thẻ tiến độ + danh sách đợt trả + nút Trả
            if (!item.isRefund && !isSingleFull) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.line, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: p.amberSoft,
                          valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Đã trả ${FinanceMonthUtils.formatVndSpace(paid)}',
                              maxLines: 1,
                              style: OmniType.bodySm.copyWith(
                                color: p.ink2,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              left > 0
                                  ? 'Còn ${FinanceMonthUtils.formatVndSpace(left)}'
                                  : '✓ Đã trả đủ (${item.payments.length} lần)',
                              maxLines: 1,
                              style: OmniType.bodySm.copyWith(
                                color: left > 0 ? p.amber : p.ok,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.payments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Divider(height: 1, thickness: 0.5, color: p.divider),
                      for (var i = 0; i < item.payments.length; i++)
                        InkWell(
                          onTap: () =>
                              _openPaymentDateMenu(item, paymentIndex: i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              border: i == item.payments.length - 1
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: p.divider,
                                        width: 0.5,
                                      ),
                                    ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    [
                                      'Lần ${i + 1}',
                                      FinanceMonthUtils.shortDayMonth(
                                        item.payments[i].paidOn,
                                      ),
                                      if ((item.payments[i].accountName ??
                                              item.effectiveAccountName ??
                                              '')
                                          .isNotEmpty)
                                        (item.payments[i].accountName ??
                                            item.effectiveAccountName!),
                                    ].join(' · '),
                                    style: OmniType.bodySm.copyWith(
                                      color: p.ink2,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '✓ ${FinanceMonthUtils.formatVndSpace(item.payments[i].amount)}',
                                  style: OmniType.bodySm.copyWith(
                                    color: p.ok,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (left > 0)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => _openPayKeypad(item),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            elevation: 0,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Trả · ${FinanceMonthUtils.formatVndSpace(left)}',
                              style: OmniType.bodyStrong.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (left >= 2000) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Trả đủ ngay',
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            ref
                                .read(financeLedgerProvider.notifier)
                                .markPaidFull(item.id);
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: p.primarySoft,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: p.selLine, width: 0.5),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: p.primaryInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIconBtn(
    FinancePalette p, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: danger ? p.dangerSoft : p.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: danger
                  ? p.danger.withValues(alpha: 0.18)
                  : p.line,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 16, color: danger ? p.danger : p.ink2),
        ),
      ),
    );
  }
}
