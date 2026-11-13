import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
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
  final confirmed = await showOmniSheet<bool>(
    context: context,
    builder: (sheetCtx) {
      return _FinanceTwoStepDeleteSheet(item: item, groupName: groupName);
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
    final item = widget.item;

    return OmniSheetBody(
      semanticsLabel: 'Xoá khoản chi',
      header: OmniSheetHeader(
        title: 'Xoá khoản chi?',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(
              Icons.close_rounded,
              size: OmniIconSize.md,
              color: p.ink,
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ),
      footer: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  if (_step == 2) {
                    setState(() => _step = 1);
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
                child: Text(_step == 2 ? 'Quay lại' : 'Huỷ'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
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
                // Chữ đỏ ngữ nghĩa trên nút kính hệ thống 50dp.
                style: FilledButton.styleFrom(foregroundColor: p.danger),
                child: Text(_step == 1 ? 'Tiếp tục xoá' : 'Xác nhận xoá'),
              ),
            ),
          ),
        ],
      ),
      children: [
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
        OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
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
          ],
        ),
        if (_step == 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.dangerSoft,
              borderRadius: BorderRadius.circular(14),
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
    );
  }
}

/// Hiển thị Sheet Chi tiết khoản chi (`fillDetail`),
/// đồng bộ trực tiếp với API chứng từ, đợt thanh toán và thời gian nhập.
Future<void> showExpenseDetailSheet({
  required BuildContext context,
  required String expenseId,
}) {
  return showOmniSheet<void>(
    context: context,
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
        : '—';

    final partial = !item.isRefund && !isSingleFull;

    return OmniSheetBody(
      semanticsLabel: 'Chi tiết khoản chi',
      header: OmniSheetHeader(
        title: 'Chi tiết khoản chi',
        subtitle: item.createdAt.isNotEmpty
            ? 'Nhập lúc ${item.createdAt}'
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              tooltip: 'Đóng',
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      children: [
        // 1. Khối tâm điểm trong OmniGroupSection bo 18: tên + số tiền lớn (không FittedBox) + trạng thái.
        OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
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
                      decoration: const InputDecoration(isDense: true),
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
                      borderRadius: BorderRadius.circular(12),
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
                            Icon(Icons.edit_outlined, size: 14, color: p.muted),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Số tiền lớn — đầy đủ chữ số tabularFigures, không co nhỏ bằng FittedBox
                  InkWell(
                    onTap: item.isRefund ? null : () => _openAmountKeypad(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              FinanceMonthUtils.formatNumber(item.amount),
                              maxLines: 1,
                              softWrap: false,
                              style: OmniType.displayLg.copyWith(
                                color: p.ink,
                                fontWeight: FontWeight.w600,
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
                      constraints: const BoxConstraints(minHeight: 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                          Flexible(
                            child: Text(
                              left > 0
                                  ? (paid > 0
                                        ? 'Trả một phần · Còn ${FinanceMonthUtils.formatVndSpace(left)}'
                                        : 'Chưa thanh toán')
                                  : 'Đã trả đủ (${item.payments.length} lần)',
                              style: OmniType.caption.copyWith(
                                color: left > 0 ? p.amber : p.ok,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // 2. Thông tin: nhóm lồng bo 18, vạch chia thụt 14, không chấm màu cầu vồng.
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            OmniGroupRow(
              key: _dateChipKey,
              title: 'Ngày ghi nhận',
              value: FinanceMonthUtils.fullDayMonthYear(
                item.spentOn,
                fallbackMonth: item.month,
              ),
              chevron: false,
              onTap: () => _openDateMenu(item),
            ),
            if (!item.isRefund)
              OmniGroupRow(
                key: const ValueKey('finance-detail-paid-date-cell'),
                title: 'Ngày thanh toán',
                value: paidDateFull,
                chevron: false,
                onTap: item.payments.isNotEmpty
                    ? () => _openPaymentDateMenu(item, paymentIndex: 0)
                    : () => _openPayKeypad(item),
              ),
            OmniGroupRow(
              key: _grpBtnKey,
              title: 'Nhóm chi phí',
              value: grp.name,
              chevron: false,
              onTap: () => _openGroupMenu(item),
            ),
            if (!item.isRefund)
              OmniGroupRow(
                key: _accChipKey,
                title: 'Nguồn tiền',
                value: accName,
                chevron: false,
                onTap: () => _openAccountMenu(item),
              ),
            OmniGroupRow(
              key: _attChipKey,
              title: 'Chứng từ',
              value: item.attachments.isNotEmpty
                  ? '${item.attachments.length} chứng từ'
                  : null,
              trailing: _uploadingAttachment
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              onTap: () => _openAttachmentMenu(item),
            ),
            // Ảnh thu nhỏ bo 14 xem trực tiếp ngay trong nhóm
            if (item.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                        height: 58,
                        onTap: () => _previewAttachment(item, att),
                        onRemove: () {
                          ref
                              .read(financeLedgerProvider.notifier)
                              .removeAttachmentFromExpense(item.id, att.id);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),

        // 3. Chưa trả / trả nhiều đợt: nhóm lồng Lịch sử trả + nút Trả (không FittedBox).
        if (partial)
          OmniGroupSection(
            title: item.payments.isNotEmpty ? 'Lịch sử trả' : null,
            dividerIndent: 14,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Đã trả ${FinanceMonthUtils.formatVndSpace(paid)}',
                          style: OmniType.bodySm.copyWith(
                            color: p.ink2,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          left > 0
                              ? 'Còn ${FinanceMonthUtils.formatVndSpace(left)}'
                              : '✓ Đã trả đủ (${item.payments.length} lần)',
                          style: OmniType.bodySm.copyWith(
                            color: left > 0 ? p.amber : p.ok,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < item.payments.length; i++)
                InkWell(
                  onTap: () => _openPaymentDateMenu(item, paymentIndex: i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
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
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (partial && left > 0)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => _openPayKeypad(item),
                    child: Text(
                      'Trả · ${FinanceMonthUtils.formatVndSpace(left)}',
                      maxLines: 1,
                      softWrap: false,
                      style: OmniType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              if (left >= 2000) ...[
                const SizedBox(width: 8),
                OmniGlass(
                  blur: false,
                  radius: 25,
                  child: SizedBox.square(
                    dimension: 50,
                    child: Center(
                      child: IconButton(
                        tooltip: 'Trả đủ ngay',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 50,
                          height: 50,
                        ),
                        icon: Icon(
                          Icons.check_rounded,
                          size: OmniIconSize.md,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref
                              .read(financeLedgerProvider.notifier)
                              .markPaidFull(item.id);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

        // 4. Xoá: nhóm đỏ riêng ở cuối, vẫn xác nhận hai bước.
        OmniGroupSection(
          children: [
            Tooltip(
              message: 'Xoá khoản chi',
              child: OmniGroupRow(
                title: 'Xoá khoản chi',
                icon: Icons.delete_outline_rounded,
                destructive: true,
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleIconBtn(
    FinancePalette p, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OmniGlassCircle(
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: Icon(icon, size: OmniIconSize.md, color: p.ink),
        onPressed: onTap,
      ),
    );
  }
}
