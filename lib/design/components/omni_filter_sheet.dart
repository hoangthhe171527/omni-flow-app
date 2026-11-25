import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'omni_group.dart';
import 'omni_inputs.dart';

/// Một lựa chọn trong [OmniFilterGroup].
@immutable
class OmniFilterOption {
  const OmniFilterOption(this.id, this.label);
  final String id;
  final String label;
}

/// Một nhóm điều kiện của sheet lọc: tiêu đề + các chip.
@immutable
class OmniFilterGroup {
  const OmniFilterGroup({
    required this.id,
    required this.title,
    required this.options,
    this.multi = false,
  });

  final String id;
  final String title;
  final List<OmniFilterOption> options;

  /// Chọn nhiều trong nhóm. Mặc định chọn một (chạm lại để bỏ).
  final bool multi;
}

/// Lựa chọn của sheet lọc: id nhóm → các id lựa chọn đang bật.
typedef OmniFilterSelection = Map<String, Set<String>>;

/// Số điều kiện đang áp — cho chấm / số trên nút lọc.
int omniFilterCount(OmniFilterSelection selection) =>
    selection.values.fold(0, (n, s) => n + s.length);

/// Sheet lọc DÙNG CHUNG cho mọi danh sách (Chuẩn Mobile UI — FilterSheet).
///
/// Đầu: "Lọc" + "Xoá hết". Nhóm: tiêu đề HOA nhỏ + chip chọn ([OmniChoicePill]).
/// Đáy: nút chính "Xem N kết quả" — số cập nhật sống qua [countResults]; 0
/// kết quả thì nút khoá. Áp khi bấm nút; kéo xuống / ✕ = huỷ (trả `null`).
///
/// Sắp xếp là một nhóm trong sheet này, không phải nút riêng. Tối đa ~4 nhóm.
Future<OmniFilterSelection?> showOmniFilterSheet({
  required BuildContext context,
  required List<OmniFilterGroup> groups,
  OmniFilterSelection initial = const {},
  String title = 'Lọc',
  int Function(OmniFilterSelection selection)? countResults,
  String resultNoun = 'kết quả',
}) {
  return showOmniSheet<OmniFilterSelection>(
    context: context,
    builder: (_) => _OmniFilterSheet(
      groups: groups,
      initial: initial,
      title: title,
      countResults: countResults,
      resultNoun: resultNoun,
    ),
  );
}

class _OmniFilterSheet extends StatefulWidget {
  const _OmniFilterSheet({
    required this.groups,
    required this.initial,
    required this.title,
    required this.countResults,
    required this.resultNoun,
  });

  final List<OmniFilterGroup> groups;
  final OmniFilterSelection initial;
  final String title;
  final int Function(OmniFilterSelection selection)? countResults;
  final String resultNoun;

  @override
  State<_OmniFilterSheet> createState() => _OmniFilterSheetState();
}

class _OmniFilterSheetState extends State<_OmniFilterSheet> {
  late final OmniFilterSelection _sel = {
    for (final g in widget.groups) g.id: {...?widget.initial[g.id]},
  };

  void _toggle(OmniFilterGroup g, OmniFilterOption o) {
    setState(() {
      final s = _sel[g.id]!;
      if (s.contains(o.id)) {
        s.remove(o.id);
      } else {
        if (!g.multi) s.clear();
        s.add(o.id);
      }
    });
  }

  OmniFilterSelection get _result => {
    for (final e in _sel.entries)
      if (e.value.isNotEmpty) e.key: {...e.value},
  };

  @override
  Widget build(BuildContext context) {
    final count = widget.countResults?.call(_result);
    final any = omniFilterCount(_sel) > 0;
    final label = count == null
        ? 'Áp dụng'
        : count == 0
        ? 'Không có ${widget.resultNoun}'
        : 'Xem $count ${widget.resultNoun}';

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.title,
        trailing: TextButton(
          onPressed: any
              ? () => setState(() {
                  for (final s in _sel.values) {
                    s.clear();
                  }
                })
              : null,
          child: const Text('Xoá hết'),
        ),
      ),
      footer: FilledButton(
        onPressed: count == 0 ? null : () => Navigator.of(context).pop(_result),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(label),
      ),
      children: [
        for (final g in widget.groups)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OmniGroupHeader(title: g.title),
                Wrap(
                  spacing: OmniSpacing.sm,
                  runSpacing: OmniSpacing.sm,
                  children: [
                    for (final o in g.options)
                      OmniChoicePill(
                        label: o.label,
                        selected: _sel[g.id]!.contains(o.id),
                        onTap: () => _toggle(g, o),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
