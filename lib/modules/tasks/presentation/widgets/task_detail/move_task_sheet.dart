import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../data/tasks_api.dart';

/// Đích chuyển việc: kế hoạch và nhóm việc (null = chưa xếp nhóm).
typedef MoveTarget = ({String projectId, String? sectionId});

/// "Chuyển sang nhóm / kế hoạch khác": hai bước trong một sheet — chọn kế
/// hoạch (`projectsForMove`, mọi kế hoạch đọc được kèm nhóm việc), rồi chọn
/// nhóm. Trả đích đã chọn, null khi đóng.
Future<MoveTarget?> showMoveTaskSheet(
  BuildContext context, {
  required String? currentProjectId,
  required String? currentSectionId,
}) => showOmniViecSheet<MoveTarget>(
  context: context,
  builder: (_) => MoveTaskSheet(
    currentProjectId: currentProjectId,
    currentSectionId: currentSectionId,
  ),
);

class MoveTaskSheet extends ConsumerStatefulWidget {
  const MoveTaskSheet({
    super.key,
    required this.currentProjectId,
    required this.currentSectionId,
  });

  final String? currentProjectId;
  final String? currentSectionId;

  @override
  ConsumerState<MoveTaskSheet> createState() => _MoveTaskSheetState();
}

class _MoveTaskSheetState extends ConsumerState<MoveTaskSheet> {
  late Future<List<MovablePlan>> _plans = _load();
  MovablePlan? _plan;

  Future<List<MovablePlan>> _load() =>
      ref.read(tasksApiProvider).projectsForMove();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Chuyển công việc',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OmniSheetHandle(),
            Row(
              children: [
                if (plan != null)
                  IconButton(
                    tooltip: 'Chọn kế hoạch khác',
                    onPressed: () => setState(() => _plan = null),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      plan == null ? 'Chuyển sang kế hoạch' : plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.section.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: OmniMotion.enabled(context)
                  ? AnimatedSize(
                      duration: OmniMotion.of(context).fast,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: plan == null
                          ? _planList(context)
                          : _sectionList(plan),
                    )
                  : (plan == null ? _planList(context) : _sectionList(plan)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planList(BuildContext context) => FutureBuilder<List<MovablePlan>>(
    future: _plans,
    builder: (context, snap) {
      if (snap.hasError) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa tải được danh sách kế hoạch.',
              style: OmniType.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _plans = _load()),
              child: const Text('Thử lại'),
            ),
          ],
        );
      }
      final plans = snap.data;
      if (plans == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }

      return _Group(
        children: [
          for (final p in plans)
            _Option(
              key: ValueKey('move-plan-${p.id}'),
              label: p.name,
              selected: p.id == widget.currentProjectId,
              trailingChevron: true,
              onTap: () => setState(() => _plan = p),
            ),
        ],
      );
    },
  );

  Widget _sectionList(MovablePlan plan) {
    final tones = OmniTaskTones.of(context);
    final samePlan = plan.id == widget.currentProjectId;

    return _Group(
      children: [
        for (var i = 0; i < plan.sections.length; i++)
          _Option(
            key: ValueKey('move-section-${plan.sections[i].id}'),
            label: plan.sections[i].name,
            color: tones.sectionColor(i),
            selected:
                samePlan && plan.sections[i].id == widget.currentSectionId,
            onTap: () => Navigator.of(
              context,
            ).pop((projectId: plan.id, sectionId: plan.sections[i].id)),
          ),
        if (plan.sections.isEmpty)
          _Option(
            label: 'Chưa xếp nhóm việc',
            selected: samePlan && widget.currentSectionId == null,
            onTap: () => Navigator.of(
              context,
            ).pop((projectId: plan.id, sectionId: null)),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: children.length,
      separatorBuilder: (context, _) =>
          Divider(height: 1, thickness: 1, color: OmniColors.trackOf(context)),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.selected = false,
    this.trailingChevron = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool selected;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              if (color case final c?) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: scheme.primary)
              else if (trailingChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: OmniTaskTones.of(context).faint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
