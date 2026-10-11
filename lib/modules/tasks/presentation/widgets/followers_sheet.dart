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
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) => InkWell(
      onTap: _busy ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: OmniIconSize.lg, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final actions = [
      if (me != null)
        action(
          icon: following
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          label: following ? 'Bỏ theo dõi' : 'Theo dõi việc này',
          onTap: () => _run(() => _controller.setFollowing(!following)),
        ),
      if (widget.canEditOthers)
        action(
          icon: Icons.person_add_alt_outlined,
          label: 'Thêm người theo dõi',
          onTap: () => _addOthers(ids),
        ),
    ];

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Người theo dõi',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmniSheetHandle(gap: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                'Người theo dõi (${followers.length})',
                style: OmniType.section.copyWith(color: scheme.onSurface),
              ),
            ),
            if (actions.isNotEmpty) _Group(children: actions),
            const SizedBox(height: 10),
            _Group(
              children: [
                if (followers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Chưa ai theo dõi việc này.',
                      textAlign: TextAlign.center,
                      style: OmniType.bodySm.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final f in followers)
                  ConstrainedBox(
                    key: ValueKey('follower-${f.id}'),
                    constraints: const BoxConstraints(minHeight: 50),
                    child: Row(
                      children: [
                        OmniAvatar(
                          name: f.name ?? '?',
                          imageUrl: f.avatar,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.id == me
                                ? '${f.name ?? 'Bạn'} (bạn)'
                                : (f.name ?? 'Người đã rời'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.body.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (widget.canEditOthers)
                          IconButton(
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
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhóm `.og`: nền surface bo 8, vạch giữa các dòng.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: OmniColors.trackOf(context),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
