import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';

/// Thanh trên của chi tiết việc, kiểu nút kính rời (viomni-apple-uiux.html,
/// màn "Chi tiết việc", duyệt 07/11).
///
/// ✕, "Người theo dõi" ([followers]) và ⋯ ([menu]) là các viên kính tròn 44
/// trôi trên nội dung; nội dung cuộn dưới thanh nhoè dần ([OmniScrollEdge])
/// kèm dải nền chuyển sắc mờ bảo vệ độ đọc. Giữa là tên việc bọc trong viên
/// thuốc kính gọn, chỉ hiện khi dòng tiêu đề trong thân đã khuất dưới thanh
/// ([titleShown]).
class DetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.titleShown,
    this.menu,
    this.followers,
  });

  /// Đệm trên 4 + nút 44 + đệm dưới 8.
  static const double height = 56;

  final String title;
  final ValueListenable<bool> titleShown;

  /// Nút ⋯ (vùng chạm 44). null = không có mục nào cho người này.
  final Widget? menu;

  /// Nút "Người theo dõi" (vùng chạm 44). null = API chưa có khả năng.
  final Widget? followers;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  void _handleClose(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.maybePop();
    } else {
      GoRouter.maybeOf(context)?.go('/tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;
    final duration = OmniMotion.enabled(context)
        ? OmniDuration.base
        : Duration.zero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: OmniScrollEdge(atTop: true)),
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: titleShown,
              builder: (context, shown, _) => AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: duration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.68, 1],
                      colors: [
                        bg.withValues(alpha: 0.96),
                        bg.withValues(alpha: 0.82),
                        bg.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  OmniTopBarAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Đóng',
                    onPressed: () => _handleClose(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: titleShown,
                      builder: (context, shown, _) => IgnorePointer(
                        ignoring: !shown,
                        child: AnimatedOpacity(
                          opacity: shown ? 1 : 0,
                          duration: duration,
                          child: Center(
                            child: OmniGlass(
                              blur: false,
                              radius: 999,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                title,
                                key: const ValueKey('header-title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: OmniType.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (followers case final button?) ...[
                    OmniGlassCircle(child: button),
                    const SizedBox(width: 8),
                  ],
                  if (menu case final button?)
                    OmniGlassCircle(child: button)
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
