import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tokens/tokens.dart';
import 'brand_anchor.dart';
import 'omni_app_bar.dart';
import 'omni_brand.dart';

/// Chỗ cắm cho phần của [OmniTopBar] thuộc về `modules/`: số thông báo chưa đọc
/// và nơi nút chuông dẫn tới. Cùng lý do với [OmniAccountSlot] — `design/` chỉ
/// được phụ thuộc `core/`, nên app cắm nội dung vào một lần ở gốc.
class OmniTopBarSlot extends InheritedWidget {
  const OmniTopBarSlot({
    super.key,
    required this.unreadOf,
    required this.onBell,
    required super.child,
  });

  /// Số thông báo chưa đọc; được gọi trong `build` nên có thể `ref.watch`.
  final int Function(WidgetRef ref) unreadOf;

  /// Mở trung tâm thông báo.
  final void Function(BuildContext context) onBell;

  static OmniTopBarSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniTopBarSlot>();

  @override
  bool updateShouldNotify(OmniTopBarSlot oldWidget) =>
      unreadOf != oldWidget.unreadOf || onBell != oldWidget.onBell;
}

/// Header chung của ba tab gốc: logo bên trái, chuông + tài khoản bên phải, và
/// (tuỳ màn) ô tìm / bộ lọc xếp dưới. Nền kính mờ như thanh tab dưới.
class OmniTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const OmniTopBar({super.key, this.bottom});

  /// Ô tìm, bộ lọc, nút riêng của màn. Cần biết chiều cao để Scaffold chừa chỗ.
  final PreferredSizeWidget? bottom;

  static const double _rowHeight = 36;
  static const double _topPad = 8;
  static const double _bottomPad = 10;

  @override
  Size get preferredSize => Size.fromHeight(
    _topPad +
        _rowHeight +
        _bottomPad +
        (bottom == null ? 0 : bottom!.preferredSize.height),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final slot = OmniTopBarSlot.maybeOf(context);
    final unread = slot?.unreadOf(ref) ?? 0;
    final account = OmniAccountSlot.maybeTileOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    _topPad,
                    16,
                    _bottomPad,
                  ),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        BrandAnchor(
                          withWordmark: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const OmniBrandMark(size: 30),
                              const SizedBox(width: 8),
                              OmniWordmark(fontSize: 19, onInk: dark),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _BellButton(
                          unread: unread,
                          onTap: slot == null
                              ? null
                              : () => slot.onBell(context),
                        ),
                        if (account != null) ...[
                          const SizedBox(width: 8),
                          account(context),
                        ],
                      ],
                    ),
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: unread > 0 ? 'Thông báo, $unread chưa đọc' : 'Thông báo',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: scheme.outline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox.square(
            dimension: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: OmniIconSize.md,
                  color: scheme.onSurface,
                ),
                if (unread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      key: const ValueKey('omni-top-bar-bell-dot'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
