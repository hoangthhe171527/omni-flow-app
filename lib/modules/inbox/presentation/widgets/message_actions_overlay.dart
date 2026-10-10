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

/// Sáu cảm xúc nội bộ trên thanh của menu bấm giữ (`Thread.dc.html`). Đều
/// ngoài ASCII — đúng luật `emoji` của `POST …/team-reactions`.
const kTeamReactionChoices = ['👍', '❤️', '😂', '😮', '🙏', '✅'];

/// Bấm giữ một tin → lớp mờ + (thanh cảm xúc) + bong bóng nổi lên + menu kính
/// bên dưới.
///
/// Thanh cảm xúc chỉ hiện khi có [onReact]: đó là cảm xúc NỘI BỘ của đội
/// (`team_reactions`), không gửi cho khách. Chọn một emoji thì đóng hộp rồi
/// gọi [onReact]; [myReaction] (emoji tôi đang thả) có nền nhấn — chọn lại nó
/// là bỏ.
Future<void> showMessageActions({
  required BuildContext context,
  required Widget bubble,
  required bool outbound,
  required List<MessageActionItem> items,
  String? myReaction,
  ValueChanged<String>? onReact,
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
      myReaction: myReaction,
      onReact: onReact == null
          ? null
          : (emoji) {
              Navigator.pop(dialogContext);
              onReact(emoji);
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
    this.myReaction,
    this.onReact,
  });

  final Widget bubble;
  final bool outbound;
  final List<MessageActionItem> items;
  final ValueChanged<MessageActionItem> onSelected;
  final String? myReaction;
  final ValueChanged<String>? onReact;

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
                      if (onReact != null) ...[
                        _ReactionBar(selected: myReaction, onPick: onReact!),
                        const SizedBox(height: 8),
                      ],
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

/// Thanh 6 cảm xúc trên bong bóng nổi: khung bo 24, nền trắng .92 (tối:
/// `surfaceContainerHigh` .92), mỗi nút 44×44 (bản mẫu 36 — guard vùng chạm
/// thắng). Các nút "nảy" vào lệch nhau 30ms (`pop .35s`), tắt khi giảm chuyển
/// động.
class _ReactionBar extends StatefulWidget {
  const _ReactionBar({required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar>
    with SingleTickerProviderStateMixin {
  static const _pop = Duration(milliseconds: 350);
  static const _stagger = Duration(milliseconds: 30);
  static const _curve = Cubic(.2, .8, .2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pop + _stagger * (kTeamReactionChoices.length - 1),
  );
  bool _started = false;

  // Dựng một lần: CurvedAnimation tự gắn listener vào controller.
  late final _scales = [
    for (var i = 0; i < kTeamReactionChoices.length; i++) _scaleAt(i),
  ];
  late final _opacities = [
    for (var i = 0; i < kTeamReactionChoices.length; i++) _opacityAt(i),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OmniMotion.enabled(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `pop`: 0% ×.4 mờ → 70% ×1.1 → 100% ×1.
  Animation<double> _scaleAt(int index) {
    final total = _controller.duration!.inMilliseconds;
    final start = (_stagger * index).inMilliseconds / total;
    final end = (_stagger * index + _pop).inMilliseconds / total;
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: .4, end: 1.1), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: _curve),
      ),
    );
  }

  Animation<double> _opacityAt(int index) {
    final total = _controller.duration!.inMilliseconds;
    final start = (_stagger * index).inMilliseconds / total;
    final end = (_stagger * index + _pop * .7).inMilliseconds / total;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedBg = OmniColors.byBrightness(
      context,
      OmniColors.accent,
      OmniColors.darkAccent,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: OmniColors.byBrightness(
          context,
          Colors.white,
          scheme.surfaceContainerHigh,
        ).withValues(alpha: .92),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400B1A33),
            offset: Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < kTeamReactionChoices.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                FadeTransition(
                  opacity: _opacities[i],
                  child: ScaleTransition(
                    scale: _scales[i],
                    child: _ReactionButton(
                      emoji: kTeamReactionChoices[i],
                      selected: kTeamReactionChoices[i] == widget.selected,
                      selectedColor: selectedBg,
                      onTap: () => widget.onPick(kTeamReactionChoices[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Bỏ cảm xúc $emoji' : 'Thả cảm xúc $emoji',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('reaction-choice-$emoji'),
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedColor : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(emoji, style: OmniChatType.reaction),
        ),
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
