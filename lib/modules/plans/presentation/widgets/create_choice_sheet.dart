import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Hai thứ tạo được từ gốc tab Việc.
enum CreateChoice { team, plan }

/// Menu của nút + (`TeamsAdd.dc.html`): lớp phủ mờ, hộp 220 bo 8 bật xuống
/// ngay dưới nút, neo theo mép phải của nút ([anchor], toạ độ màn).
///
/// "Tạo team" chỉ có khi [canCreateTeam]: tạo team LÀ tạo một đơn vị trong cơ
/// cấu tổ chức, API đòi quyền org tương ứng, và bày ra một dòng bấm vào là 403
/// tệ hơn không bày.
///
/// Lớp phủ `fade` 200ms, hộp `pop` 280ms gốc trên-phải. Giảm chuyển động: hiện
/// và tắt ngay.
Future<CreateChoice?> showCreateMenu(
  BuildContext context, {
  required Rect anchor,
  required bool canCreateTeam,
}) {
  final motion = OmniMotion.enabled(context);

  return Navigator.of(context).push<CreateChoice>(
    _CreateMenuRoute(
      anchor: anchor,
      canCreateTeam: canCreateTeam,
      duration: motion ? _popDuration : Duration.zero,
    ),
  );
}

const _popDuration = Duration(milliseconds: 280);
const _fadeDuration = Duration(milliseconds: 200);

/// cubic-bezier(.2,.9,.25,1) của `pop` và `sheet`.
const _popCurve = Cubic(0.2, 0.9, 0.25, 1);

class _CreateMenuRoute extends PopupRoute<CreateChoice> {
  _CreateMenuRoute({
    required this.anchor,
    required this.canCreateTeam,
    required this.duration,
  });

  final Rect anchor;
  final bool canCreateTeam;
  final Duration duration;

  @override
  Color? get barrierColor => null;

  // Lớp phủ tự vẽ (có blur) và tự đóng khi chạm.
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.sizeOf(context);
    final fade = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0,
        _fadeDuration.inMilliseconds / _popDuration.inMilliseconds,
      ),
    );
    final pop = CurvedAnimation(parent: animation, curve: _popCurve);
    final scrim = OmniColors.byBrightness(
      context,
      OmniColors.ink.withValues(alpha: .22),
      Colors.black.withValues(alpha: .4),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: 'Đóng',
            onTap: () => Navigator.of(context).pop(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: FadeTransition(
                opacity: fade,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: ColoredBox(color: scrim),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: anchor.bottom + 6,
          right: size.width - anchor.right,
          child: AnimatedBuilder(
            animation: pop,
            builder: (context, child) {
              final t = pop.value;

              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Transform.scale(
                    scale: .96 + .04 * t,
                    alignment: Alignment.topRight,
                    child: child,
                  ),
                ),
              );
            },
            child: _CreateMenu(canCreateTeam: canCreateTeam),
          ),
        ),
      ],
    );
  }
}

class _CreateMenu extends StatelessWidget {
  const _CreateMenu({required this.canCreateTeam});

  final bool canCreateTeam;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(8));

    return Container(
      key: const Key('create-menu'),
      width: 220,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 12),
            blurRadius: 32,
            color: OmniColors.ink.withValues(alpha: .18),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Tạo mới',
          explicitChildNodes: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canCreateTeam)
                _MenuItem(
                  icon: Icons.person_add_alt_outlined,
                  label: 'Tạo team',
                  onTap: () => Navigator.of(context).pop(CreateChoice.team),
                ),
              _MenuItem(
                icon: Icons.view_kanban_outlined,
                label: 'Tạo kế hoạch',
                divider: canCreateTeam,
                onTap: () => Navigator.of(context).pop(CreateChoice.plan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniPressScale(
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: divider
              ? BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.surfaceContainerHighest),
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
