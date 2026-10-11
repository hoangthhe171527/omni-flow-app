import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Breadcrumb "kế hoạch › nhóm việc" (`TaskDetail.dc.html` `.crumb`): nút
/// viền cao 32, bo 6, chữ 13 w500, giữa là ›. Vùng chạm cao 44.
///
/// [onPlan] null = chỉ hiển thị (thiếu quyền route bảng). [onSection] null =
/// chỉ hiển thị (không phải người giao việc).
class TaskBreadcrumb extends StatelessWidget {
  const TaskBreadcrumb({
    super.key,
    required this.planName,
    required this.sectionName,
    this.onPlan,
    this.onSection,
  });

  final String? planName;

  /// null = không có ô nhóm.
  final String? sectionName;
  final VoidCallback? onPlan;
  final VoidCallback? onSection;

  @override
  Widget build(BuildContext context) {
    final plan = planName;
    final section = sectionName;

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (plan != null)
          _Crumb(key: const ValueKey('crumb-plan'), text: plan, onTap: onPlan),
        if (plan != null && section != null)
          Icon(
            Icons.chevron_right_rounded,
            size: OmniIconSize.sm,
            color: OmniTaskTones.of(context).faint,
          ),
        if (section != null)
          _Crumb(
            key: const ValueKey('crumb-section'),
            text: section,
            onTap: onSection,
          ),
      ],
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),

      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      // Ôm chữ, căn giữa theo chiều cao 32.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: OmniTaskTones.of(context).upcoming.foreground,
          ),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: chip,
          ),
        ),
      ),
    );
  }
}
