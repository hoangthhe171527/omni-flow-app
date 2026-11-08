import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/finance_models.dart';
import 'finance_palette.dart';

/// Kết quả trả về từ bàn phím số kiêm máy tính (`showExpenseKeypadSheet`).
@immutable
class ExpenseKeypadResult {
  const ExpenseKeypadResult({
    required this.amount,
    this.accountId,
    this.accountName,
  });

  final int amount;
  final String? accountId;
  final String? accountName;
}

/// Hiển thị bàn phím số kiêm máy tính (`#pad` trong `so-chi-phi-mobile.html`).
Future<ExpenseKeypadResult?> showExpenseKeypadSheet({
  required BuildContext context,
  required String title,
  required int initialAmount,
  int? maxAmount,
  String? initialAccountId,
  String? initialAccountName,
  List<MoneyAccount> availableAccounts = const [],
  List<({String label, int amount})> chips = const [],
}) {
  return showOmniSheet<ExpenseKeypadResult>(
    context: context,
    builder: (sheetContext) {
      return _ExpenseKeypadSheet(
        title: title,
        initialAmount: initialAmount,
        maxAmount: maxAmount,
        initialAccountId: initialAccountId,
        initialAccountName: initialAccountName,
        availableAccounts: availableAccounts,
        chips: chips,
      );
    },
  );
}

class _ExpenseKeypadSheet extends StatefulWidget {
  const _ExpenseKeypadSheet({
    required this.title,
    required this.initialAmount,
    this.maxAmount,
    this.initialAccountId,
    this.initialAccountName,
    required this.availableAccounts,
    required this.chips,
  });

  final String title;
  final int initialAmount;
  final int? maxAmount;
  final String? initialAccountId;
  final String? initialAccountName;
  final List<MoneyAccount> availableAccounts;
  final List<({String label, int amount})> chips;

  @override
  State<_ExpenseKeypadSheet> createState() => _ExpenseKeypadSheetState();
}

