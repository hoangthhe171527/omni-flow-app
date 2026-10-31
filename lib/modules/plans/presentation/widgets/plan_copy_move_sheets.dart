import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';
import '../../domain/team.dart';

/// Lựa chọn của sheet sao chép kế hoạch (`CopyProjectRequest`).
typedef PlanCopyChoice = ({String name, bool copyTasks, bool asTemplate});

/// Sheet sao chép: tên (mặc định "Bản sao của …"), "Chép cả công việc",
/// "Lưu làm mẫu". Trả null khi huỷ.
Future<PlanCopyChoice?> showCopyPlanSheet(BuildContext context, Plan plan) =>
    showOmniViecSheet<PlanCopyChoice>(
      context: context,
      builder: (_) => _CopyPlanSheet(plan: plan),
    );

class _CopyPlanSheet extends StatefulWidget {
  const _CopyPlanSheet({required this.plan});

  final Plan plan;

  @override
  State<_CopyPlanSheet> createState() => _CopyPlanSheetState();
}

class _CopyPlanSheetState extends State<_CopyPlanSheet> {
  late final _name = TextEditingController(
    text: 'Bản sao của ${widget.plan.name}',
  );
  bool _copyTasks = true;
  bool _asTemplate = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop((name: name, copyTasks: _copyTasks, asTemplate: _asTemplate));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHandle(gap: 6),
          Text(
            'Sao chép kế hoạch',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          OmniField(
            label: 'Tên kế hoạch mới',
            child: TextField(
              controller: _name,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _copyTasks,
            title: const Text('Chép cả công việc'),
            onChanged: (on) {
              HapticFeedback.selectionClick();
              setState(() => _copyTasks = on);
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _asTemplate,
            title: const Text('Lưu làm mẫu'),
            // App chưa có chỗ dùng mẫu: nói trước, để bật công tắc không dẫn
            // vào ngõ cụt.
            subtitle: const Text('Mẫu chỉ dùng được trên web.'),
            onChanged: (on) {
              HapticFeedback.selectionClick();
              setState(() => _asTemplate = on);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _submit,
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }
}

/// Đích chuyển team: một team, hoặc [none] = "Không team".
sealed class PlanTeamTarget {
  const PlanTeamTarget();
}

class PlanTeamTo extends PlanTeamTarget {
  const PlanTeamTo(this.team);
  final Team team;
}

class PlanTeamNone extends PlanTeamTarget {
  const PlanTeamNone();
}

/// Sheet chọn team cho kế hoạch. [teams] chỉ gồm team thật; dòng "Không
/// team" luôn ở cuối. Chọn đúng team đang ở thì trả null (không đổi).
Future<PlanTeamTarget?> showMoveTeamSheet(
  BuildContext context, {
  required Plan plan,
  required List<Team> teams,
}) => showOmniViecSheet<PlanTeamTarget>(
  context: context,
  builder: (ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final current = plan.teamId ?? '';

    Widget row(String label, bool selected, PlanTeamTarget target) => Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, đang chọn' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(ctx).pop(selected ? null : target);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
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
                Icon(
                  Icons.check_rounded,
                  size: OmniIconSize.lg,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHandle(gap: 6),
          Text(
            'Chuyển sang team khác',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          for (final team in teams)
            row(team.name, team.id == current, PlanTeamTo(team)),
          row('Không team', current.isEmpty, const PlanTeamNone()),
        ],
      ),
    );
  },
);
