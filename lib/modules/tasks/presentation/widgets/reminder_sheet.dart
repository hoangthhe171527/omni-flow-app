import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/tasks_providers.dart';
import '../../data/tasks_api.dart';
import '../../domain/task_reminder.dart';

/// Chọn ngày + giờ nhắc; null = huỷ. Tiêm được để test không mở lịch / đồng
/// hồ của hệ thống.
typedef ReminderPicker = Future<DateTime?> Function(BuildContext context);

/// Lịch rồi đồng hồ (giờ máy). Ngày từ hôm nay tới +365 (server: `after:now`,
/// `before:+366 days`).
Future<DateTime?> pickReminderTime(BuildContext context) async {
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final day = await pickOmniDate(
    context: context,
    initialDate: today,
    firstDate: today,
    lastDate: today.add(const Duration(days: 365)),
  );
  if (day == null || !context.mounted) return null;
  final next = now.add(const Duration(hours: 1));
  final time = await pickOmniTime(
    context: context,
    initialTime: TimeOfDay(hour: next.hour, minute: 0),
  );
  if (time == null) return null;

  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// Sheet "Nhắc việc" (Nhóm 2, phiên khai `tasks.reminders`).
///
///  * Danh sách lời nhắc người này thấy (`GET /tasks/{id}/reminders`).
///  * "Thêm lời nhắc": chọn ngày giờ → `POST {remind_at, audience}`. Chọn
///    "Mọi người trong việc" chỉ khi [canEveryone] (server: sửa được việc).
///  * × xoá: lời nhắc của mình, hoặc `everyone` khi [canManage] (server:
///    người khác → 403); chỉ lời nhắc còn chờ.
Future<void> showReminderSheet(
  BuildContext context, {
  required String taskId,
  required String? myUserId,
  required bool canEveryone,
  required bool canManage,
  ReminderPicker pick = pickReminderTime,
}) {
  final messenger = ScaffoldMessenger.of(context);

  return showOmniViecSheet<void>(
    context: context,
    builder: (_) => ReminderSheet(
      taskId: taskId,
      myUserId: myUserId,
      canEveryone: canEveryone,
      canManage: canManage,
      pick: pick,
      messenger: messenger,
    ),
  );
}

class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({
    super.key,
    required this.taskId,
    required this.myUserId,
    required this.canEveryone,
    required this.canManage,
    required this.pick,
    required this.messenger,
  });

  final String taskId;
  final String? myUserId;
  final bool canEveryone;
  final bool canManage;
  final ReminderPicker pick;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet> {
  bool _everyone = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function(TasksApi api) write) async {
    if (_busy) return;
    // Container giữ trước lượt chờ: người dùng có thể đóng sheet giữa chừng,
    // và `ref` của một widget đã huỷ thì ném.
    final container = ProviderScope.containerOf(context, listen: false);
    final api = container.read(tasksApiProvider);
    setState(() => _busy = true);
    try {
      await write(api);
      container.invalidate(taskRemindersProvider(widget.taskId));
    } on AppException catch (e) {
      widget.messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final at = await widget.pick(context);
    if (at == null || !mounted) return;
    if (!at.isAfter(DateTime.now())) {
      widget.messenger.showSnackBar(
        const SnackBar(content: Text('Chọn một thời điểm sau bây giờ.')),
      );
      return;
    }
    final everyone = widget.canEveryone && _everyone;
    await _run((api) async {
      await api.addReminder(widget.taskId, at, everyone: everyone);
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Đã đặt nhắc lúc ${_stamp(at)}.')),
      );
    });
  }

  bool _canDelete(TaskReminder r) {
    if (!r.isPending || r.id.isEmpty) return false;
    final mine = widget.myUserId != null && r.createdBy == widget.myUserId;

    return mine || (r.forEveryone && widget.canManage);
  }

  static String _stamp(DateTime at) =>
      '${Formatters.time(at)} ${Formatters.dayMonth(at)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant;
    final list = ref.watch(taskRemindersProvider(widget.taskId));

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Nhắc việc',
      child: OmniSheetBody(
        header: const OmniSheetHeader(title: 'Nhắc việc'),
        children: [
          if (widget.canEveryone)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OmniChoicePill(
                  label: 'Chỉ mình tôi',
                  selected: !_everyone,
                  onTap: _busy ? null : () => setState(() => _everyone = false),
                ),
                OmniChoicePill(
                  label: 'Mọi người trong việc',
                  selected: _everyone,
                  onTap: _busy ? null : () => setState(() => _everyone = true),
                ),
              ],
            ),
          OmniGroupSection(
            children: [
              OmniGroupRow.add(
                title: 'Thêm lời nhắc',
                icon: Icons.add_alarm_rounded,
                onTap: _busy ? null : _add,
              ),
              ...list.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    child: Text(
                      e is AppException
                          ? e.message
                          : 'Chưa tải được lời nhắc. Thử lại khi có mạng.',
                      textAlign: TextAlign.center,
                      style: OmniType.bodySm.copyWith(color: secondary),
                    ),
                  ),
                ],
                data: (items) => items.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          child: Text(
                            'Chưa có lời nhắc nào.',
                            textAlign: TextAlign.center,
                            style: OmniType.bodySm.copyWith(color: secondary),
                          ),
                        ),
                      ]
                    : [for (final r in items) _row(r, scheme, secondary)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(TaskReminder r, ColorScheme scheme, Color secondary) {
    final at = r.remindAt;
    final who = r.forEveryone ? 'Mọi người trong việc' : 'Chỉ mình tôi';
    final state = switch (r.status) {
      'sent' => ' · Đã nhắc',
      'skipped' => ' · Bỏ qua',
      _ => '',
    };
    final by =
        r.createdBy != null &&
            r.createdBy != widget.myUserId &&
            r.createdByName != null
        ? ' · ${r.createdByName}'
        : '';

    return OmniGroupRow(
      key: ValueKey('reminder-${r.id}'),
      icon: r.isPending ? Icons.alarm_rounded : Icons.alarm_off_rounded,
      title: at == null ? 'Không rõ giờ' : _stamp(at),
      subtitle: '$who$by$state',
      trailing: _canDelete(r)
          ? IconButton(
              tooltip: 'Xoá lời nhắc',
              onPressed: _busy
                  ? null
                  : () =>
                        _run((api) => api.deleteReminder(widget.taskId, r.id)),
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              icon: Icon(
                Icons.close_rounded,
                size: OmniIconSize.md,
                color: secondary,
              ),
            )
          : null,
    );
  }
}
