import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Hàng thứ hai của header tab Việc (`Main.dc.html`): ô tìm team/kế hoạch cao
/// 40 nền xám bo 6, và nút vuông **+** 44×40 bo 6.
///
/// Nút + nền primary; khi menu của nó mở ([addOpen]) thì nền mực và biểu tượng
/// xoay 45° thành × trong 300ms. Hình vẽ cao 40 nhưng vùng chạm phủ cả 8px đệm
/// đáy, thành 44×48.
class TeamsSearchRow extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _fieldHeight + _bottomPad,
      child: Padding(
        // Bản mẫu: header đệm phải 8 + hàng tìm đệm phải 8 = mép phải 16.
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                key: const Key('teams-search-box'),
                height: _fieldHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
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
                        controller: controller,
                        onChanged: onChanged,
                        textInputAction: TextInputAction.search,
                        style: OmniType.bodySm.copyWith(
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Tìm team, kế hoạch',
                          hintStyle: OmniType.bodySm.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showAdd) ...[
              const SizedBox(width: 8),
              _AddButton(open: addOpen, onAdd: onAdd),
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
    final ink = OmniColors.byBrightness(
      context,
      OmniColors.ink,
      OmniColors.darkForeground,
    );
    final onInk = OmniColors.byBrightness(
      context,
      OmniColors.primaryForeground,
      OmniColors.ink,
    );
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
              child: AnimatedContainer(
                key: const Key('teams-add-face'),
                width: 44,
                height: TeamsSearchRow._fieldHeight,
                duration: motion ? OmniDuration.base : Duration.zero,
                curve: OmniCurves.standard,
                decoration: BoxDecoration(
                  color: open ? ink : scheme.primary,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: AnimatedRotation(
                  turns: open ? 0.125 : 0,
                  duration: motion
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  curve: OmniCurves.standard,
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: open ? onInk : scheme.onPrimary,
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
