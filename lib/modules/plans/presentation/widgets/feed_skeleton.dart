import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Khung xương của Dòng việc trong lúc tải lần đầu.
///
/// Trông như chính cái danh sách sắp hiện — một tiêu đề ngày rồi vài dòng
/// "avatar + hai dòng chữ + giờ" — để lúc dữ liệu tới, bố cục không nhảy.
/// Một vòng xoay giữa màn trắng nói "chưa có gì"; khung xương nói "sắp có,
/// và trông thế này". Đây là màn đầu tiên mở lên mỗi sáng nên đáng làm kỹ.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(OmniSpacing.lg),
      children: [
        // Tiêu đề ngày: một thanh ngắn, cùng chỗ với "Hôm nay · 3 việc".
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OmniSkeletonBox(
              height: 12,
              width: 132,
              radius: OmniRadius.xs,
            ),
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        OmniGroupSection(
          dividerIndent: 52,
          children: [for (var i = 0; i < rows; i++) const _RowSkeleton()],
        ),
      ],
    );
  }
}

/// Một dòng: avatar 28dp, câu chính, dòng phụ ngắn hơn, giờ bên phải — khớp
/// hình học với [CompletionRow] trong thẻ bo 18 của ngày.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OmniSkeletonBox(height: 28, width: 28, radius: 14),
          SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OmniSkeletonBox(height: 14, radius: OmniRadius.xs),
                SizedBox(height: OmniSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  child: OmniSkeletonBox(height: 11, radius: OmniRadius.xs),
                ),
              ],
            ),
          ),
          SizedBox(width: OmniSpacing.sm),
          OmniSkeletonBox(height: 11, width: 36, radius: OmniRadius.xs),
        ],
      ),
    );
  }
}
