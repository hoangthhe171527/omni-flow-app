import 'package:flutter/material.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';

/// Một mục `.op` của sheet chia nhóm.
class DetailMenuItem<T> {
  const DetailMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.danger = false,
    this.trailing,
  });

  final T value;
  final IconData icon;
  final String label;

  /// Đỏ `#B42318` (Xoá).
  final bool danger;

  /// Chữ nhỏ bên phải (số đếm).
  final String? trailing;
}

/// Sheet chia nhóm của chi tiết việc (`TaskDetail.dc.html` `isMenu`): nền
/// `#F5F7FA`, bo trên 12, đệm 8/16/30, thanh kéo 36×4, mỗi nhóm `.og` nền
/// surface bo 8, mục cao 50 (biểu tượng 20 màu phụ, chữ 15 w500), vạch
/// `#EEF1F5` giữa các mục, nhóm cách 10. Trả `value` của mục đã chọn.
///
/// Nhóm rỗng bị bỏ; [title] (16 w600) là dòng đầu khi có.
Future<T?> showDetailMenuSheet<T>(
  BuildContext context, {
  required String semanticsLabel,
  required List<List<DetailMenuItem<T>>> groups,
  String? title,
}) => showOmniViecSheet<T>(
  context: context,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  builder: (_) => DetailMenuSheet<T>(
    semanticsLabel: semanticsLabel,
    title: title,
    groups: [
      for (final g in groups)
        if (g.isNotEmpty) g,
    ],
  ),
);

class DetailMenuSheet<T> extends StatelessWidget {
  const DetailMenuSheet({
    super.key,
    required this.semanticsLabel,
    required this.groups,
    this.title,
  });

  final String semanticsLabel;
  final String? title;
  final List<List<DetailMenuItem<T>>> groups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmniSheetHandle(gap: 12),
            if (title case final text?)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.section.copyWith(color: scheme.onSurface),
                ),
              ),
            for (var g = 0; g < groups.length; g++) ...[
              if (g > 0) const SizedBox(height: 10),
              Container(
                key: Key('detail-menu-group-$g'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[g].length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: OmniColors.trackOf(context),
                        ),
                      _Row(item: groups[g][i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.item});

  final DetailMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniTaskTones.of(context).highPriority.foreground;

    return InkWell(
      onTap: () => Navigator.of(context).pop(item.value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: OmniIconSize.lg,
                color: item.danger ? danger : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: item.danger ? danger : scheme.onSurface,
                  ),
                ),
              ),
              if (item.trailing case final value?)
                Text(
                  value,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
