import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Bốn nhãn chuẩn của web; luôn hiện dù khách chưa có nhãn nào.
const kStandardCustomerTags = ['Đặt lịch', 'Báo giá', 'Hợp đồng', 'Khiếu nại'];

/// Chọn nhãn khách. Trả về TOÀN BỘ danh sách nhãn mới (máy chủ ghi đè
/// `metadata.tags` cả mảng), theo thứ tự đã chọn; `null` khi huỷ/vuốt đóng.
Future<List<String>?> showTagPicker(
  BuildContext context, {
  required List<String> current,
  String? draftScope,
}) {
  return showOmniSheet<List<String>>(
    context: context,
    showDragHandle: true,
    guardInput: true,
    builder: (_) => _TagPickerSheet(current: current, draftScope: draftScope),
  );
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.current, this.draftScope});

  final List<String> current;

  /// Id khách — nháp chỉ mời lại đúng khách đó.
  final String? draftScope;

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
      } else {
        _selected.add(tag);
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

  // Tính lại từ widget (không từ _selected — `late` chỉ chạy khi đọc lần đầu,
  // lúc đó _selected có thể đã đổi).
  late final List<String> _initial = _dedupe(widget.current.map(_canon));

  bool get _isDirty =>
      _input.text.trim().isNotEmpty ||
      _selected.length != _initial.length ||
      !_selected.every(_initial.contains);

  @override
  Widget build(BuildContext context) {
    // Sheet ngắn: đóng khi đã đổi nhãn / đang gõ nhãn mới → hỏi trong sheet.
    // "Xong" trả danh sách (khác null) nên nháp tự xoá.
    return OmniSheetGuard(
      draftKind: 'customers.tags.pick',
      draftScope: widget.draftScope,
      length: OmniSheetLength.short,
      listenable: _input,
      isDirty: () => _isDirty,
      toDraft: () => {
        'selected': List<String>.of(_selected),
        'options': List<String>.of(_options),
        'input': _input.text,
      },
      onRestore: (d) => setState(() {
        final options = [
          for (final o in (d['options'] as List?) ?? const []) '$o',
        ];
        for (final o in options) {
          if (!_options.any((x) => x.toLowerCase() == o.toLowerCase())) {
            _options.add(o);
          }
        }
        _selected
          ..clear()
          ..addAll([
            for (final s in (d['selected'] as List?) ?? const []) '$s',
          ]);
        _input.text = d['input'] as String? ?? '';
      }),
      summary: () => _selected.join(', '),
      discardPrompt: 'Bỏ thay đổi nhãn?',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return OmniSheetBody(
      // Đầu sheet tự có nút ✕ tròn xám (spec phong cách iOS §3.4).
      header: const OmniSheetHeader(title: 'Chọn nhãn'),
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop(List<String>.of(_selected)),
        child: const Text('Xong'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 38,
          children: [
            for (final tag in _options)
              OmniGroupRow(
                leading: Semantics(
                  label: 'Nhãn: $tag',
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: OmniLabelColors.of(tag),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                title: tag,
                chevron: false,
                selected: _selected.contains(tag),
                onTap: () => _toggle(tag),
              ),
          ],
        ),
        OmniGroupSection(
          title: 'Nhãn mới',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên nhãn mới…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  TextButton(
                    onPressed: _add,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: OmniGlass.selectionOf(context),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Thêm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
