import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Bốn nhãn chuẩn của web; luôn hiện dù khách chưa có nhãn nào.
const kStandardCustomerTags = ['Đặt lịch', 'Báo giá', 'Hợp đồng', 'Khiếu nại'];

/// Chọn nhãn khách. Trả về TOÀN BỘ danh sách nhãn mới (máy chủ ghi đè
/// `metadata.tags` cả mảng), theo thứ tự đã chọn; `null` khi huỷ/vuốt đóng.
Future<List<String>?> showTagPicker(
  BuildContext context, {
  required List<String> current,
}) {
  return showOmniSheet<List<String>>(
    context: context,
    showDragHandle: true,
    builder: (_) => _TagPickerSheet(current: current),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.current});

  final List<String> current;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  // Nhãn hiện có khớp nhãn chuẩn không phân biệt hoa thường thì gập về cách
  // viết của nhãn chuẩn (không hiện hai dòng "Báo giá" / "báo giá").
  static String _canon(String tag) {
    final lower = tag.trim().toLowerCase();
    for (final s in kStandardCustomerTags) {
      if (s.toLowerCase() == lower) return s;
    }
    return tag;
  }

  late final List<String> _selected = _dedupe(widget.current.map(_canon));
  late final List<String> _options = _dedupe([
    ...kStandardCustomerTags,
    ..._selected,
  ]);

  static List<String> _dedupe(Iterable<String> tags) {
    final seen = <String>{};
    return [
      for (final t in tags)
        if (seen.add(t.toLowerCase())) t,
    ];
  }

  final _input = TextEditingController();
  String? _bumped;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
        _bumped = null;
      } else {
        _selected.add(tag);
        _bumped = tag;
      }
    });
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    final lower = text.toLowerCase();
    String? existing;
    for (final option in _options) {
      if (option.toLowerCase() == lower) existing = option;
    }
    setState(() {
      if (existing == null) {
        _options.add(text);
        _selected.add(text);
      } else if (!_selected.contains(existing)) {
        _selected.add(existing);
      }
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.enabled(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                for (final tag in _options)
                  InkWell(
                    onTap: () => _toggle(tag),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OmniSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            Semantics(
                              label: 'Nhãn: $tag',
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: OmniLabelColors.of(tag),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: OmniSpacing.md),
                            Expanded(child: Text(tag)),
                            AnimatedScale(
                              scale: motion && _bumped == tag ? 1.15 : 1,
                              duration: motion
                                  ? const Duration(milliseconds: 120)
                                  : Duration.zero,
                              onEnd: () {
                                if (_bumped == tag) {
                                  setState(() => _bumped = null);
                                }
                              },
                              child: IgnorePointer(
                                child: Checkbox.adaptive(
                                  value: _selected.contains(tag),
                                  onChanged: (_) {},
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(hintText: 'Thêm nhãn'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                OutlinedButton(
                  onPressed: _add,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              0,
              OmniSpacing.lg,
              OmniSpacing.lg,
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Huỷ'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(List<String>.of(_selected)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                  ),
                  child: const Text('Xong'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
