// A throwaway harness for looking at the task screens without a backend.
//
// Not part of the app: nothing under lib/ imports it, and it is never built
// into a release. It exists so a screen can be reviewed on a real device or in
// a browser before the API behind it is up, using stub data that includes the
// awkward cases — an overdue piano, a stage that failed to save, a name long
// enough to wrap.
//
//   flutter run -d chrome -t tool/ui_preview.dart
//   flutter build web -t tool/ui_preview.dart
//
// Run it, do not read it, for an opinion on the design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/notifications/presentation/notifications_page.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/my_tasks_page.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/subtask_row.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() => runApp(const ProviderScope(child: _PreviewApp()));

// ---------------------------------------------------------------------------
// Stub data
// ---------------------------------------------------------------------------

String _iso(Duration offset) =>
    DateTime.now().add(offset).toIso8601String();

/// Deliberately not all tidy: a piano that is late, one due today, one with no
/// deadline at all, and a title long enough to need two lines.
final _tasks = <Map<String, dynamic>>[
  {
    'id': 't-1',
    'title': 'KAWAI HAT-5 · 2308512',
    'project_name': 'Phục hồi đàn — Xưởng A',
    'status': 'doing',
    'due_date': _iso(const Duration(days: -3)),
    'assignee_names': ['Hằng Ni', 'Luận'],
    'description':
        'Khách yêu cầu giữ nguyên màu vecni gốc. Kiểm tra kỹ phần chốt trước '
        'khi lắp lại bộ máy.',
    'checklist': [
      {'id': 's-1', 'title': 'Tháo bộ máy', 'done': true, 'assignee_name': 'Luận'},
      {'id': 's-2', 'title': 'Vệ sinh khung sườn', 'done': true},
      {
        'id': 's-3',
        'title': 'Nắp phím',
        'done': false,
        'assignee_name': 'Hằng Ni',
      },
      {'id': 's-4', 'title': 'Lên dây và cân chỉnh lực phím', 'done': false},
    ],
    'viewers': [
      {'user_id': 'Hằng Ni', 'viewed_at': _iso(const Duration(hours: -2))},
      {'user_id': 'Luận', 'viewed_at': _iso(const Duration(minutes: -20))},
    ],
  },
  {
    'id': 't-2',
    'title': 'YAMAHA U3 · 1874203 — thay dạ búa toàn bộ và cân lại bàn phím',
    'project_name': 'Phục hồi đàn — Xưởng A',
    'status': 'todo',
    'due_date': _iso(const Duration(hours: 5)),
    'assignee_names': ['Hằng Ni'],
    'checklist': [
      {'id': 's-5', 'title': 'Tháo dạ búa cũ', 'done': false},
      {'id': 's-6', 'title': 'Dán dạ mới', 'done': false},
    ],
  },
  {
    'id': 't-3',
    'title': 'Giao đàn cho khách — chị Trang, Q7',
    'project_name': 'Giao nhận',
    'status': 'todo',
    'assignee_names': ['Luận'],
    'checklist': <Map<String, dynamic>>[],
  },
  {
    'id': 't-4',
    'title': 'ROLAND FP-30 · kiểm tra bo mạch',
    'project_name': 'Bảo hành',
    'status': 'done',
    'due_date': _iso(const Duration(days: -1)),
    'assignee_names': ['Luận'],
    'checklist': [
      {'id': 's-7', 'title': 'Đo nguồn', 'done': true},
      {'id': 's-8', 'title': 'Thay tụ', 'done': true},
    ],
  },
];

final _notifications = <Map<String, dynamic>>[
  {
    'id': 'n-1',
    'notification_type': 'TASK_ASSIGNED',
    'title': 'Bạn có việc mới',
    'content': '«KAWAI HAT-5 · 2308512» — hạn 3 ngày trước',
    'related_entity_type': 'task',
    'related_entity_id': 't-1',
    'created_at': _iso(const Duration(minutes: -8)),
  },
  {
    'id': 'n-2',
    'notification_type': 'TASK_STAGE_OPEN',
    'title': 'Công đoạn đang trống',
    'content': 'Nắp phím đang trống — «KAWAI HAT-5 · 2308512»',
    'related_entity_type': 'task',
    'related_entity_id': 't-1',
    'created_at': _iso(const Duration(hours: -1)),
  },
  {
    'id': 'n-3',
    'notification_type': 'TASK_COMPLETED',
    'title': 'Công việc đã hoàn thành',
    'content': '«ROLAND FP-30 · kiểm tra bo mạch» đã hoàn thành',
    'related_entity_type': 'task',
    'related_entity_id': 't-4',
    'read_at': null,
    'created_at': _iso(const Duration(hours: -3)),
  },
  {
    'id': 'n-4',
    'notification_type': 'TASK_OVERDUE',
    'title': 'Việc quá hạn',
    'content': '«YAMAHA U3 · 1874203» đã quá hạn',
    'related_entity_type': 'task',
    'related_entity_id': 't-2',
    'read_at': _iso(const Duration(hours: -20)),
    'created_at': _iso(const Duration(days: -1)),
  },
  {
    // A type this build has never heard of. It must still read as a normal row.
    'id': 'n-5',
    'notification_type': 'PIANO_DELIVERED',
    'title': 'Đã giao đàn',
    'content': 'Chị Trang (Q7) đã nhận đàn',
    'related_entity_type': 'order',
    'related_entity_id': 'o-9',
    'read_at': _iso(const Duration(days: -2)),
    'created_at': _iso(const Duration(days: -2)),
  },
];

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _StubTasksApi implements TasksApi {
  final _rows = [..._tasks];

  @override
  Future<Paged<Task>> mine({
    required TaskBucket bucket,
    int page = 1,
    int perPage = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final tasks = _rows.map(Task.fromJson).toList();

    return Paged(
      items: switch (bucket) {
        TaskBucket.today => tasks.where((t) => t.isDueToday).toList(),
        TaskBucket.overdue => tasks.where((t) => t.isOverdue).toList(),
        TaskBucket.upcoming =>
          tasks.where((t) => !t.isOverdue && !t.isDueToday && !t.isDone).toList(),
        TaskBucket.all => tasks,
      },
      pagination: const ApiPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 4,
      ),
    );
  }

  @override
  Future<Task> get(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return Task.fromJson(_rows.firstWhere((t) => t['id'] == id));
  }

  @override
  Future<Task> setSubtaskDone(
    String taskId,
    String subtaskId, {
    required bool done,
    String? clientRequestId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // s-4 always fails, so the failed-tick state is visible without unplugging
    // anything: the row keeps what the worker chose and says it did not save.
    if (subtaskId == 's-4') throw Exception('offline');

    final row = _rows.firstWhere((t) => t['id'] == taskId);
    for (final item in (row['checklist'] as List).cast<Map<String, dynamic>>()) {
      if (item['id'] == subtaskId) item['done'] = done;
    }

    return Task.fromJson(row);
  }

  @override
  Future<Task> setStatus(String taskId, String status) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final row = _rows.firstWhere((t) => t['id'] == taskId);
    row['status'] = status;

    return Task.fromJson(row);
  }

  @override
  Future<void> comment(String taskId, String body) async {}

  @override
  Future<void> attach(String taskId, String filePath, {String? filename}) async {}
}

