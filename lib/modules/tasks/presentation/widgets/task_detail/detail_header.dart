import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';

/// Thanh trên của chi tiết việc, kiểu nút kính rời (viomni-apple-uiux.html,
/// màn "Chi tiết việc", duyệt 07/11).
///
/// Không còn dải nền: ✕, "Người theo dõi" ([followers]) và ⋯ ([menu]) là các
/// viên kính tròn 44 trôi trên nội dung; nội dung cuộn dưới thanh thì nhoè dần
/// ([OmniScrollEdge]). Giữa là tên việc 15 w600, chỉ hiện khi dòng tiêu đề
/// trong thân đã khuất dưới thanh ([titleShown]).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = OmniMotion.enabled(context)
        ? OmniDuration.base
        : Duration.zero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: OmniScrollEdge(atTop: true)),
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
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: titleShown,
                      builder: (context, shown, _) => AnimatedOpacity(
                        opacity: shown ? 1 : 0,
                        duration: duration,
                        child: Text(
                          title,
                          key: const ValueKey('header-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: OmniType.bodyStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
