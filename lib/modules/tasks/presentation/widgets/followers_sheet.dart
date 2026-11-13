import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import 'assign_task_sheet.dart';

/// Sheet "Người theo dõi" của chi tiết việc (Nhóm 2).
///
/// Danh sách đọc thẳng từ việc đang mở (`follower_ids` / `_names` /
/// `_avatars`), nên mỗi lượt ghi xong là sheet vẽ lại theo bản server.
///  * "Theo dõi việc này" / "Bỏ theo dõi": `POST|DELETE /tasks/{id}/follow`,
///    ai đọc được việc cũng làm được (kể cả việc đã khoá).
///  * [canEditOthers] (người giao việc, việc chưa khoá): "Thêm người theo dõi"
///    và × trên từng dòng — `PUT follower_ids` cả danh sách.
Future<void> showFollowersSheet(
  BuildContext context, {
  required String taskId,
  required String? myUserId,
  required bool canEditOthers,
}) {
  final messenger = ScaffoldMessenger.of(context);

  return showOmniViecSheet<void>(
    context: context,
    builder: (_) => FollowersSheet(
      taskId: taskId,
      myUserId: myUserId,
      canEditOthers: canEditOthers,
      messenger: messenger,
    ),
  );
}

class FollowersSheet extends ConsumerStatefulWidget {
  const FollowersSheet({
    super.key,
    required this.taskId,
    required this.myUserId,
    required this.canEditOthers,
    required this.messenger,
  });

  final String taskId;
  final String? myUserId;
  final bool canEditOthers;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<FollowersSheet> createState() => _FollowersSheetState();
}

class _FollowersSheetState extends ConsumerState<FollowersSheet> {
  bool _busy = false;

  TaskController get _controller =>
      ref.read(taskDetailProvider(widget.taskId).notifier);

  Future<void> _run(Future<void> Function() write) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
    } on AppException catch (e) {
      widget.messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOthers(List<String> current) async {
    final chosen = await showAssignTaskSheet(
      context: context,
      currentIds: current,
      title: 'Ai theo dõi việc này',
      confirmLabel: (n) => n == 0 ? 'Bỏ hết người theo dõi' : 'Lưu ($n người)',
    );
    if (chosen == null || !mounted) return;
    if (chosen.length == current.length &&
        chosen.toSet().containsAll(current)) {
      return;
    }
    await _run(() => _controller.setFollowers(chosen));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final task = ref.watch(taskDetailProvider(widget.taskId)).valueOrNull?.task;
    if (task == null) return const SizedBox.shrink();
    final followers = task.followers;
    final ids = [for (final f in followers) f.id];
    final me = widget.myUserId;
    final following = me != null && ids.contains(me);

    final actions = [
      if (me != null)
        OmniGroupRow(
          icon: following
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          title: following ? 'Bỏ theo dõi' : 'Theo dõi việc này',
          chevron: false,
          onTap: _busy
              ? null
              : () => _run(() => _controller.setFollowing(!following)),
        ),
      if (widget.canEditOthers)
        OmniGroupRow(
          icon: Icons.person_add_alt_outlined,
          title: 'Thêm người theo dõi',
          onTap: _busy ? null : () => _addOthers(ids),
        ),
    ];

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Người theo dõi',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Người theo dõi (${followers.length})',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
            ),
          ),
        ),
        children: [
          if (actions.isNotEmpty) OmniGroupSection(children: actions),
          if (followers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Text(
                'Chưa ai theo dõi việc này.',
                textAlign: TextAlign.center,
                style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            OmniGroupSection(
              dividerIndent: 56,
              children: [
                for (final f in followers)
                  OmniGroupRow(
                    key: ValueKey('follower-${f.id}'),
                    leading: OmniAvatar(
                      name: f.name ?? '?',
                      imageUrl: f.avatar,
                      size: 30,
                    ),
                    title: f.id == me
                        ? '${f.name ?? 'Bạn'} (bạn)'
                        : (f.name ?? 'Người đã rời'),
                    maxTitleLines: 1,
                    chevron: false,
                    trailing: widget.canEditOthers
                        ? IconButton(
                            tooltip:
                                'Bỏ ${f.name ?? 'người này'} khỏi theo dõi',
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => _controller.setFollowers([
                                      for (final id in ids)
                                        if (id != f.id) id,
                                    ]),
                                  ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            icon: Icon(
                              Icons.close_rounded,
                              size: OmniIconSize.md,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
