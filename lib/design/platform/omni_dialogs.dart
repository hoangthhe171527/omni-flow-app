import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';
import 'omni_platform.dart';

/// Hỏi người dùng một câu có/không.
///
/// Trả về `true` khi người dùng xác nhận. Gạt bỏ hộp thoại — bấm ra ngoài, bấm
/// nút back — trả về `false`, không phải null: với một hành động phá huỷ,
/// "chưa trả lời" mà bị hiểu thành "đồng ý" là xoá nhầm dữ liệu của người ta.
/// Kiểu trả về không cho phép chỗ gọi mắc lỗi đó.
Future<bool> showOmniConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Huỷ',
  bool destructive = false,
}) async {
  // Thẻ kính giữa màn kiểu iOS cho CẢ hai nền tảng (viomni-apple-uiux.html
  // `.alert.glass`): tiêu đề 17, lời nhắn 14 phụ, hai nút chữ chia đôi ngăn
  // bằng vạch — "Huỷ" | hành động (đỏ khi phá huỷ, đậm hơn). Vẫn là một
  // AlertDialog để các bài kiểm / trợ năng nhận ra hộp thoại.
  final answer = await showDialog<bool>(
    context: context,
    barrierColor: OmniColors.ink.withValues(alpha: .28),
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final line = scheme.onSurface.withValues(alpha: .10);
      Widget action(String label, bool value, {bool strong = false}) =>
          Expanded(
            child: TextButton(
              onPressed: () {
                if (value) HapticFeedback.selectionClick();
                Navigator.of(context).pop(value);
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: const RoundedRectangleBorder(),
                foregroundColor: value && destructive
                    ? scheme.error
                    : scheme.primary,
                textStyle: OmniType.body.copyWith(
                  fontSize: 16,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              child: Text(label),
            ),
          );

      return AlertDialog(
        backgroundColor: scheme.surface.withValues(alpha: dark ? .90 : .94),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: dark ? .10 : .70),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        titlePadding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
        contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        actionsPadding: EdgeInsets.zero,
        buttonPadding: EdgeInsets.zero,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: OmniType.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: OmniType.body.copyWith(
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: line)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  action(cancelLabel, false),
                  VerticalDivider(width: 1, thickness: 1, color: line),
                  // Phá huỷ thì KHÔNG đậm: nút đậm là "mặc định", cái người ta
                  // bấm khi không đọc kỹ — xoá không được nằm ở đó (HIG).
                  action(confirmLabel, true, strong: !destructive),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  return answer ?? false;
}

/// Chọn ngày theo đúng chuẩn nền tảng: bánh xe Cupertino trên iOS/macOS,
/// hộp thoại lịch Material trên Android.
Future<DateTime?> pickOmniDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String cancelText = 'Huỷ',
  String confirmText = 'Xong',
}) async {
  if (!isApple(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }

  var selected = initialDate;
  if (selected.isBefore(firstDate)) selected = firstDate;
  if (selected.isAfter(lastDate)) selected = lastDate;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(cancelText),
                          ),
                          Expanded(
                            child: helpText == null
                                ? const SizedBox.shrink()
                                : Text(
                                    helpText,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: OmniType.caption.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(sheetContext).pop(selected);
                            },
                            child: Text(
                              confirmText,
                              style: OmniType.body.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: selected,
                    minimumDate: DateTime(
                      firstDate.year,
                      firstDate.month,
                      firstDate.day,
                    ),
                    maximumDate: DateTime(
                      lastDate.year,
                      lastDate.month,
                      lastDate.day,
                      23,
                      59,
                      59,
                    ),
                    onDateTimeChanged: (value) {
                      HapticFeedback.selectionClick();
                      selected = value;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Chọn giờ theo đúng chuẩn nền tảng: bánh xe Cupertino trên iOS/macOS,
/// đồng hồ Material trên Android.
Future<TimeOfDay?> pickOmniTime({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  String cancelText = 'Huỷ',
  String confirmText = 'Xong',
}) async {
  if (!isApple(context)) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
    );
  }

  final now = DateTime.now();
  var selected = TimeOfDay(hour: initialTime.hour, minute: initialTime.minute);

  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(cancelText),
                          ),
                          Expanded(
                            child: helpText == null
                                ? const SizedBox.shrink()
                                : Text(
                                    helpText,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: OmniType.caption.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(sheetContext).pop(selected);
                            },
                            child: Text(
                              confirmText,
                              style: OmniType.body.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      now.year,
                      now.month,
                      now.day,
                      initialTime.hour,
                      initialTime.minute,
                    ),
                    onDateTimeChanged: (value) {
                      HapticFeedback.selectionClick();
                      selected = TimeOfDay(
                        hour: value.hour,
                        minute: value.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Route chuyển trang theo nền tảng: hỗ trợ vuốt cạnh trái để quay lại mượt trên
/// iOS/macOS mà không để `modules/` phải import `package:flutter/cupertino.dart`.
PageRoute<T> omniPageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (isApple(context)) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
  );
}
