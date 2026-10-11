import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';

/// Header kính sáng của chi tiết việc (`TaskDetail.dc.html` `.bar`).
///
/// ✕ 44 bên trái; giữa là tên việc 15 w600, mờ 0 cho tới khi dòng tiêu đề
/// trong thân cuộn khuất dưới header ([titleShown]); phải là [menu] (⋯).
/// Nút "Người theo dõi" của bản mẫu thuộc Nhóm 2: API chưa có khoá nên
/// không vẽ.
class DetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.titleShown,
    this.menu,
  });

  static const double height = 48;

  final String title;
  final ValueListenable<bool> titleShown;

  /// Nút ⋯ (đã có vùng chạm 44). null = không có mục nào cho người này.
  final Widget? menu;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = OmniColors.byBrightness(
      context,
      OmniColors.background.withValues(alpha: 0.82),
      OmniColors.darkBackground.withValues(alpha: 0.82),
    );
    final duration = OmniMotion.enabled(context)
        ? OmniDuration.base
        : Duration.zero;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass,
            border: Border(
              bottom: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        maximumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        foregroundColor: scheme.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: OmniIconSize.xl - 2,
                      ),
                    ),
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
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    menu ?? const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
