import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../design/components/components.dart';
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
    final plan = _plan;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Chuyển công việc',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: plan == null ? 'Chuyển sang kế hoạch' : plan.name,
          leading: plan == null
              ? null
              : IconButton(
                  tooltip: 'Chọn kế hoạch khác',
                  onPressed: () => setState(() => _plan = null),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        ),
        children: [
          if (plan == null) _planList(context) else _sectionList(plan),
        ],
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

      return OmniGroupSection(
        dividerIndent: 14,
        children: [
          for (final p in plans)
            OmniGroupRow(
              key: ValueKey('move-plan-${p.id}'),
              title: p.name,
              selected: p.id == widget.currentProjectId,
              chevron: p.id != widget.currentProjectId,
              onTap: () => setState(() => _plan = p),
            ),
        ],
      );
    },
  );

  Widget _sectionList(MovablePlan plan) {
    final tones = OmniTaskTones.of(context);
    final samePlan = plan.id == widget.currentProjectId;

    return OmniGroupSection(
      dividerIndent: 40,
      children: [
        for (var i = 0; i < plan.sections.length; i++)
          OmniGroupRow(
            key: ValueKey('move-section-${plan.sections[i].id}'),
            leading: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: tones.sectionColor(i),
                shape: BoxShape.circle,
              ),
            ),
            title: plan.sections[i].name,
            selected:
                samePlan && plan.sections[i].id == widget.currentSectionId,
            onTap: () => Navigator.of(
              context,
            ).pop((projectId: plan.id, sectionId: plan.sections[i].id)),
          ),
        if (plan.sections.isEmpty)
          OmniGroupRow(
            title: 'Chưa xếp nhóm việc',
            selected: samePlan && widget.currentSectionId == null,
            onTap: () => Navigator.of(
              context,
            ).pop((projectId: plan.id, sectionId: null)),
          ),
      ],
    );
  }
}
