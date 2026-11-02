import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_models.dart';
import 'expense_keypad_sheet.dart';
import 'finance_palette.dart';

/// Hiển thị Sheet Chi tiết khoản chi (`fillDetail` trong `so-chi-phi-mobile.html`),
/// tích hợp thêm chứng từ đính kèm (`attachments`) và thời gian nhập (`createdAt`).
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
      width: 244,
      items: [
        for (final g in groups)
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
    final dates = FinanceMonthUtils.quickDatesForMonth(item.month);
    final currentDm = FinanceMonthUtils.shortDayMonth(item.spentOn);
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _dateChipKey.currentContext,
      header: 'Ngày ghi nhận',
      width: 224,
      items: [
        for (final d in dates)
          FinancePopoverItem<String>(
            value: d.isoDate,
            label: d.label,
            selected: FinanceMonthUtils.shortDayMonth(d.isoDate) == currentDm,
          ),
      ],
    );
    if (picked != null && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateExpenseDate(item.id, picked);
    }
  }

  Future<void> _openAccountMenu(ExpenseItem item) async {
    final currentAcc = item.effectiveAccountName ?? 'TK ngân hàng';
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _accChipKey.currentContext,
      header: 'Nguồn tiền',
      width: 224,
      items: [
        for (final acc in FinanceSeedCatalog.defaultAccountNames)
          FinancePopoverItem<String>(
            value: acc,
            label: acc,
            selected: acc == currentAcc,
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
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _attChipKey.currentContext,
      header: 'Đính kèm chứng từ đã chi',
      width: 244,
      items: const [
        FinancePopoverItem<String>(
          value: 'photo',
          label: 'Chụp ảnh phiếu chi',
          icon: Icons.camera_alt_outlined,
        ),
        FinancePopoverItem<String>(
          value: 'gallery',
          label: 'Chọn ảnh hoá đơn',
          icon: Icons.image_outlined,
        ),
        FinancePopoverItem<String>(
          value: 'pdf',
          label: 'Đính kèm tệp PDF',
          icon: Icons.picture_as_pdf_outlined,
        ),
      ],
    );
    if (picked == null || !mounted) return;

    final nextIdx = item.attachments.length + 1;
    final dm = FinanceMonthUtils.shortDayMonth(
      item.spentOn,
    ).replaceAll('/', '');
    final att = switch (picked) {
      'photo' => ExpenseAttachment(
        id: 'att_${item.id}_$nextIdx',
        name: 'Phieu-chi-tien-mat-$dm-$nextIdx.jpg',
        kind: 'image',
        sizeLabel: '410 KB',
        uploadedAt: item.createdAt,
      ),
      'gallery' => ExpenseAttachment(
        id: 'att_${item.id}_$nextIdx',
        name: 'Anh-hoa-don-$dm-$nextIdx.jpg',
        kind: 'image',
        sizeLabel: '520 KB',
        uploadedAt: item.createdAt,
      ),
      _ => ExpenseAttachment(
        id: 'att_${item.id}_$nextIdx',
        name: 'Chung-tu-thanh-toan-$dm-$nextIdx.pdf',
        kind: 'pdf',
        sizeLabel: '240 KB',
        uploadedAt: item.createdAt,
      ),
    };

    ref
        .read(financeLedgerProvider.notifier)
        .addAttachmentToExpense(item.id, att);
  }

  Future<void> _previewAttachment(
    ExpenseItem item,
    ExpenseAttachment att,
  ) async {
    final p = FinancePalette.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        att.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.receipt_long_outlined,
                        size: 20,
                        color: p.primaryInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.bodyStrong.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${att.sizeLabel} · Tải lên ${att.uploadedAt}',
                            style: OmniType.caption.copyWith(color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: Icon(Icons.close_rounded, color: p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        att.isPdf
                            ? Icons.description_outlined
                            : Icons.image_outlined,
                        size: 40,
                        color: p.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chứng từ khoản chi: ${item.title}',
                        textAlign: TextAlign.center,
                        style: OmniType.bodySm.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${FinanceMonthUtils.formatVndSpace(item.amount)} · ${item.effectiveAccountName ?? 'TK ngân hàng'}',
                        style: OmniType.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAmountKeypad(ExpenseItem item) async {
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

  Future<void> _openPayKeypad(ExpenseItem item) async {
    final left = item.remainingAmount;
    if (left <= 0) return;
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
      initialAccountName: item.effectiveAccountName ?? 'TK ngân hàng',
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      final add = math.min(res.amount, left);
      ref
          .read(financeLedgerProvider.notifier)
          .recordPayment(item.id, amount: add, accountName: res.accountName);
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
    final accName = item.effectiveAccountName ?? 'TK ngân hàng';
    final isSingleFull = item.isSingleFullPayment;
    final paidDateDm = item.payments.isNotEmpty
        ? FinanceMonthUtils.shortDayMonth(item.payments.first.paidOn)
        : FinanceMonthUtils.shortDayMonth(item.spentOn);

    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
        6,
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
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: p.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // Top bar: sh-bar
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Row(
                children: [
                  // Group pill button on left
                  InkWell(
                    key: _grpBtnKey,
                    onTap: () => _openGroupMenu(item),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: p.line, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          Text(
                            grp.name,
                            style: OmniType.caption.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 13,
                            color: p.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 3 circular 30x30 action buttons on right: Copy, Delete, Close
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
                  const SizedBox(width: 6),
                  _buildCircleIconBtn(
                    p,
                    tooltip: 'Xoá khoản chi',
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      ref
                          .read(financeLedgerProvider.notifier)
                          .deleteExpense(item.id);
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildCircleIconBtn(
                    p,
                    tooltip: 'Đóng',
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Hero section: inline title + 3 compact chips (Date, Account, Attachments) + attachment pills + big tappable amount + single paid pill (if paid in 1 go)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _commitTitle(),
                    style: OmniType.section.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: p.primary, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Compact inline metadata chips: Date + Account + Attachments
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildMetaChip(
                        key: _dateChipKey,
                        p: p,
                        icon: Icons.calendar_today_outlined,
                        label: FinanceMonthUtils.fullDayMonthYear(
                          item.spentOn,
                          fallbackMonth: item.month,
                        ),
                        onTap: () => _openDateMenu(item),
                      ),
                      _buildMetaChip(
                        key: _accChipKey,
                        p: p,
                        icon: Icons.account_balance_wallet_outlined,
                        label: accName,
                        onTap: () => _openAccountMenu(item),
                      ),
                      _buildMetaChip(
                        key: _attChipKey,
                        p: p,
                        icon: Icons.attach_file_rounded,
                        label: item.attachments.isNotEmpty
                            ? '${item.attachments.length} chứng từ'
                            : 'Đính kèm',
                        active: item.attachments.isNotEmpty,
                        onTap: () => _openAttachmentMenu(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Nhập lúc ${item.createdAt}',
                    style: OmniType.micro.copyWith(color: p.muted),
                  ),
                  if (item.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < item.attachments.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _buildAttachmentPill(
                              p,
                              item: item,
                              att: item.attachments[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Big tappable amount button
                  InkWell(
                    onTap: () => _openAmountKeypad(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            FinanceMonthUtils.formatNumber(item.amount),
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
                          const SizedBox(width: 5),
                          Icon(Icons.edit_outlined, size: 15, color: p.muted),
                        ],
                      ),
                    ),
                  ),
                  // Khi đã trả đủ trong 1 lần: chỉ hiện 1 dòng pill xanh gọn nhẹ, KHÔNG lặp lại bảng 3 dòng hay card lịch sử
                  if (isSingleFull) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 30,
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
                  ],
                ],
              ),
            ),
            // Khi chưa trả hoặc trả nhiều đợt: hiện thanh tiến độ + danh sách đợt trả + nút Trả
            if (!isSingleFull) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
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
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (item.payments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < item.payments.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
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
                                  'Lần ${i + 1} · ${FinanceMonthUtils.shortDayMonth(item.payments[i].paidOn)} · ${item.payments[i].accountName ?? accName}',
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

  Widget _buildAttachmentPill(
    FinancePalette p, {
    required ExpenseItem item,
    required ExpenseAttachment att,
  }) {
    return InkWell(
      onTap: () => _previewAttachment(item, att),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(left: 9, right: 5),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              att.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.receipt_long_outlined,
              size: 13,
              color: p.primary,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                att.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.caption.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                ref
                    .read(financeLedgerProvider.notifier)
                    .removeAttachmentFromExpense(item.id, att.id);
              },
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 13, color: p.muted),
              ),
            ),
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: danger ? p.dangerSoft : p.control,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: danger ? p.danger : p.ink2),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required Key key,
    required FinancePalette p,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? p.primarySoft : p.control,
          borderRadius: BorderRadius.circular(7),
          border: active ? Border.all(color: p.selLine, width: 0.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? p.primaryInk : p.muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: OmniType.caption.copyWith(
                color: active ? p.primaryInk : p.ink2,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: active ? p.primaryInk : p.muted,
            ),
          ],
        ),
      ),
    );
  }
}
