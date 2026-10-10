import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Một mục trong menu bấm giữ tin.
class MessageActionItem {
  const MessageActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Mép trên của bong bóng nổi theo bản mẫu (`Thread.dc.html`), thu lại khi màn
/// thấp để menu vẫn nằm gọn.
const _bubbleTop = 260.0;
const _menuWidth = 220.0;
const _rowHeight = 44.0;

Color _ink(BuildContext context) => OmniColors.byBrightness(
  context,
  const Color(0xFF0B1A33),
  Theme.of(context).colorScheme.onSurface,
);

/// Bấm giữ một tin → lớp mờ + bong bóng nổi lên + menu kính bên dưới.
///
/// KHÔNG có thanh cảm xúc và không bắt bấm đúp: API cảm xúc chưa có, một nút
/// bấm vào rồi mất lặng lẽ tệ hơn không có nút.
Future<void> showMessageActions({
  required BuildContext context,
  required Widget bubble,
  required bool outbound,
  required List<MessageActionItem> items,
}) {
  final motion = OmniMotion.enabled(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng menu tin nhắn',
    barrierColor: const Color(0x590B1A33),
    transitionDuration: motion
        ? const Duration(milliseconds: 400)
        : Duration.zero,
    pageBuilder: (dialogContext, _, _) => _MessageActionsOverlay(
      bubble: bubble,
      outbound: outbound,
      items: items,
      onSelected: (item) {
        Navigator.pop(dialogContext);
        item.onTap();
      },
    ),
    transitionBuilder: (context, animation, _, child) {
      if (!motion) return child;
      // Độ mờ đi đường thẳng (phải nằm trong 0..1); chỉ độ co dùng đường cong
      // "nảy" cubic-bezier(.2,1.1,.3,1).
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .88, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Cubic(.2, 1.1, .3, 1),
            ),
          ),
          alignment: Alignment(outbound ? .6 : -.6, -.3),
          child: child,
        ),
      );
    },
  );
}

class _MessageActionsOverlay extends StatelessWidget {
  const _MessageActionsOverlay({
    required this.bubble,
    required this.outbound,
    required this.items,
    required this.onSelected,
  });

  final Widget bubble;
  final bool outbound;
  final List<MessageActionItem> items;
  final ValueChanged<MessageActionItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final top = math.min(_bubbleTop, height * .22);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Không có con: không nuốt chạm, để rào chắn của route đóng hộp.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            ),
          ),
          Positioned.fill(
            // Bọc NGOÀI vùng cuộn: vùng cuộn phủ cả màn nên nuốt chạm trước cả
            // rào chắn của route; bấm vào khoảng trống phải tự đóng.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(8, top, 8, 16),
                  child: Column(
                    crossAxisAlignment: outbound
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Bong bóng chỉ để nhìn: chạm vào nó không mở ảnh hay liên
                      // kết phía sau lớp mờ.
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0B1A33,
                                  ).withValues(alpha: dark ? .5 : .3),
                                  offset: const Offset(0, 14),
                                  blurRadius: 34,
                                ),
                              ],
                            ),
                            child: bubble,
                          ),
                        ),
                      ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _GlassMenu(
                            items: items,
                            onSelected: onSelected,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassMenu extends StatelessWidget {
  const _GlassMenu({required this.items, required this.onSelected});

  final List<MessageActionItem> items;
  final ValueChanged<MessageActionItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: OmniColors.byBrightness(
              context,
              OmniColors.ink.withAlpha(0x40),
              Colors.black.withAlpha(0x80),
            ),
            offset: Offset(0, 16),
            blurRadius: 40,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: _menuWidth,
            color: OmniColors.byBrightness(
              context,
              Colors.white,
              scheme.surfaceContainerHigh,
            ).withValues(alpha: .9),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                    InkWell(
                      onTap: () => onSelected(items[i]),
                      child: SizedBox(
                        height: _rowHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  items[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OmniType.body.copyWith(
                                    color: _ink(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                items[i].icon,
                                size: 18,
                                color: _ink(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
