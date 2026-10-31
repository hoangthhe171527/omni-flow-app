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
  final answer = isApple(context)
      ? await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                // Trên iOS, hành động phá huỷ KHÔNG được là mặc định: mặc định
                // là cái người dùng bấm khi không đọc kỹ.
                isDefaultAction: !destructive,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
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

