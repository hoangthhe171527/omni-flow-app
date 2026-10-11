import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../team/team.dart';
import '../../../application/tasks_providers.dart';
import '../../../domain/task.dart';
import '../subtask_assignee_sheet.dart';
import 'detail_card.dart';

/// Thứ người dùng nhập ở sheet "Việc con mới".
typedef SubtaskDraft = ({String title, String? assigneeId});

/// Sheet "Việc con mới" (`SubtaskCreate.dc.html`): gần toàn màn (cách trên
/// 54), đầu Huỷ / "Việc con mới" / Tạo, ô tên, dòng Người làm.
///
/// Ô mô tả, hai ô ngày và chip Hôm nay / Ngày mai / Tuần sau là Nhóm 2 (API
/// chưa nhận các khoá đó khi tạo việc con) nên KHÔNG vẽ.
///
/// [onCreate] chạy khi bấm Tạo; xong thì sheet đóng. Nó ném [AppException]
/// thì sheet ở lại (giữ chữ đã gõ) và báo lỗi.
Future<void> showSubtaskCreateSheet(
  BuildContext context, {
  required String? projectId,
  required bool canAssign,
  required Future<void> Function(SubtaskDraft draft) onCreate,
}) {
  final height = MediaQuery.sizeOf(context).height;

  return showOmniSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    barrierColor: OmniColors.ink.withValues(alpha: 0.4),
    maxHeight: height - 54,
    radius: OmniRadius.fab,
    showDragHandle: false,
    animationStyle: const AnimationStyle(
      duration: OmniDuration.sheet,
      curve: OmniCurves.sheet,
      reverseDuration: OmniDuration.base,
    ),
    builder: (_) => SubtaskCreateSheet(
      projectId: projectId,
      canAssign: canAssign,
      onCreate: onCreate,
    ),
  );
}

class SubtaskCreateSheet extends ConsumerStatefulWidget {
  const SubtaskCreateSheet({
    super.key,
    required this.projectId,
    required this.canAssign,
    required this.onCreate,
  });

  final String? projectId;
  final bool canAssign;
  final Future<void> Function(SubtaskDraft draft) onCreate;

  @override
  ConsumerState<SubtaskCreateSheet> createState() => _SubtaskCreateSheetState();
}

class _SubtaskCreateSheetState extends ConsumerState<SubtaskCreateSheet> {
  final _name = TextEditingController();
  String? _assigneeId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canCreate => !_busy && _name.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_canCreate) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.onCreate((
        title: _name.text.trim(),
        assigneeId: _assigneeId,
      ));
      navigator.pop();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAssignee() async {
    final result = await showSubtaskAssigneeSheet(
      context,
      projectId: widget.projectId,
      subtask: Subtask(
        id: '',
        title: _name.text.trim(),
        done: false,
        assigneeId: _assigneeId,
      ),
    );
    if (result == null || !mounted) return;
    setState(
      () => _assigneeId = result is SubtaskAssignTo ? result.userId : null,
    );
  }

  TeamMember? _member(String id) {
    final list = widget.projectId == null
        ? ref.watch(teamMembersProvider).valueOrNull
        : ref.watch(projectMembersProvider(widget.projectId!)).valueOrNull;
    for (final m in list ?? const <TeamMember>[]) {
      if (m.userId == id) return m;
    }

    return ref.watch(teamMemberByIdProvider)[id];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = detailSecondary(context);
    final picked = _assigneeId;
    final member = picked == null ? null : _member(picked);
    final focusRing = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.primary),
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Tạo việc con',
      child: SizedBox(
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 44),
                      foregroundColor: secondary,
                      textStyle: OmniType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Huỷ'),
                  ),
                  Expanded(
                    child: Text(
                      'Việc con mới',
                      textAlign: TextAlign.center,
                      style: OmniType.section.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, _, _) => TextButton(
                      onPressed: _canCreate ? _create : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        foregroundColor: scheme.primary,
                        disabledForegroundColor: scheme.primary.withValues(
                          alpha: 0.4,
                        ),
                        textStyle: OmniType.bodyStrong,
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Tạo'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: true,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                      style: OmniType.body.copyWith(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Tên việc con',
                        filled: true,
                        fillColor: scheme.surface,
                        constraints: const BoxConstraints(minHeight: 48),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        focusedBorder: focusRing,
                      ),
                    ),
                    if (widget.canAssign) ...[
                      const SizedBox(height: 12),
                      DetailCard(
                        children: [
                          DetailRow(
                            label: 'Người làm',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (picked != null)
                                  Semantics(
                                    label:
                                        'Người làm: ${member?.name ?? 'đã chọn'}',
                                    excludeSemantics: true,
                                    child: OmniAvatar(
                                      name: member?.name ?? '?',
                                      imageUrl: member?.avatarUrl,
                                      size: 30,
                                    ),
                                  ),
                                Semantics(
                                  button: true,
                                  label: 'Chọn người làm',
                                  excludeSemantics: true,
                                  child: InkWell(
                                    onTap: _busy ? null : _pickAssignee,
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox.square(
                                      dimension: 44,
                                      child: Center(
                                        child: OmniDashedCircle(
                                          size: 30,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
