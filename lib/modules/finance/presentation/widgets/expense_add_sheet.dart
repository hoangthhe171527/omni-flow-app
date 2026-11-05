import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/tokens.dart';
import '../../application/finance_providers.dart';
import '../../data/finance_api.dart';
import '../../domain/finance_models.dart';
import '../../domain/smart_expense_parser.dart';
import 'expense_keypad_sheet.dart';
import 'finance_attachment_picker.dart';
import 'finance_palette.dart';

/// Hiển thị Sheet Thêm khoản chi (`openAdd`):
/// - Dải gợi ý thông minh duy nhất (`Wrap` gọn gàng, không dùng scroll ngang):
///   + Khi ô nhập trống: hiển thị 4 khoản cố định vận hành (`Chi phí kho`, `Điện nước`, `Lãi vay`, `Dịch vụ kế toán`)
///   + Khi đang gõ: hiển thị các gợi ý tên khoản chi khớp từ khoá (vd gõ `"Quảng"` -> `"Quảng cáo Facebook"`) và tự gán nhóm
/// - Tách riêng `Ngày ghi nhận` và `Ngày thanh toán` (khi chọn `Trả đủ`)
/// - Hiển thị trực tiếp Thumbnail ảnh chứng từ ngay trong dòng `Chứng từ` (không để dạng link chữ)
/// - Cụm 2 nút hành động dưới đáy: `Lưu & thêm tiếp` + `Lưu khoản chi`
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
  final FocusNode _smartFocus = FocusNode();
  final GlobalKey _grpRowKey = GlobalKey();
  final GlobalKey _dateRowKey = GlobalKey();
  final GlobalKey _paidDateRowKey = GlobalKey();
  final GlobalKey _accRowKey = GlobalKey();
  final GlobalKey _attRowKey = GlobalKey();

  late String _title;
  late int _amount;
  late String _groupId;
  late String _spentOn;
  late String _paidOn;
  bool _paidOnCustomized = false;
  late bool _isPaid;
  String? _accountId;
  String _accountName = '';
  bool _uploadingAttachment = false;
  final List<ExpenseAttachment> _attachments = <ExpenseAttachment>[];

  @override
  void initState() {
    super.initState();
    final state = ref.read(financeLedgerProvider);
    final defaultAcc = state.defaultPaymentAccount;
    _title = '';
    _amount = 0;
    _groupId = state.defaultGroupId;
    _spentOn = FinanceMonthUtils.defaultSpentOnForMonth(
      state.activeMonth,
      state.clock,
    );
    _paidOn = FinanceMonthUtils.clampPaidOn(_spentOn, state.clock);
    _isPaid = true;
    _accountId = defaultAcc?.id;
    _accountName = defaultAcc?.name ?? '';
  }

  @override
  void dispose() {
    _smartFocus.dispose();
    _smartCtrl.dispose();
    super.dispose();
  }

  void _onSmartTextChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _title = '';
      });
      return;
    }

    final state = ref.read(financeLedgerProvider);
    final parsed = SmartExpenseParser.parse(
      trimmed,
      groups: state.usableGroups,
      accounts: state.usableAccounts,
    );
    final suggestions = SmartExpenseParser.suggestTitles(
      trimmed,
      groups: state.usableGroups,
      historyItems: state.allLoadedExpenses,
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
      if (suggestions.isNotEmpty) {
        _groupId = suggestions.first.groupId;
      } else if (parsed.matchedGroupId != null &&
          parsed.matchedGroupId!.isNotEmpty) {
        _groupId = parsed.matchedGroupId!;
      } else {
        final guessed = SmartExpenseParser.guessGroup(
          _title,
          groups: state.usableGroups,
        );
        if (guessed != null && guessed.isNotEmpty) {
          _groupId = guessed;
        }
      }
      if (parsed.suggestedStatus == ExpenseStatus.unpaid) {
        _isPaid = false;
      }
      if (parsed.matchedAccountId != null) {
        _accountId = parsed.matchedAccountId;
        _accountName =
            parsed.matchedAccountName ??
            state.accountNameById(parsed.matchedAccountId) ??
            _accountName;
      } else if (parsed.matchedAccountName != null) {
        _accountName = parsed.matchedAccountName!;
      }
    });
  }

  void _applyQuickPreset(
    ({String label, String title, int amount, String groupId}) preset,
  ) {
    setState(() {
      _title = preset.title;
      _groupId = preset.groupId;
      if (preset.amount > 0) {
        _amount = preset.amount;
        _smartCtrl.text =
            '${preset.title} ${FinanceMonthUtils.formatNumber(preset.amount)}';
      } else {
        _smartCtrl.text = preset.title;
      }
      _smartCtrl.selection = TextSelection.collapsed(
        offset: _smartCtrl.text.length,
      );
    });
  }

  void _applyTitleSuggestion(ExpenseTitleSuggestion suggestion) {
    setState(() {
      _title = suggestion.title;
      _groupId = suggestion.groupId;
      if (_amount <= 0 && suggestion.suggestedAmount > 0) {
        _amount = suggestion.suggestedAmount;
      }
      _smartCtrl.text = suggestion.title;
      _smartCtrl.selection = TextSelection.collapsed(
        offset: _smartCtrl.text.length,
      );
    });
  }

  Future<void> _openAmountKeypad() async {
    final hist = ref.read(financeLedgerProvider).historyForTitle(_title);
    final chips = hist.isNotEmpty
        ? FinanceSeedCatalog.buildHistoryChips(hist)
        : <({String label, int amount})>[
            for (final v in [500000, 1500000, 3000000, 6500000, 12000000])
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
    final groups = ref.read(financeLedgerProvider).usableGroups;
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
    final state = ref.read(financeLedgerProvider);
    final picked = await showFinanceDateSelector(
      context: context,
      anchorContext: _dateRowKey.currentContext,
      currentIsoDate: _spentOn,
      monthYm: state.activeMonth,
      header: 'Ngày ghi nhận',
      clock: state.clock,
    );
    if (picked != null && mounted) {
      setState(() {
        _spentOn = picked;
        if (!_paidOnCustomized) {
          _paidOn = FinanceMonthUtils.clampPaidOn(picked, state.clock);
        }
      });
    }
  }

  Future<void> _openPaidDatePicker() async {
    final state = ref.read(financeLedgerProvider);
    final picked = await showFinanceDateSelector(
      context: context,
      anchorContext: _paidDateRowKey.currentContext,
      currentIsoDate: _paidOn,
      monthYm: state.activeMonth,
      header: 'Ngày thanh toán',
      clock: state.clock,
    );
    if (picked != null && mounted) {
      setState(() {
        _paidOnCustomized = true;
        _paidOn = FinanceMonthUtils.clampPaidOn(picked, state.clock);
      });
    }
  }

  Future<void> _openAccountPicker() async {
    final state = ref.read(financeLedgerProvider);
    final accounts = state.usableAccounts;
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _accRowKey.currentContext,
      header: 'Nguồn tiền',
      width: 236,
      items: [
        if (!_isPaid)
          FinancePopoverItem<String>(
            value: '__none__',
            label: 'Chưa chọn nguồn',
            selected: _accountId == null || _accountId!.isEmpty,
          ),
        for (final acc in accounts)
          FinancePopoverItem<String>(
            value: acc.id,
            label: acc.name,
            selected: acc.id == _accountId,
          ),
      ],
    );
    if (picked != null && mounted) {
      setState(() {
        if (picked == '__none__') {
          _accountId = null;
          _accountName = '';
        } else {
          _accountId = picked;
          _accountName = state.accountNameById(picked) ?? '';
        }
      });
    }
  }

  Future<void> _openAttachmentPicker() async {
    if (_uploadingAttachment) return;
    setState(() => _uploadingAttachment = true);
    try {
      final att = await pickAndUploadFinanceAttachment(
        context: context,
        anchorContext: _attRowKey.currentContext,
        api: ref.read(financeApiProvider),
        onError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
      if (att != null && mounted) {
        setState(() => _attachments.add(att));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _saveExpense({required bool keepOpen}) async {
    if (_uploadingAttachment) return;
    if (_amount <= 0) {
      await _openAmountKeypad();
      if (_amount <= 0 || !mounted) return;
    }
    final state = ref.read(financeLedgerProvider);
    final resolvedGroupId = _groupId.isNotEmpty
        ? _groupId
        : state.defaultGroupId;
    final grp = state.groupById(resolvedGroupId);
    final cleanTitle = _title.trim().isNotEmpty ? _title.trim() : grp.name;

    ref
        .read(financeLedgerProvider.notifier)
        .addExpense(
          title: cleanTitle,
          amount: _amount,
          groupId: resolvedGroupId,
          spentOn: _spentOn,
          isPaid: _isPaid,
          paidOn: _isPaid ? _paidOn : null,
          accountId: _accountId,
          accountName: _accountName.isNotEmpty ? _accountName : null,
          attachments: List<ExpenseAttachment>.unmodifiable(_attachments),
        );

    if (!mounted) return;
    if (!keepOpen) {
      Navigator.of(context).pop();
      return;
    }

    // Lưu & thêm tiếp: xoá tên + số tiền + chứng từ, giữ nguyên Ngày ghi nhận / Ngày thanh toán / Nhóm / Nguồn tiền
    setState(() {
      _title = '';
      _amount = 0;
      _smartCtrl.clear();
      _attachments.clear();
    });
    _smartFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeLedgerProvider);
    if (_groupId.isEmpty && state.defaultGroupId.isNotEmpty) {
      _groupId = state.defaultGroupId;
    }
    if (_isPaid && _accountId == null && state.defaultPaymentAccount != null) {
      _accountId = state.defaultPaymentAccount!.id;
      _accountName = state.defaultPaymentAccount!.name;
    }

    final p = FinancePalette.of(context);
    final grp = state.groupById(_groupId);
    final presets = state.quickAddPresets;
    final rawTyped = _smartCtrl.text.trim();
    final suggestions = rawTyped.isNotEmpty
        ? SmartExpenseParser.suggestTitles(
            rawTyped,
            groups: state.usableGroups,
            historyItems: state.allLoadedExpenses,
          )
        : const <ExpenseTitleSuggestion>[];
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final displayAccount = _accountName.isNotEmpty
        ? _accountName
        : (_isPaid ? 'Chọn nguồn tiền' : 'Chưa chọn nguồn');

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
              key: const ValueKey('finance-smart-input'),
              controller: _smartCtrl,
              focusNode: _smartFocus,
              onChanged: _onSmartTextChanged,
              style: OmniType.input.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:
                    'Tên khoản chi hoặc gõ kèm số tiền (vd: Quảng cáo FB 2.5tr)',
                hintStyle: OmniType.body.copyWith(color: p.muted),
                filled: true,
                fillColor: p.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
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
            // 1 Dải Chip thông minh duy nhất (Wrap gọn gàng, tuyệt đối không dùng scroll ngang):
            // - Khi đang gõ: hiển thị các chip gợi ý tên khoản chi khớp từ khoá
            // - Khi ô trống: hiển thị 4 khoản cố định vận hành
            if (suggestions.isNotEmpty)
              Padding(
                key: const ValueKey('finance-autocomplete-chips'),
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in suggestions)
                      InkWell(
                        key: ValueKey('finance-suggest-${s.title}'),
                        onTap: () => _applyTitleSuggestion(s),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: p.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: p.selLine, width: 0.7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: FinanceMonthUtils.parseHexColor(
                                    s.groupColor,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                s.title,
                                style: OmniType.caption.copyWith(
                                  color: p.primaryInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (rawTyped.isEmpty && presets.isNotEmpty)
              Padding(
                key: const ValueKey('finance-preset-chips'),
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in presets)
                      InkWell(
                        onTap: () => _applyQuickPreset(preset),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: p.line, width: 0.5),
                          ),
                          child: Text(
                            preset.label,
                            style: OmniType.caption.copyWith(
                              color: p.ink2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 10),
            // Grouped iOS form card
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
                        vertical: 11,
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
                        vertical: 11,
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
                          Flexible(
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
                                Flexible(
                                  child: Text(
                                    grp.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: OmniType.body.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                        vertical: 11,
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
                                  fallbackMonth: _spentOn.length >= 7
                                      ? _spentOn.substring(0, 7)
                                      : state.activeMonth,
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
                  // 4. Trạng thái (Chưa trả | Trả đủ)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8.5,
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
                                onTap: () => setState(() {
                                  _isPaid = true;
                                  if (_accountId == null &&
                                      state.defaultPaymentAccount != null) {
                                    _accountId =
                                        state.defaultPaymentAccount!.id;
                                    _accountName =
                                        state.defaultPaymentAccount!.name;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 5. Ngày thanh toán (hiển thị khi chọn Trả đủ)
                  if (_isPaid)
                    InkWell(
                      key: _paidDateRowKey,
                      onTap: _openPaidDatePicker,
                      child: Container(
                        key: const ValueKey('finance-add-paid-date-row'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
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
                              'Ngày thanh toán',
                              style: OmniType.body.copyWith(color: p.muted),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  FinanceMonthUtils.fullDayMonthYear(
                                    _paidOn,
                                    fallbackMonth: _paidOn.length >= 7
                                        ? _paidOn.substring(0, 7)
                                        : state.activeMonth,
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
                  // 6. Nguồn tiền
                  InkWell(
                    key: _accRowKey,
                    onTap: _openAccountPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
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
                                displayAccount,
                                style: OmniType.body.copyWith(
                                  color: _accountName.isNotEmpty
                                      ? p.ink
                                      : p.muted,
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
                  // 7. Chứng từ: Hiển thị trực tiếp Thumbnail ảnh ngay trong dòng (không để dạng link chữ)
                  Padding(
                    key: _attRowKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chứng từ',
                          style: OmniType.body.copyWith(color: p.muted),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final att in _attachments)
                                FinanceAttachmentInlineThumb(
                                  attachment: att,
                                  expenseTitle: _title.isNotEmpty
                                      ? _title
                                      : grp.name,
                                  expenseAmount: _amount,
                                  accountName: _accountName,
                                  onTap: () =>
                                      showFinanceAttachmentPreviewDialog(
                                        context: context,
                                        att: att,
                                        expenseTitle: _title.isNotEmpty
                                            ? _title
                                            : grp.name,
                                        expenseAmount: _amount,
                                        accountName: _accountName,
                                      ),
                                  onRemove: () {
                                    setState(() {
                                      _attachments.removeWhere(
                                        (x) => x.id == att.id,
                                      );
                                    });
                                  },
                                ),
                              InkWell(
                                key: const ValueKey('finance-add-attach-btn'),
                                onTap: _openAttachmentPicker,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: _attachments.isNotEmpty ? 46 : 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: p.line,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_uploadingAttachment)
                                        SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  p.primary,
                                                ),
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 15,
                                          color: p.primary,
                                        ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _uploadingAttachment
                                            ? 'Đang tải…'
                                            : (_attachments.isEmpty
                                                  ? 'Đính kèm ảnh / phiếu chi'
                                                  : '+ Thêm'),
                                        style: OmniType.caption.copyWith(
                                          color: p.primary,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Cụm 2 nút hành động dưới đáy (tương tự bản PC/Web): Lưu & thêm tiếp + Lưu khoản chi
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      key: const ValueKey('finance-save-and-continue-btn'),
                      onPressed: _uploadingAttachment
                          ? null
                          : () => _saveExpense(keepOpen: true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: p.primarySoft,
                        foregroundColor: p.primaryInk,
                        side: BorderSide(color: p.selLine, width: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Lưu & thêm tiếp',
                          style: OmniType.bodyStrong.copyWith(
                            color: p.primaryInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      key: const ValueKey('finance-save-btn'),
                      onPressed: _uploadingAttachment
                          ? null
                          : () => _saveExpense(keepOpen: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Lưu khoản chi',
                          style: OmniType.bodyStrong.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
