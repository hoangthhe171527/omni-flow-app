import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';
import '../components/omni_glass.dart';
import '../components/omni_group.dart';
import '../components/omni_inputs.dart';
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
  final answer = await showOmniGlassDialog<bool>(
    context: context,
    builder: (context) => OmniGlassAlert(
      title: title,
      message: message,
      actions: [
        OmniAlertAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        // Phá huỷ thì KHÔNG đậm: nút đậm là "mặc định", cái người ta bấm khi
        // không đọc kỹ — xoá không được nằm ở đó (HIG).
        OmniAlertAction(
          label: confirmLabel,
          destructive: destructive,
          strong: !destructive,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  );

  return answer ?? false;
}

/// Mở một hộp thoại kính giữa màn (lớp phủ mực 28%). Nội dung thường là một
/// [OmniGlassAlert].
Future<T?> showOmniGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: OmniColors.ink.withValues(alpha: .28),
  builder: builder,
);

/// Một nút chữ ở đáy [OmniGlassAlert].
class OmniAlertAction {
  const OmniAlertAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.strong = false,
    this.key,
  });

  final String label;

  /// null = nút mờ (chưa đủ điều kiện).
  final VoidCallback? onPressed;
  final bool destructive;
  final bool strong;
  final Key? key;
}

/// Thẻ kính giữa màn kiểu iOS cho CẢ hai nền tảng (viomni-apple-uiux.html
/// `.alert.glass`): tiêu đề 17, lời nhắn 14 phụ, [body] tuỳ ý (ô nhập, ô
/// đánh dấu), các nút chữ chia đều ngăn bằng vạch. Vẫn là một AlertDialog để
/// các bài kiểm / trợ năng nhận ra hộp thoại.
class OmniGlassAlert extends StatelessWidget {
  const OmniGlassAlert({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.body,
  });

  final String title;
  final String? message;
  final Widget? body;
  final List<OmniAlertAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = scheme.onSurface.withValues(alpha: .10);

