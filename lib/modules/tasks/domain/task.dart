import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// One step of a task, owned by one person.
///
/// In the workshop a task is a piano and these are its stages — "Nắp phím
/// (Hằng Ni)", "Bộ máy (Luận)" — worked in order by different people. That is
/// why an item carries an owner and a date of its own rather than being a bare
/// line of text.
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    required this.done,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    done: json.flag('done'),
    assigneeId: json.str('assignee_id'),
    assigneeName: json.str('assignee_name'),
    dueDate: DateUtilsX.parse(json['due_date']),
  );

  final String id;
  final String title;
  final bool done;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;

  Subtask copyWith({bool? done}) => Subtask(
    id: id,
    title: title,
    done: done ?? this.done,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    dueDate: dueDate,
  );
}

/// A unit of work somebody is responsible for.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.status = 'todo',
    this.priority = 'med',
    this.projectId,
    this.projectName,
    this.assigneeIds = const [],
    this.assigneeNames = const [],
    this.dueDate,
    this.startDate,
    this.subtasks = const [],
    this.customFields = const {},
    this.attachmentCount = 0,
    this.commentCount = 0,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    description: json.str('description'),
    status: json.strOr('status', 'todo'),
    priority: json.strOr('priority', 'med'),
    projectId: json.str('project_id'),
    projectName: json.str('project_name'),
    assigneeIds: json.strList('assignee_ids'),
    assigneeNames: json.strList('assignee_names'),
    // The API writes the deadline as due_date; older documents used deadline.
    // Reading only one of them is how a whole column silently shows "no date".
    dueDate:
        DateUtilsX.parse(json['due_date']) ??
        DateUtilsX.parse(json['deadline']),
    startDate: DateUtilsX.parse(json['start_date']),
    subtasks: json.mapList('checklist').map(Subtask.fromJson).toList(),
    customFields: json.child('custom_fields'),
    attachmentCount: json.intOr('attachments_count'),
    commentCount: json.intOr('comments_count'),
  );

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? projectId;
  final String? projectName;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final DateTime? dueDate;
  final DateTime? startDate;
  final List<Subtask> subtasks;
  final Map<String, dynamic> customFields;
  final int attachmentCount;
  final int commentCount;

  /// Only `done` is terminal; every other status id is defined by the project.
  bool get isDone => status == 'done';

  int get doneCount => subtasks.where((s) => s.done).length;

  int get totalCount => subtasks.length;

  /// 0.0–1.0, and 0 rather than NaN when there are no stages at all.
  ///
  /// This is the number the card leads with, because "how far along is this
  /// piano" is the only question a worker opens the app to answer.
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  bool get hasSubtasks => subtasks.isNotEmpty;

  /// Days past the deadline, or null when it is not overdue.
  ///
  /// Compared by calendar day, not by instant: a task due today at 09:00 is not
  /// "overdue" at 10:00 to somebody standing at a workbench.
  int? get daysOverdue {
    final due = dueDate;
    if (due == null || isDone) return null;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final difference = todayDay.difference(dueDay).inDays;

    return difference > 0 ? difference : null;
  }

  bool get isOverdue => daysOverdue != null;

  bool get isDueToday {
    final due = dueDate;
    if (due == null || isDone) return false;
    final today = DateTime.now();

    return due.year == today.year &&
        due.month == today.month &&
        due.day == today.day;
  }

  Task copyWith({List<Subtask>? subtasks, String? status}) => Task(
    id: id,
    title: title,
    description: description,
    status: status ?? this.status,
    priority: priority,
    projectId: projectId,
    projectName: projectName,
    assigneeIds: assigneeIds,
    assigneeNames: assigneeNames,
    dueDate: dueDate,
    startDate: startDate,
    subtasks: subtasks ?? this.subtasks,
    customFields: customFields,
    attachmentCount: attachmentCount,
    commentCount: commentCount,
  );
}
