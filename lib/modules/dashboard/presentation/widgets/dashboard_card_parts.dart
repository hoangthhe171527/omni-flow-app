/// Mảnh dùng chung của các thẻ danh sách trên Tổng quan.
library;

import 'package:flutter/material.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

/// Nút "Xem tất cả" cuối thẻ, cao 44.
class DashboardSeeAll extends StatelessWidget {
  const DashboardSeeAll({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed: onPressed,
      child: const Text('Xem tất cả'),
    ),
  );
}

/// Dòng chữ nhạt khi thẻ không có gì.
class DashboardEmptyLine extends StatelessWidget {
  const DashboardEmptyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
    child: Text(
      text,
      style: OmniType.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Khung xương ba dòng lúc thẻ đang tải.
class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Column(
      children: [
        OmniSkeletonBox(height: 36),
        SizedBox(height: 8),
        OmniSkeletonBox(height: 36),
        SizedBox(height: 8),
        OmniSkeletonBox(height: 36),
      ],
    ),
  );
}

/// Lỗi gọn trong thẻ: một dòng + "Thử lại", không ảnh hưởng thẻ khác.
class DashboardCardError extends StatelessWidget {
  const DashboardCardError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = OmniColors.dangerTextOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              humanError(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(color: color),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
