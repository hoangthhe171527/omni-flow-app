import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_models.dart';
import '../../domain/smart_expense_parser.dart';
import 'expense_keypad_sheet.dart';
import 'finance_palette.dart';

/// Hiển thị Sheet Thêm khoản chi (`openAdd` trong `so-chi-phi-mobile.html`),
/// tích hợp 5 mẫu gợi ý nhanh của anh Lê Nguyên và đính kèm chứng từ/phiếu chi.
Future<void> showExpenseAddSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.36),
    builder: (sheetContext) => const _ExpenseAddSheet(),
  );
}

class _ExpenseAddSheet extends ConsumerStatefulWidget {
  const _ExpenseAddSheet();

  @override
  ConsumerState<_ExpenseAddSheet> createState() => _ExpenseAddSheetState();
}

class _ExpenseAddSheetState extends ConsumerState<_ExpenseAddSheet> {
  final TextEditingController _smartCtrl = TextEditingController();
  final GlobalKey _grpRowKey = GlobalKey();
  final GlobalKey _dateRowKey = GlobalKey();
  final GlobalKey _accRowKey = GlobalKey();
  final GlobalKey _attRowKey = GlobalKey();

  late String _title;
  late int _amount;
  late String _groupId;
  late String _spentOn;
  late bool _isPaid;
  late String _accountName;
  final List<ExpenseAttachment> _attachments = <ExpenseAttachment>[];
  String _smartHint =
      'Mẹo: Gõ tên kèm số tiền (12tr, 650k, 1.85tr) — tự nhận diện số tiền & nhóm.';

  @override
  void initState() {
    super.initState();
    final state = ref.read(financeLedgerProvider);
    _title = '';
    _amount = 0;
    _groupId = 'op';
    _spentOn = FinanceMonthUtils.defaultSpentOnForMonth(state.activeMonth);
    _isPaid = true;
    _accountName = 'TK ngân hàng';
  }

  @override
  void dispose() {
    _smartCtrl.dispose();
    super.dispose();
  }

