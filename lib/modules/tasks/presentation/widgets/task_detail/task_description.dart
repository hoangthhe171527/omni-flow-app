import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Khối mô tả. Với người giao việc, chạm vào để sửa — kể cả khi còn trống.
class TaskDescription extends StatelessWidget {
  const TaskDescription({super.key, required this.text, this.onEdit});

  final String text;

  /// Null = chỉ đọc.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mô tả',
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.sm),
          if (onEdit == null)
            Text(text, style: OmniType.body)
          else
            InkWell(
              onTap: onEdit,
              borderRadius: OmniRadius.mdAll,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  text.trim().isEmpty ? 'Thêm mô tả…' : text,
                  style: text.trim().isEmpty
                      ? OmniType.body.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        )
                      : OmniType.body,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
