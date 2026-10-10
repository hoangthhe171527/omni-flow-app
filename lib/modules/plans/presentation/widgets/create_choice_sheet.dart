import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Hai thứ tạo được từ gốc tab Việc.
enum CreateChoice { team, plan }

/// Sheet "Tạo mới": một nút, hai thứ tạo được — hỏi trước bằng một sheet thay
/// vì hai nút nổi, để người dùng chỉ đọc nhãn khi thật sự cần chọn.
///
/// "Tạo team" chỉ có khi [canCreateTeam]: tạo team LÀ tạo một đơn vị trong cơ
/// cấu tổ chức, API đòi quyền org tương ứng, và bày ra một dòng bấm vào là 403
/// tệ hơn không bày.
Future<CreateChoice?> showCreateChoiceSheet(
  BuildContext context, {
  required bool canCreateTeam,
}) => showOmniSheet<CreateChoice>(
  context: context,
  builder: (ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Tạo mới',
            style: Theme.of(
              ctx,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        if (canCreateTeam) ...[
          _ChoiceTile(
            icon: Icons.group_outlined,
            tone: OmniTaskTones.of(ctx).violet,
            title: 'Tạo team',
            subtitle: 'Một nhóm người, chứa nhiều dự án',
            onTap: () => Navigator.of(ctx).pop(CreateChoice.team),
          ),
          const SizedBox(height: 8),
        ],
        _ChoiceTile(
          icon: Icons.assignment_outlined,
          tone: OmniTaskTones.of(ctx).today,
          title: 'Tạo dự án',
          subtitle: 'Các nhóm việc và công việc trong đó',
          onTap: () => Navigator.of(ctx).pop(CreateChoice.plan),
        ),
      ],
    ),
  ),
);

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final OmniTaskTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(8));

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: radius,
                  ),
                  child: Icon(icon, size: 20, color: tone.foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút + của tab Việc (`Tasks.dc.html`): vuông 52×52 bo 14, CHỈ biểu tượng.
///
/// Xoay 45° thành × khi sheet của nó đang mở ([open]), để nút cũng là chỗ đóng
/// ngay trước mắt. Hoạt ảnh tắt khi người dùng bật giảm chuyển động.
class CreateSquareButton extends StatelessWidget {
  const CreateSquareButton({
    super.key,
    required this.open,
    required this.onPressed,
  });

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    );

    return Semantics(
      button: true,
      label: 'Tạo team hoặc dự án',
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: scheme.primary,
          elevation: 6,
          shadowColor: scheme.primary.withValues(alpha: 0.4),
          shape: shape,
          child: InkWell(
            customBorder: shape,
            // Giảm chuyển động: không gợn sóng khi chạm.
            splashFactory: OmniMotion.enabled(context)
                ? null
                : NoSplash.splashFactory,
            onTap: onPressed,
            child: AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: OmniMotion.enabled(context)
                  ? const Duration(milliseconds: 300)
                  : Duration.zero,
              curve: OmniCurves.standard,
              child: Icon(Icons.add_rounded, size: 24, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