  void _onSmartTextChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _title = '';
        _smartHint =
            'Mẹo: Gõ tên kèm số tiền (12tr, 650k, 1.85tr) — tự nhận diện số tiền & nhóm.';
      });
      return;
    }

    final state = ref.read(financeLedgerProvider);
    final parsed = SmartExpenseParser.parse(
      trimmed,
      groups: state.groups,
      accounts: state.accounts,
    );

    setState(() {
      if (parsed.title.isNotEmpty) {
        _title = parsed.title;
      } else {
        _title = trimmed;
      }
      if (parsed.amount > 0) {
        _amount = parsed.amount;
      }
      if (parsed.matchedGroupId != null) {
        _groupId = parsed.matchedGroupId!;
      } else {
        final guessed = SmartExpenseParser.guessGroup(
          _title,
          groups: state.groups,
        );
        if (guessed != null) _groupId = guessed;
      }
      if (parsed.suggestedStatus == ExpenseStatus.unpaid) {
        _isPaid = false;
      }
      if (parsed.matchedAccountName != null) {
        _accountName = parsed.matchedAccountName!;
      } else if (parsed.matchedAccountId != null) {
        for (final a in state.accounts) {
          if (a.id == parsed.matchedAccountId) {
            _accountName = a.name;
            break;
          }
        }
      }
      final grpName = state.groupById(_groupId).name;
      if (_amount > 0) {
        _smartHint =
            'Đã nhận diện: $_title · ${FinanceMonthUtils.formatVndSpace(_amount)} · $grpName';
      } else {
        _smartHint = 'Chạm vào "Số tiền" bên dưới để mở bàn phím số';
      }
    });
  }

  void _applyQuickPreset(
    ({String label, String title, int amount, String groupId}) preset,
  ) {
    final state = ref.read(financeLedgerProvider);
    final grpName = state.groupById(preset.groupId).name;
    setState(() {
      _title = preset.title;
      _amount = preset.amount;
      _groupId = preset.groupId;
      _smartCtrl.text =
          '${preset.title} ${FinanceMonthUtils.formatNumber(preset.amount)}';
      _smartHint =
          'Đã chọn mẫu: ${preset.title} · ${FinanceMonthUtils.formatVndSpace(preset.amount)} · $grpName';
    });
  }

  Future<void> _openAmountKeypad() async {
    final hist = FinanceSeedCatalog.historyForTitle(_title);
    final chips = hist != null
        ? FinanceSeedCatalog.buildHistoryChips(hist)
        : <({String label, int amount})>[
            for (final v in [1850000, 3000000, 6500000, 12000000, 18000000])
              (label: FinanceMonthUtils.formatNumber(v), amount: v),
          ];

    final res = await showExpenseKeypadSheet(
      context: context,
      title: 'Số tiền khoản chi',
      initialAmount: _amount,
      chips: chips,
    );
    if (res != null && mounted) {
      setState(() => _amount = res.amount);
    }
  }

  Future<void> _openGroupPicker() async {
    final groups = ref.read(financeLedgerProvider).groups;
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _grpRowKey.currentContext,
      header: 'Nhóm chi phí',
      width: 248,
      items: [
        for (final g in groups)
          FinancePopoverItem<String>(
            value: g.id,
            label: g.name,
            dotColor: g.parsedColor,
            selected: g.id == _groupId,
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _groupId = picked);
    }
  }

  Future<void> _openDatePicker() async {
    final activeMonth = ref.read(financeLedgerProvider).activeMonth;
    final dates = FinanceMonthUtils.quickDatesForMonth(activeMonth);
    final currentDm = FinanceMonthUtils.shortDayMonth(_spentOn);
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _dateRowKey.currentContext,
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
      setState(() => _spentOn = picked);
    }
  }

  Future<void> _openAccountPicker() async {
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _accRowKey.currentContext,
      header: 'Nguồn tiền',
      width: 224,
      items: [
        for (final acc in FinanceSeedCatalog.defaultAccountNames)
          FinancePopoverItem<String>(
            value: acc,
            label: acc,
            selected: acc == _accountName,
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _accountName = picked);
    }
  }

  Future<void> _openAttachmentPicker() async {
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _attRowKey.currentContext,
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

    final nextIdx = _attachments.length + 1;
    final dm = FinanceMonthUtils.shortDayMonth(_spentOn).replaceAll('/', '');
    final dmSpace = FinanceMonthUtils.shortDayMonth(_spentOn);
    final att = switch (picked) {
      'photo' => ExpenseAttachment(
        id: 'new_att_$nextIdx',
        name: 'Phieu-chi-tien-mat-$dm-$nextIdx.jpg',
        kind: 'image',
        sizeLabel: '410 KB',
        uploadedAt: '$dmSpace 10:30',
      ),
      'gallery' => ExpenseAttachment(
        id: 'new_att_$nextIdx',
        name: 'Anh-hoa-don-$dm-$nextIdx.jpg',
        kind: 'image',
        sizeLabel: '520 KB',
        uploadedAt: '$dmSpace 10:30',
      ),
      _ => ExpenseAttachment(
        id: 'new_att_$nextIdx',
        name: 'Chung-tu-thanh-toan-$dm-$nextIdx.pdf',
        kind: 'pdf',
        sizeLabel: '240 KB',
        uploadedAt: '$dmSpace 10:30',
      ),
    };

    setState(() => _attachments.add(att));
  }

  Future<void> _saveExpense() async {
    if (_amount <= 0) {
      await _openAmountKeypad();
      if (_amount <= 0 || !mounted) return;
    }
    final state = ref.read(financeLedgerProvider);
    final grp = state.groupById(_groupId);
    final cleanTitle = _title.trim().isNotEmpty ? _title.trim() : grp.name;

    ref.read(financeLedgerProvider.notifier).addExpense(
      title: cleanTitle,
      amount: _amount,
      groupId: _groupId,
      spentOn: _spentOn,
      isPaid: _isPaid,
      accountName: _accountName,
      attachments: List<ExpenseAttachment>.unmodifiable(_attachments),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeLedgerProvider);
    final p = FinancePalette.of(context);
    final grp = state.groupById(_groupId);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thêm chi phí · ${FinanceMonthUtils.formatMonthSlash(state.activeMonth)}',
                    style: OmniType.section.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: p.control,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: p.ink2),
                    ),
                  ),
                ],
              ),
            ),
            // Smart 1-line input
            TextField(
              controller: _smartCtrl,
              onChanged: _onSmartTextChanged,
              style: OmniType.input.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Ví dụ: Chi phí kho 12tr hoặc Tiếp khách 650k tm',
                hintStyle: OmniType.body.copyWith(color: p.muted),
                filled: true,
                fillColor: p.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.line, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.primary, width: 1.2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 9),
              child: Text(
                _smartHint,
                style: OmniType.caption.copyWith(color: p.muted),
              ),
            ),
            // Quick preset chips (5 khoản cố định chuẩn)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      var i = 0;
                      i < FinanceSeedCatalog.quickAddPresets.length;
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _applyQuickPreset(
                          FinanceSeedCatalog.quickAddPresets[i],
                        ),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 29,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: p.line, width: 0.5),
                          ),
                          child: Text(
                            FinanceSeedCatalog.quickAddPresets[i].label,
                            style: OmniType.caption.copyWith(
                              color: p.ink2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Grouped iOS form card (.card with 6 .kv rows)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line, width: 0.5),
              ),
              child: Column(
                children: [
                  // 1. Số tiền
                  InkWell(
                    onTap: _openAmountKeypad,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: p.divider, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Số tiền',
                            style: OmniType.body.copyWith(color: p.muted),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _amount > 0
                                    ? FinanceMonthUtils.formatVndSpace(_amount)
                                    : 'Chạm để nhập',
                                style: OmniType.body.copyWith(
                                  color: _amount > 0 ? p.ink : p.primary,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: p.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 2. Nhóm chi phí
                  InkWell(
                    key: _grpRowKey,
                    onTap: _openGroupPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: p.divider, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nhóm chi phí',
                            style: OmniType.body.copyWith(color: p.muted),
                          ),
                          Row(
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
                                style: OmniType.body.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 15,
                                color: p.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3. Ngày ghi nhận
                  InkWell(
                    key: _dateRowKey,
                    onTap: _openDatePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: p.divider, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ngày ghi nhận',
                            style: OmniType.body.copyWith(color: p.muted),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                FinanceMonthUtils.fullDayMonthYear(
                                  _spentOn,
                                  fallbackMonth: state.activeMonth,
                                ),
                                style: OmniType.body.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 15,
                                color: p.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 4. Trạng thái (Segmented 2-option: Chưa trả | Trả đủ)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: p.divider, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trạng thái',
                          style: OmniType.body.copyWith(color: p.muted),
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: p.track,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatusSegOption(
                                p,
                                label: 'Chưa trả',
                                active: !_isPaid,
                                onTap: () => setState(() => _isPaid = false),
                              ),
                              _buildStatusSegOption(
                                p,
                                label: 'Trả đủ',
                                active: _isPaid,
                                onTap: () => setState(() => _isPaid = true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 5. Nguồn tiền
                  InkWell(
                    key: _accRowKey,
                    onTap: _openAccountPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: p.divider, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nguồn tiền',
                            style: OmniType.body.copyWith(color: p.muted),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _accountName,
                                style: OmniType.body.copyWith(
                                  color: p.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 15,
                                color: p.muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 6. Chứng từ đính kèm
                  InkWell(
                    key: _attRowKey,
                    onTap: _openAttachmentPicker,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chứng từ',
                                style: OmniType.body.copyWith(color: p.muted),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 15,
                                    color: _attachments.isNotEmpty
                                        ? p.primary
                                        : p.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _attachments.isNotEmpty
                                        ? '${_attachments.length} chứng từ'
                                        : 'Đính kèm ảnh / phiếu chi',
                                    style: OmniType.body.copyWith(
                                      color: _attachments.isNotEmpty
                                          ? p.primary
                                          : p.ink2,
                                      fontWeight: _attachments.isNotEmpty
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_attachments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final att in _attachments)
                                  Container(
                                    height: 26,
                                    padding: const EdgeInsets.only(
                                      left: 8,
                                      right: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.control,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          att.isPdf
                                              ? Icons.picture_as_pdf_outlined
                                              : Icons.receipt_long_outlined,
                                          size: 12,
                                          color: p.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          att.name,
                                          style: OmniType.caption.copyWith(
                                            color: p.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _attachments.removeWhere(
                                                (x) => x.id == att.id,
                                              );
                                            });
                                          },
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 13,
                                            color: p.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Primary button: Lưu khoản chi
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saveExpense,
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Lưu khoản chi',
                  style: OmniType.bodyStrong.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSegOption(
    FinancePalette p, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: active ? p.card : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: OmniType.caption.copyWith(
            color: active ? p.ink : p.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
