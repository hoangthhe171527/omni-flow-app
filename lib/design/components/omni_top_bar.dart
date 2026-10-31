import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/omni_platform.dart';
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

  /// Mở menu thông báo nhanh, neo vào hình chữ nhật của nút chuông.
  final void Function(BuildContext context, Rect anchor) onBell;

  static OmniTopBarSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniTopBarSlot>();

  @override
  bool updateShouldNotify(OmniTopBarSlot oldWidget) =>
      unreadOf != oldWidget.unreadOf || onBell != oldWidget.onBell;
}

/// Header chung của ba tab gốc: logo bên trái, chuông + tài khoản bên phải, và
/// (tuỳ màn) ô tìm / bộ lọc xếp dưới. Nền kính mờ như thanh tab dưới.
class OmniTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const OmniTopBar({
    super.key,
    this.bottom,
    this.semanticsTitle,
    this.allowBack = false,
  });

  /// Ô tìm, bộ lọc, nút riêng của màn. Cần biết chiều cao để Scaffold chừa chỗ.
  final PreferredSizeWidget? bottom;

  /// Tên trang cho trình đọc màn hình ("Hộp thư", "Khách"…). Logo luôn đọc là
  /// "Viomni", nên không có nó thì tiêu đề trang không tồn tại với người dùng
  /// TalkBack/VoiceOver. Vô hình: chỉ thêm một nút `header` vào cây ngữ nghĩa.
  final String? semanticsTitle;

  /// Hiện nút quay lại (44x44) bên trái logo khi màn này được đẩy lên stack
  /// (`ModalRoute.of(context)?.canPop == true`), ví dụ `PipelinePage` mở từ
  /// danh bạ "Tất cả".
  final bool allowBack;

  // Hàng 1 cao 44 để chuông/avatar (vẽ 36) có vùng chạm 44; tổng 54 như cũ.
  static const double _rowHeight = 44;
  static const double _topPad = 4;
  static const double _bottomPad = 6;

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
    final showBack = allowBack && (ModalRoute.of(context)?.canPop ?? false);

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
                  // Phải 12 chứ không 16: ô avatar rộng 44 mà vẽ 36, 4dp đệm
                  // trong ô giữ mép vẽ ở đúng 16.
                  padding: EdgeInsets.fromLTRB(
                    showBack ? 4 : 16,
                    _topPad,
                    12,
                    _bottomPad,
                  ),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Stack(
                      children: [
                        // Phủ cả hàng: một nút ngữ nghĩa rỗng (0x0) bị bỏ khỏi
                        // cây, nên tiêu đề phải có hình chữ nhật thật.
                        if (semanticsTitle != null)
                          Positioned.fill(
                            child: Semantics(
                              header: true,
                              container: true,
                              label: semanticsTitle,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        Row(
                          children: [
                            if (showBack)
                              SizedBox.square(
                                dimension: 44,
                                child: IconButton(
                                  tooltip: 'Quay lại',
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).maybePop();
                                  },
                                  icon: Icon(
                                    isApple(context)
                                        ? Icons.arrow_back_ios_new_rounded
                                        : Icons.arrow_back_rounded,
                                    size: OmniIconSize.md,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            BrandAnchor(
                              withWordmark: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const OmniBrandMark(size: 30, framed: false),
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
                                  : (anchor) {
                                      HapticFeedback.selectionClick();
                                      slot.onBell(context, anchor);
                                    },
                            ),
                            // Hai ô 44 kề nhau: khoảng 8 giữa hai hình 36 đã nằm
                            // trong đệm của chúng.
                            if (account != null) account(context),
                          ],
                        ),
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

class _BellButton extends StatefulWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final ValueChanged<Rect>? onTap;

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  final _buttonKey = GlobalKey(debugLabel: 'OmniTopBarBell');

  void _open() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    widget.onTap?.call(origin & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.unread > 0
          ? 'Thông báo, ${widget.unread} chưa đọc'
          : 'Thông báo',
      excludeSemantics: true,
      onTap: widget.onTap == null ? null : _open,
      // Chỉ vẽ icon; toàn ô 44 là vùng chạm.
      child: GestureDetector(
        key: _buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _open,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            key: const ValueKey('omni-top-bar-bell-face'),
            color: Colors.transparent,
            child: InkResponse(
              onTap: widget.onTap == null ? null : _open,
              radius: 22,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurface,
                  ),
                  if (widget.unread > 0)
                    Positioned(
                      right: 9,
                      top: 9,
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
      ),
    );
  }
}
