import 'ymd.dart';

/// Ghi đè một ngày khi sao chép: record CÓ MẶT = gửi khoá (date null = để trống),
/// record null = không gửi khoá (server chép ngày của việc gốc).
typedef TaskDateOverride = ({DateTime? date});

/// Body của `POST /tasks/{id}/copy`. Bốn khoá cuối chỉ được đặt khi phiên có
/// `ApiCapability.taskCopyOptions` — sheet chịu trách nhiệm đó (R11).
class TaskCopyRequest {
  const TaskCopyRequest({
    this.title,
    this.projectId,
    this.sectionId,
    this.keepAssignees = true,
    this.keepChecklist = true,
    this.startDate,
    this.dueDate,
    this.assigneeIds,
    this.keepCustomFields,
  });

  final String? title;
  final String? projectId;
  final String? sectionId;
  final bool keepAssignees;
  final bool keepChecklist;
  final TaskDateOverride? startDate;
  final TaskDateOverride? dueDate;
  final List<String>? assigneeIds;
  final bool? keepCustomFields;

  Map<String, dynamic> toJson() {
    final name = title?.trim() ?? '';

    return <String, dynamic>{
      if (name.isNotEmpty) 'title': name,
      if (projectId case final p? when p.isNotEmpty) 'project_id': p,
      if (sectionId case final s? when s.isNotEmpty) 'section_id': s,
      // `assignee_ids` có mặt thì thay `keep_assignees` (hợp đồng): gửi cả hai
      // là hai câu trả lời cho một câu hỏi.
      if (assigneeIds == null) 'keep_assignees': keepAssignees,
      'keep_checklist': keepChecklist,
      if (startDate case (:final date))
        'start_date': date == null ? null : ymd(date),
      if (dueDate case (:final date))
        'due_date': date == null ? null : ymd(date),
      'assignee_ids': ?assigneeIds,
      'keep_custom_fields': ?keepCustomFields,
    };
  }
}
