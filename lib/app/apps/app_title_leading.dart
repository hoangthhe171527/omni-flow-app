import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';

/// Đầu thanh trên của màn gốc trong một ứng dụng (khung ứng dụng): nút kính ô
/// lưới, tên ứng dụng nhỏ và tên màn. Chạm nút hay tên ứng dụng đều về màn Chọn
/// ứng dụng. [onSwitch] null (người chỉ có một ô) thì không có nút, chỉ chữ.
class AppTitleLeading extends StatelessWidget {
  const AppTitleLeading({
    super.key,
    required this.appName,
    required this.title,
    this.onSwitch,
  });

  final String appName;
  final String? title;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSwitch = this.onSwitch;
    void tap() {
      HapticFeedback.selectionClick();
      onSwitch?.call();
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (title case final t? when t.isNotEmpty)
          Semantics(
            header: true,
            child: Text(
              t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.navTitle.copyWith(color: scheme.onSurface),
            ),
          ),
      ],
    );

    return Row(
      children: [
        if (onSwitch != null) ...[
          OmniGlassCircle(
            child: IconButton(
              key: const ValueKey('app-switch-button'),
              tooltip: 'Đổi ứng dụng',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: tap,
              icon: Icon(
                Icons.grid_view_rounded,
                size: OmniIconSize.md,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: onSwitch == null
              ? text
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: tap,
                  child: text,
                ),
        ),
      ],
    );
  }
}
