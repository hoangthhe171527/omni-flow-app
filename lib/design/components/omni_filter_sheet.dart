import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'omni_group.dart';
import 'omni_inputs.dart';
import 'omni_pills.dart';

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
/// Bảng lọc thống nhất (duyệt 26/11/2026, rà soát mục 7): đầu "Lọc" 17/700 +
/// "Đặt lại" chữ màu chính ([OmniFilterHeader]); nhóm: nhãn chữ HOA 12/700 xám
/// ([OmniFilterGroupLabel]) + chip viên mực đặc ([OmniFilterPill]); bảng bo 24.
/// Đáy: nút chính "Xem N kết quả" — số cập nhật sống qua [countResults]; 0
/// kết quả thì nút khoá. Áp khi bấm nút; kéo xuống = huỷ (trả `null`).
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
    radius: OmniFilterHeader.sheetRadius,
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
      header: OmniFilterHeader(
        title: widget.title,
        padding: const EdgeInsets.fromLTRB(22, 4, 12, 4),
        onReset: any
            ? () => setState(() {
                for (final s in _sel.values) {
                  s.clear();
                }
              })
            : null,
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
                OmniFilterGroupLabel(
                  title: g.title,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: OmniSpacing.sm,
                    children: [
                      for (final o in g.options)
                        OmniFilterPill(
                          label: o.label,
                          selected: _sel[g.id]!.contains(o.id),
                          onTap: () => _toggle(g, o),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Đầu bảng lọc DÙNG CHUNG (duyệt 26/11/2026): "Lọc" 17/700 bên trái, "Đặt
/// lại" chữ màu chính bên phải — thay icon + nút ✕. [onReset] null = chưa có
/// gì để đặt lại (nút mờ). Bảng lọc nổi (menu neo) đóng bằng chạm ra ngoài,
/// sheet đóng bằng kéo xuống.
class OmniFilterHeader extends StatelessWidget {
  const OmniFilterHeader({
    super.key,
    this.title = 'Lọc',
    required this.onReset,
    this.resetKey,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 6, 0),
  });

  /// Bo góc của bảng lọc dạng sheet.
  static const double sheetRadius = 24;

  final String title;
  final VoidCallback? onReset;

  /// Khoá của nút "Đặt lại" (test tìm theo khoá).
  final Key? resetKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.navTitle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            TextButton(
              key: resetKey,
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: OmniType.body.copyWith(fontWeight: FontWeight.w500),
              ),
              child: const Text('Đặt lại'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhóm của bảng lọc: chữ HOA 12/700 xám, giãn chữ .06em (duyệt
/// 26/11/2026). Trình đọc màn hình đọc chữ thường.
class OmniFilterGroupLabel extends StatelessWidget {
  const OmniFilterGroupLabel({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(bottom: 4),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        label: title,
        excludeSemantics: true,
        child: Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.72,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