    Widget action(OmniAlertAction a) => Expanded(
      child: TextButton(
        key: a.key,
        onPressed: a.onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: const RoundedRectangleBorder(),
          foregroundColor: a.destructive ? scheme.error : scheme.primary,
          textStyle: OmniType.body.copyWith(
            fontSize: 16,
            fontWeight: a.strong ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        child: Text(a.label, textAlign: TextAlign.center),
      ),
    );

    return AlertDialog(
      backgroundColor: scheme.surface.withValues(alpha: dark ? .90 : .94),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
        constraints: const BoxConstraints(maxWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message case final m?)
                Text(
                  m,
                  textAlign: TextAlign.center,
                  style: OmniType.body.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (body != null) ...[
                if (message != null) const SizedBox(height: 14),
                body!,
              ],
            ],
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
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0)
                    VerticalDivider(width: 1, thickness: 1, color: line),
                  action(actions[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hỏi một dòng chữ trong hộp kính (vd gắn nhãn). Trả chữ đã cắt khoảng trắng,
/// hoặc null khi huỷ. Nút xác nhận mờ khi ô trống.
Future<String?> showOmniPrompt({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  String? hintText,
  String initialValue = '',
  String cancelLabel = 'Huỷ',
  int? maxLength,
  Key? fieldKey,
}) => showOmniGlassDialog<String>(
  context: context,
  builder: (_) => _OmniPrompt(
    title: title,
    confirmLabel: confirmLabel,
    message: message,
    hintText: hintText,
    initialValue: initialValue,
    cancelLabel: cancelLabel,
    maxLength: maxLength,
    fieldKey: fieldKey,
  ),
);

/// Hộp của [showOmniPrompt]. Ô nhập do State giữ và huỷ khi hộp rời cây —
/// huỷ ngay lúc pop sẽ vỡ vì hoạt ảnh đóng hộp vẫn còn vẽ ô nhập.
class _OmniPrompt extends StatefulWidget {
  const _OmniPrompt({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
    required this.cancelLabel,
    this.message,
    this.hintText,
    this.maxLength,
    this.fieldKey,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final String? hintText;
  final String initialValue;
  final String cancelLabel;
  final int? maxLength;
  final Key? fieldKey;

  @override
  State<_OmniPrompt> createState() => _OmniPromptState();
}

class _OmniPromptState extends State<_OmniPrompt> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) => OmniGlassAlert(
    title: widget.title,
    message: widget.message,
    body: TextField(
      key: widget.fieldKey,
      controller: _controller,
      autofocus: true,
      maxLength: widget.maxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: widget.hintText, counterText: ''),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      OmniAlertAction(
        label: widget.cancelLabel,
        onPressed: () => Navigator.of(context).pop(),
      ),
      OmniAlertAction(
        label: widget.confirmLabel,
        strong: true,
        onPressed: _controller.text.trim().isEmpty ? null : _submit,
      ),
    ],
  );
}

/// Chọn ngày bằng sheet kính (đợt 1 liquid, duyệt 08/11/2026) cho MỌI nền
/// tảng: chip nhanh Hôm nay / Ngày mai / Tuần sau (khi nằm trong khoảng),
/// lịch tháng — ngày đang chọn là viên trắng mờ chữ màu chính, không khối
/// xanh — và nút kính "Xong". Thay hộp lịch Material bật giữa màn.
Future<DateTime?> pickOmniDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String cancelText = 'Huỷ',
  String confirmText = 'Xong',
  bool quickPicks = true,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final first = day(firstDate);
  final last = day(lastDate);
  var selected = day(initialDate);
  if (selected.isBefore(first)) selected = first;
  if (selected.isAfter(last)) selected = last;
  final today = day(DateTime.now());
  final quick = <(String, DateTime)>[
    ('Hôm nay', today),
    ('Ngày mai', today.add(const Duration(days: 1))),
    ('Tuần sau', today.add(const Duration(days: 7))),
  ].where((q) => !q.$2.isBefore(first) && !q.$2.isAfter(last)).toList();

  return showOmniSheet<DateTime>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final selection = OmniGlass.selectionOf(sheetContext);
        bool isSel(Set<WidgetState> s) => s.contains(WidgetState.selected);

        return OmniSheetBody(
          semanticsLabel: helpText ?? 'Chọn ngày',
          header: OmniSheetHeader(
            title: helpText ?? 'Chọn ngày',
            trailing: TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(cancelText),
            ),
          ),
          footer: FilledButton(
            key: const Key('omni-date-done'),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(sheetContext).pop(selected);
            },
            child: Text(confirmText),
          ),
          children: [
            if (quickPicks && quick.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, value) in quick)
                    OmniChoicePill(
                      label: label,
                      selected: selected == value,
                      onTap: () => setState(() => selected = value),
                    ),
                ],
              ),
            Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: theme.copyWith(
                  datePickerTheme: theme.datePickerTheme.copyWith(
                    dayBackgroundColor: WidgetStateProperty.resolveWith(
                      (s) => isSel(s) ? selection : Colors.transparent,
                    ),
                    dayForegroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.disabled)
                          ? scheme.onSurface.withValues(alpha: .3)
                          : isSel(s)
                          ? scheme.primary
                          : scheme.onSurface,
                    ),
                    dayShape: WidgetStateProperty.resolveWith(
                      (s) => CircleBorder(
                        side: isSel(s)
                            ? BorderSide(
                                color: scheme.primary.withValues(alpha: .35),
                              )
                            : BorderSide.none,
                      ),
                    ),
                    todayForegroundColor: WidgetStateProperty.resolveWith(
                      (s) => isSel(s) ? scheme.primary : scheme.primary,
                    ),
                    todayBackgroundColor: WidgetStateProperty.resolveWith(
                      (s) => isSel(s) ? selection : Colors.transparent,
                    ),
                    todayBorder: BorderSide.none,
                  ),
                ),
                child: CalendarDatePicker(
                  // Đổi key khi chọn nhanh để lịch nhảy đúng tháng.
                  key: ValueKey(selected),
                  initialDate: selected,
                  firstDate: first,
                  lastDate: last,
                  onDateChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => selected = day(value));
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Chọn giờ bằng sheet kính cho MỌI nền tảng: hai cột giờ / phút 24h, chip
/// giờ hay dùng 08:00 · 12:00 · 17:00 và nút kính "Xong".
Future<TimeOfDay?> pickOmniTime({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  String cancelText = 'Huỷ',
  String confirmText = 'Xong',
}) {
  final now = DateTime.now();
  var selected = TimeOfDay(hour: initialTime.hour, minute: initialTime.minute);
  var wheelKey = 0;
  const quick = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
  ];
  String fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  return showOmniSheet<TimeOfDay>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => OmniSheetBody(
        semanticsLabel: helpText ?? 'Chọn giờ',
        header: OmniSheetHeader(
          title: helpText ?? 'Chọn giờ',
          trailing: TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelText),
          ),
        ),
        footer: FilledButton(
          key: const Key('omni-time-done'),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(sheetContext).pop(selected);
          },
          child: Text(confirmText),
        ),
        children: [
          Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 180,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(sheetContext).brightness,
                ),
                child: CupertinoDatePicker(
                  key: ValueKey(wheelKey),
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selected.hour,
                    selected.minute,
                  ),
                  onDateTimeChanged: (value) {
                    HapticFeedback.selectionClick();
                    selected = TimeOfDay(
                      hour: value.hour,
                      minute: value.minute,
                    );
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in quick)
                OmniChoicePill(
                  label: fmt(t),
                  selected: selected == t,
                  onTap: () => setState(() {
                    selected = t;
                    wheelKey++;
                  }),
                ),
            ],
          ),
        ],
      ),
    ),
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
