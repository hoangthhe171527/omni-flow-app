import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Thẻ Mô tả (`TaskDetail.dc.html`): đầu thẻ 48 gồm biểu tượng, "Mô tả",
/// nút "Sao chép mô tả" và "Sửa mô tả" (44); thân đệm 0/12/12, dòng 1.55,
/// giữ xuống dòng. Trống thì "Chưa có mô tả" mờ.
class DescriptionCard extends StatelessWidget {
  const DescriptionCard({
    super.key,
    required this.text,
    this.onCopy,
    this.onEdit,
  });

  final String text;

  /// null = không có nút chép (mô tả trống thì không có gì để chép).
  final VoidCallback? onCopy;

  /// null = không sửa được (không phải người giao việc).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final empty = text.trim().isEmpty;

    Widget action(String tooltip, IconData icon, VoidCallback onTap) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            maximumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            foregroundColor: scheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(icon, size: OmniIconSize.md),
        );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: OmniIconSize.lg,
                    color: secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mô tả',
                      style: OmniType.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (onCopy != null)
                    action('Sao chép mô tả', Icons.copy_rounded, onCopy!),
                  if (onEdit != null)
                    action('Sửa mô tả', Icons.edit_outlined, onEdit!),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              empty ? 'Chưa có mô tả' : text,
              style: OmniType.bodySm.copyWith(
                height: 1.55,
                color: empty
                    ? secondary
                    : OmniTaskTones.of(context).upcoming.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
