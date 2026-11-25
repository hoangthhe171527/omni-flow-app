import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/tokens.dart';

/// Tông của [OmniBanner] (Chuẩn Mobile UI — thành phần Banner).
enum OmniBannerTone { info, warning, danger }

/// Thông tin còn hiệu lực đến khi hết lý do: ngoại tuyến, thiếu quyền, dữ liệu
/// cũ, đồng bộ lỗi. Nằm TRONG luồng nội dung, đầu màn — không nổi, không tự
/// ẩn (việc đó của toast). Tối đa một banner mỗi màn.
///
/// Icon + một câu (phần [title] đậm) + nút chữ [actionLabel] bên phải. Màu
/// theo cặp nền nhạt / chữ đậm của [tone]; nghĩa nằm ở chữ, không chỉ ở màu.
class OmniBanner extends StatelessWidget {
  const OmniBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = OmniBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final String message;
  final String? title;
  final OmniBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Có thì hiện ✕ — chỉ khi người dùng bỏ qua được thông tin này.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData fallback) = switch (tone) {
      OmniBannerTone.info => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        LucideIcons.info,
      ),
      OmniBannerTone.warning => (
        dark ? OmniColors.darkWarningSoft : OmniColors.warningSoft,
        OmniColors.warningTextOf(context),
        LucideIcons.triangleAlert,
      ),
      OmniBannerTone.danger => (
        dark ? const Color(0xFF3A1A1A) : OmniColors.dangerSoft,
        OmniColors.dangerTextOf(context),
        LucideIcons.circleAlert,
      ),
    };
    final text = Text.rich(
      TextSpan(
        children: [
          if (title != null)
            TextSpan(
              text: '${title!}\n',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          TextSpan(text: message),
        ],
      ),
      style: OmniType.bodySm.copyWith(color: fg),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: OmniRadius.mdAll,
          border: MediaQuery.highContrastOf(context)
              ? Border.all(color: fg)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? fallback, size: OmniIconSize.lg, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(child: text),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: OmniType.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            if (onClose != null)
              IconButton(
                tooltip: 'Đóng',
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.x, size: OmniIconSize.md, color: fg),
              ),
            if (actionLabel == null && onClose == null)
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Báo một kết quả ở chỗ khác, hoặc cho hoàn tác (Chuẩn Mobile UI — Toast).
///
/// - Kết quả đã hiện trước mắt → KHÔNG gọi toast.
/// - Xoá / lưu trữ / ẩn → làm ngay rồi gọi toast với `actionLabel: 'Hoàn tác'`.
/// - Lỗi của một ô nhập → báo dưới ô, không dùng toast.
///
/// Kiểu nằm ở `snackBarTheme` (nền mực, chữ sáng, nút gạch chân); hàm này chỉ
/// gom thời lượng (4 giây, lâu hơn khi có trình đọc màn hình) và thay toast cũ
/// đang hiện để không bao giờ chồng hai cái.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showOmniToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final reader = MediaQuery.accessibleNavigationOf(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: reader ? 8 : (actionLabel == null ? 4 : 5)),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