class _ExpenseKeypadSheetState extends State<_ExpenseKeypadSheet> {
  late String _expr;
  late int _prev;
  late bool _fresh;
  String? _accountId;
  String? _accountName;
  final GlobalKey _srcBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _prev = widget.initialAmount;
    _expr = widget.initialAmount > 0 ? '${widget.initialAmount}' : '0';
    _fresh = widget.initialAmount > 0;
    _accountId = widget.initialAccountId;
    _accountName = widget.initialAccountName;
    if (_accountId != null && _accountName == null) {
      for (final a in widget.availableAccounts) {
        if (a.id == _accountId) {
          _accountName = a.name;
          break;
        }
      }
    }
  }

  bool get _hasOp =>
      RegExp(r'[+\-]').hasMatch(_expr.length > 1 ? _expr.substring(1) : '');

  int _evalExpr(String raw) {
    final s = raw.replaceAll(RegExp(r'[+\-]$'), '');
    if (s.isEmpty) return 0;
    final parts = s.split(RegExp(r'(?=[+\-])'));
    var acc = 0;
    for (final p in parts) {
      acc += int.tryParse(p) ?? 0;
    }
    return math.max(0, acc);
  }

  String _prettyExpr(String raw) {
    return raw.replaceAllMapped(RegExp(r'(\d+|\+|\-)'), (m) {
      final tok = m.group(0)!;
      if (tok == '+' || tok == '-') {
        return ' ${tok == '-' ? '−' : '+'} ';
      }
      final n = int.tryParse(tok) ?? 0;
      return FinanceMonthUtils.formatNumber(n);
    });
  }

  void _onKey(String k) {
    setState(() {
      if (k == 'c') {
        _expr = '0';
        _fresh = false;
        return;
      }
      if (k == 'bs') {
        if (_fresh) {
          _expr = '0';
          _fresh = false;
          return;
        }
        _expr = _expr.length > 1 ? _expr.substring(0, _expr.length - 1) : '0';
        return;
      }
      if (k == 'ok') {
        var v = _evalExpr(_expr);
        if (widget.maxAmount != null && v > widget.maxAmount!) {
          v = widget.maxAmount!;
        }
        Navigator.of(context).pop(
          ExpenseKeypadResult(
            amount: v,
            accountId: _accountId,
            accountName: _accountName,
          ),
        );
        return;
      }
      if (k == '+' || k == '-') {
        _fresh = false;
        if (RegExp(r'[+\-]$').hasMatch(_expr)) {
          _expr = _expr.substring(0, _expr.length - 1) + k;
        } else {
          _expr += k;
        }
        return;
      }
      // Chữ số '0'..'9' hoặc '000'
      if (_fresh) {
        _expr = (k == '000' || k == '0') ? '0' : k;
        _fresh = false;
        return;
      }
      final segs = _expr.split(RegExp(r'[+\-]'));
      final lastSeg = segs.isEmpty ? '' : segs.last;
      if (lastSeg.length >= 11) return;
      if (_expr == '0') {
        _expr = (k == '000' || k == '0') ? '0' : k;
      } else if (lastSeg == '0' && (k == '0' || k == '000')) {
        // Không nối thêm số 0 vô nghĩa vào đầu toán hạng 0
      } else {
        _expr += k;
      }
    });
  }

  Future<void> _openSourceMenu() async {
    if (widget.availableAccounts.isEmpty) return;
    final pickedId = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _srcBtnKey.currentContext,
      header: 'Nguồn tiền thanh toán',
      width: 236,
      items: [
        for (final acc in widget.availableAccounts)
          FinancePopoverItem<String>(
            value: acc.id,
            label: acc.name,
            subtitle: acc.kind.label,
            selected:
                acc.id == _accountId ||
                (_accountId == null && acc.name == _accountName),
          ),
      ],
    );
    if (pickedId != null && mounted) {
      final matched = widget.availableAccounts
          .where((a) => a.id == pickedId)
          .firstOrNull;
      if (matched != null) {
        setState(() {
          _accountId = matched.id;
          _accountName = matched.name;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    final val = _evalExpr(_expr);
    final showAccountPicker =
        widget.availableAccounts.isNotEmpty &&
        (_accountId != null || _accountName != null);

    // Tính dòng gợi ý / cảnh báo bên dưới số tiền
    String hintText = '';
    var hintDanger = false;
    if (widget.maxAmount != null && val > widget.maxAmount!) {
      hintText =
          'Vượt quá số còn phải trả (${FinanceMonthUtils.formatVndSpace(widget.maxAmount)})';
      hintDanger = true;
    } else if (widget.maxAmount != null) {
      final rem = math.max(0, widget.maxAmount! - val);
      hintText = rem == 0
          ? 'Trả 100% — đánh dấu Đã trả đủ'
          : 'Còn lại ${FinanceMonthUtils.formatVndSpace(rem)} sau lần trả này';
    } else if (_prev > 0 && val != _prev && val > 0) {
      final diff = val - _prev;
      final pct = (diff.abs() / _prev * 100).round();
      hintText =
          '${diff > 0 ? 'Tăng' : 'Giảm'} ${FinanceMonthUtils.formatVndSpace(diff.abs())} ($pct%) so với trước (${FinanceMonthUtils.formatVndSpace(_prev)})';
    }

    return OmniSheetBody(
      semanticsLabel: widget.title,
      header: OmniSheetHeader(
        title: widget.title,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAccountPicker) ...[
              const SizedBox(width: 8),
              InkWell(
                key: _srcBtnKey,
                onTap: _openSourceMenu,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: p.control,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 13,
                        color: p.ink2,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _accountName ?? 'Chọn nguồn',
                        style: OmniType.caption.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: p.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
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
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display card: pad-disp
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 17,
                    child: _hasOp
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_prettyExpr(_expr)} =',
                              maxLines: 1,
                              style: OmniType.caption.copyWith(
                                color: p.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 1),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: _fresh
                                ? const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1,
                                  )
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              color: _fresh
                                  ? p.primarySoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              FinanceMonthUtils.formatNumber(val),
                              maxLines: 1,
                              style: OmniType.moneyHero.copyWith(
                                color: _fresh ? p.primaryInk : p.ink,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'đ',
                            style: OmniType.section.copyWith(
                              color: p.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 16,
                    child: hintText.isNotEmpty
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              hintText,
                              maxLines: 1,
                              style: OmniType.micro.copyWith(
                                color: hintDanger ? p.danger : p.muted,
                                fontWeight: hintDanger
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            // Suggestion chips: pad-chips
            if (widget.chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                // Xuống hàng thay vì cuộn ngang: số tiền gợi ý không bị cắt.
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in widget.chips)
                      _buildChip(p, chip, currentVal: val),
                  ],
                ),
              ),
            // 4x4 keys grid
            Column(
              children: [
                Row(
                  children: [
                    _buildKey(p, label: '1', keyVal: '1'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '2', keyVal: '2'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '3', keyVal: '3'),
                    const SizedBox(width: 7),
                    _buildKey(
                      p,
                      label: '⌫',
                      keyVal: 'bs',
                      tone: _KeyTone.operatorKey,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildKey(p, label: '4', keyVal: '4'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '5', keyVal: '5'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '6', keyVal: '6'),
                    const SizedBox(width: 7),
                    _buildKey(
                      p,
                      label: '+',
                      keyVal: '+',
                      tone: _KeyTone.operatorKey,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildKey(p, label: '7', keyVal: '7'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '8', keyVal: '8'),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '9', keyVal: '9'),
                    const SizedBox(width: 7),
                    _buildKey(
                      p,
                      label: '−',
                      keyVal: '-',
                      tone: _KeyTone.operatorKey,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildKey(
                      p,
                      label: '000',
                      keyVal: '000',
                      tone: _KeyTone.subKey,
                    ),
                    const SizedBox(width: 7),
                    _buildKey(p, label: '0', keyVal: '0'),
                    const SizedBox(width: 7),
                    _buildKey(
                      p,
                      label: 'C',
                      keyVal: 'c',
                      tone: _KeyTone.subKey,
                    ),
                    const SizedBox(width: 7),
                    _buildKey(
                      p,
                      label: 'Xong',
                      keyVal: 'ok',
                      tone: _KeyTone.okKey,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(
    FinancePalette p,
    ({String label, int amount}) chip, {
    required int currentVal,
  }) {
    final active = chip.amount == currentVal;
    return OmniChoicePill(
      label: chip.label,
      selected: active,
      onTap: () {
        setState(() {
          _expr = '${chip.amount}';
          _fresh = false;
        });
      },
    );
  }

  Widget _buildKey(
    FinancePalette p, {
    required String label,
    required String keyVal,
    _KeyTone tone = _KeyTone.normal,
  }) {
    final bgColor = switch (tone) {
      _KeyTone.normal => p.card,
      _KeyTone.operatorKey => p.control,
      _KeyTone.subKey => p.control,
      _KeyTone.okKey => Colors.transparent,
    };
    final textColor = switch (tone) {
      _KeyTone.normal => p.ink,
      _KeyTone.operatorKey => p.ink,
      _KeyTone.subKey => p.ink2,
      _KeyTone.okKey => Theme.of(context).colorScheme.primary,
    };
    final textStyle = switch (tone) {
      _KeyTone.normal => OmniType.title.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      _KeyTone.operatorKey => OmniType.title.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      _KeyTone.subKey => OmniType.bodyStrong.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      _KeyTone.okKey => OmniType.bodyStrong.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    };

    // "Xong" là nút kính chữ màu chính (không tô đặc); các phím còn lại là
    // ô phẳng không viền.
    final ok = tone == _KeyTone.okKey;

    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _onKey(keyVal),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: ok
                ? OmniGlass.buttonDecoration(context, radius: 14)
                : null,
            child: Text(label, style: textStyle),
          ),
        ),
      ),
    );
  }
}

enum _KeyTone { normal, operatorKey, subKey, okKey }
