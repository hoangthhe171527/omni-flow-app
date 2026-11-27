import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'omni_group.dart';
import 'omni_tinted_buttons.dart';

/// Bản LƯỜI của [OmniGroupSection] cho danh sách dài (rà soát kiến trúc
/// 27/11/2026): cùng hình — đầu nhóm chữ HOA, thẻ bo 16 có bóng nhóm, vạch
/// ngăn thụt — nhưng chỉ dựng những dòng đang trong tầm nhìn.
///
/// [OmniGroupSection] đặt mọi dòng trong MỘT `Column`: một nhóm 200 việc là
/// 200 thẻ dựng, đo và vẽ cùng lúc khi mở màn, và dựng lại hết mỗi lần nhóm
/// đổi. Dùng sliver này khi số dòng tăng theo dữ liệu (danh sách phân trang,
/// lịch sử, người) — đặt trong `CustomScrollView`. Danh sách ngắn có giới hạn
/// (tuỳ chọn, enum, vài tệp) cứ dùng [OmniGroupSection].
///
/// Mỗi dòng có `Material` riêng mang nền thẻ (dòng đầu bo trên, dòng cuối bo
/// dưới) để hiệu ứng chạm vẽ đúng trên thẻ và không tràn góc bo; bóng vẽ một
/// lần cho cả nhóm bằng [DecoratedSliver].
class OmniSliverGroup extends StatelessWidget {
  const OmniSliverGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.title,
    this.trailingTitle,
    this.dividerIndent,
    this.background,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? title;
  final Widget? trailingTitle;

  /// Như [OmniGroupSection.dividerIndent]: mặc định 54, nhóm không icon 14.
  final double? dividerIndent;

  /// Nền thẻ; mặc định surface.
  final Color? background;

  static const _radius = Radius.circular(16);

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final scheme = Theme.of(context).colorScheme;
    final indent = dividerIndent ?? 54;
    final color = background ?? scheme.surface;
    final highContrast = MediaQuery.highContrastOf(context);
    final divider = scheme.outlineVariant.withValues(alpha: .7);

    Widget row(BuildContext context, int i) {
      final first = i == 0;
      final last = i == itemCount - 1;
      final radius = BorderRadius.vertical(
        top: first ? _radius : Radius.zero,
        bottom: last ? _radius : Radius.zero,
      );
      return Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: first || last ? Clip.antiAlias : Clip.none,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!first)
              Divider(height: 1, thickness: 1, indent: indent, color: divider),
            itemBuilder(context, i),
          ],
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (title != null || trailingTitle != null)
          SliverToBoxAdapter(
            child: OmniGroupHeader(title: title ?? '', trailing: trailingTitle),
          ),
        DecoratedSliver(
          // Bóng nhóm vẽ SAU các dòng (nền mỗi dòng che phần trong thẻ).
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(_radius),
            boxShadow: OmniShadows.groupOf(context),
          ),
          sliver: DecoratedSliver(
            // Tương phản cao: viền vẽ TRƯỚC các dòng, không thì nền dòng che.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(_radius),
              border: highContrast
                  ? Border.all(color: scheme.outlineVariant)
                  : null,
            ),
            sliver: OmniTintedButtons(
              child: SliverList.builder(itemCount: itemCount, itemBuilder: row),
            ),
          ),
        ),
      ],
    );
  }
}
