import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/day_group.dart';

/// `HÔM NAY · 12 công đoạn · 2 cây xong`
///
/// Dính khi cuộn: một ngày bận có thể dài hơn màn hình, và mất tiêu đề nghĩa là
/// đang đọc một danh sách không biết thuộc ngày nào.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.group});

  static const double height = 36;

  final DayGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      // Nền ĐẶC, không trong suốt: tiêu đề dính mà để lộ nội dung trôi phía sau
      // thì hai dòng chữ chồng lên nhau.
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Text(
        group.summary,
        style: OmniType.overline.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: OmniType.tabular,
        ),
      ),
    );
  }
}

/// Bọc [DayHeader] cho `SliverPersistentHeader(pinned: true)`.
class DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DayHeaderDelegate(this.group);

  final DayGroup group;

  @override
  double get minExtent => DayHeader.height;

  @override
  double get maxExtent => DayHeader.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      DayHeader(group: group);

  @override
  bool shouldRebuild(covariant DayHeaderDelegate old) =>
      old.group.day != group.day ||
      old.group.stageCount != group.stageCount ||
      old.group.pianoCount != group.pianoCount;
}
