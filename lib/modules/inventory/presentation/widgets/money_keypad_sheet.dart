import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/inventory_format.dart';

/// Bàn phím số cho một khoản tiền (giá chốt, cọc, giá ¥, số ₫). Trả số nguyên
/// đã nhập, null khi đóng không lưu. Số luôn hiện đủ chữ số.
Future<int?> showMoneyKeypad({
  required BuildContext context,
  required String title,
  String? subtitle,
  num? initial,
  String unit = 'đ',
}) {
  return showOmniSheet<int>(
    context: context,
    builder: (_) => _MoneyKeypad(
      title: title,
      subtitle: subtitle,
      initial: initial == null || initial <= 0 ? '' : '${initial.round()}',
      unit: unit,
    ),
  );
}

class _MoneyKeypad extends StatefulWidget {
  const _MoneyKeypad({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.unit,
  });

  final String title;
  final String? subtitle;
  final String initial;
  final String unit;

  @override
  State<_MoneyKeypad> createState() => _MoneyKeypadState();
}

class _MoneyKeypadState extends State<_MoneyKeypad> {
  late String _v = widget.initial;

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == 'del') {
        _v = _v.isEmpty ? '' : _v.substring(0, _v.length - 1);
      } else if ((_v + k).length <= 12) {
        _v = (_v + k).replaceFirst(RegExp(r'^0+'), '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = int.tryParse(_v) ?? 0;
    const keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '000',
      '0',
      'del',
    ];
    return OmniSheetBody(
      header: OmniSheetHeader(title: widget.title, subtitle: widget.subtitle),
      footer: FilledButton(
        key: const ValueKey('inv-keypad-done'),
        onPressed: () => Navigator.of(context).pop(n),
        child: const Text('Xong'),
      ),
      children: [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${InventoryFormat.number(n)} ${widget.unit}',
              key: const ValueKey('inv-keypad-amount'),
              textAlign: TextAlign.center,
              style: OmniType.moneyHero.copyWith(
                color: scheme.onSurface,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            for (final k in keys)
              OmniGlass(
                radius: 16,
                // 12 phím: không làm mờ thật (bậc hiệu năng), chỉ nền kính.
                blur: false,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('inv-key-$k'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _key(k),
                    child: Center(
                      child: k == 'del'
                          ? Icon(
                              Icons.backspace_outlined,
                              size: 20,
                              semanticLabel: 'Xoá',
                              color: scheme.onSurface,
                            )
                          : Text(
                              k,
                              style: OmniType.title.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
