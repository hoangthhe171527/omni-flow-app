import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Hàng thứ hai của header tab Việc: ô tìm team/kế hoạch và nút **+** đều
/// phẳng, không dựng thêm khung trang trí quanh điều khiển.
///
/// Khi menu mở ([addOpen]), biểu tượng xoay 45° thành × trong 300ms. Icon chỉ
/// cao 40 nhưng vùng chạm phủ cả 8px đệm đáy, thành 44×48.
class TeamsSearchRow extends StatefulWidget implements PreferredSizeWidget {
  const TeamsSearchRow({
    super.key,
    required this.controller,
    required this.onChanged,
    this.showAdd = false,
    this.addOpen = false,
    this.onAdd,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showAdd;
  final bool addOpen;

  /// Nhận hình chữ nhật (toạ độ màn) của nút để neo menu ngay dưới nó.
  final ValueChanged<Rect>? onAdd;

  static const double _fieldHeight = 40;
  static const double _bottomPad = 8;

  @override
  Size get preferredSize => const Size.fromHeight(_fieldHeight + _bottomPad);

  @override
  State<TeamsSearchRow> createState() => _TeamsSearchRowState();
}

class _TeamsSearchRowState extends State<TeamsSearchRow> {
  late bool _hasText = widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(TeamsSearchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _hasText = widget.controller.text.isNotEmpty;
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: TeamsSearchRow._fieldHeight + TeamsSearchRow._bottomPad,
      child: Padding(
        // Bản mẫu: header đệm phải 8 + hàng tìm đệm phải 8 = mép phải 16.
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                key: const Key('teams-search-box'),
                height: TeamsSearchRow._fieldHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          onChanged: widget.onChanged,
                          textInputAction: TextInputAction.search,
                          style: OmniType.search.copyWith(
                            color: scheme.onSurface,
                            fontStyle: FontStyle.normal,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Tìm team, kế hoạch',
                            hintStyle: OmniType.searchHint.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showAdd) ...[
              const SizedBox(width: 8),
              _AddButton(open: widget.addOpen, onAdd: widget.onAdd),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.open, required this.onAdd});

  final bool open;
  final ValueChanged<Rect>? onAdd;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  final _hitKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final open = widget.open;

    // Đo ô chạm (không co khi nhấn) rồi lấy phần vẽ 44×40 ở đỉnh của nó.
    void tap() {
      final onAdd = widget.onAdd;
      final box = _hitKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || onAdd == null) return;
      onAdd(
        box.localToGlobal(Offset.zero) &
            Size(box.size.width, TeamsSearchRow._fieldHeight),
      );
    }

    return Semantics(
      button: true,
      label: 'Tạo mới',
      expanded: open,
      excludeSemantics: true,
      onTap: tap,
      // Co khi nhấn bọc NGOÀI vùng chạm: recognizer tap trong cùng thắng arena,
      // nên OmniPressScale bên trong sẽ nuốt mất cú chạm mở menu.
      child: OmniPressScale(
        child: GestureDetector(
          key: const Key('teams-add-hit'),
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: SizedBox(
            key: _hitKey,
            width: 44,
            height: TeamsSearchRow._fieldHeight + TeamsSearchRow._bottomPad,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const Key('teams-add-face'),
                width: 44,
                height: TeamsSearchRow._fieldHeight,
                child: AnimatedRotation(
                  turns: open ? 0.125 : 0,
                  duration: motion
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  curve: OmniCurves.standard,
                  child: Icon(
                    key: const Key('teams-add-icon'),
                    Icons.add_rounded,
                    size: 24,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