class _StubNotificationsApi implements NotificationsApi {
  final _rows = [..._notifications];

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return Paged(
      items: _rows.map(AppNotification.fromJson).toList(),
      pagination: const ApiPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 5,
      ),
    );
  }

  @override
  Future<void> markRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final row in _rows) {
      if (row['id'] == id) row['read_at'] = DateTime.now().toIso8601String();
    }
  }

  @override
  Future<void> markAllRead() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    for (final row in _rows) {
      row['read_at'] = DateTime.now().toIso8601String();
    }
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(_StubTasksApi()),
        notificationsApiProvider.overrideWithValue(_StubNotificationsApi()),
        // The real one reads the session; there isn't one here.
        accessProvider.overrideWithValue(
          const AccessPolicy({TaskPermissions.read, TaskPermissions.write}),
        ),
        // No socket to open without a session.
        notificationRealtimeProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        title: 'Xem trước giao diện',
        debugShowCheckedModeBanner: false,
        theme: OmniTheme.light,
        darkTheme: OmniTheme.dark,
        themeMode: _mode,
        home: _Gallery(
          mode: _mode,
          onToggleMode: () => setState(
            () => _mode = _mode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.mode, required this.onToggleMode});

  final ThemeMode mode;
  final VoidCallback onToggleMode;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _screen = 0;

  static const _labels = ['Việc của tôi', 'Chi tiết', 'Thông báo', 'Dòng việc'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Material(
            color: scheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.md,
                  vertical: OmniSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < _labels.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: OmniSpacing.sm,
                                ),
                                child: ChoiceChip(
                                  label: Text(_labels[i]),
                                  selected: _screen == i,
                                  onSelected: (_) =>
                                      setState(() => _screen = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đổi sáng/tối',
                      onPressed: widget.onToggleMode,
                      icon: Icon(
                        widget.mode == ThemeMode.light
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (_screen) {
              0 => const MyTasksPage(),
              1 => const TaskDetailPage(taskId: 't-1'),
              2 => const NotificationsPage(),
              _ => const _RowStates(),
            },
          ),
        ],
      ),
    );
  }
}

/// Every state one subtask row can be in, side by side.
///
/// These are the states that are awkward to reach by hand — a tick still in
/// flight, a tick that failed — and the ones most likely to be got wrong.
class _RowStates extends StatelessWidget {
  const _RowStates();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget block(String label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.xs,
          ),
          child: Text(
            label,
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Material(color: scheme.surface, child: child),
      ],
    );

    const open = Subtask(id: 'a', title: 'Nắp phím', done: false);

    return ListView(
      children: [
        block(
          'Chưa xong',
          SubtaskRow(
            subtask: open,
            pending: null,
            enabled: true,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        block(
          'Có người phụ trách',
          SubtaskRow(
            subtask: const Subtask(
              id: 'b',
              title: 'Lên dây và cân chỉnh lực phím',
              done: false,
              assigneeName: 'Hằng Ni',
            ),
            pending: null,
            enabled: true,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        block(
          'Đã xong',
          SubtaskRow(
            subtask: const Subtask(id: 'c', title: 'Tháo bộ máy', done: true),
            pending: null,
            enabled: true,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        block(
          'Đang gửi',
          SubtaskRow(
            subtask: open,
            pending: const PendingTick(
              subtaskId: 'a',
              done: true,
              clientRequestId: 'c1',
            ),
            enabled: true,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        block(
          'Gửi hỏng — giữ nguyên lựa chọn của thợ',
          SubtaskRow(
            subtask: open,
            pending: const PendingTick(
              subtaskId: 'a',
              done: true,
              clientRequestId: 'c1',
              error: 'Không có kết nối mạng',
            ),
            enabled: true,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        block(
          'Chỉ xem — không tick được',
          SubtaskRow(
            subtask: open,
            pending: null,
            enabled: false,
            onToggle: (_) {},
            onRetry: () {},
            onDiscard: () {},
          ),
        ),
        const SizedBox(height: OmniSpacing.section),
      ],
    );
  }
}
