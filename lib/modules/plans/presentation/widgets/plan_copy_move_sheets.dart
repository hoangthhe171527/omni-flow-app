import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../domain/plan.dart';
import '../../domain/team.dart';

/// Lựa chọn của sheet sao chép kế hoạch (`CopyProjectRequest`).
typedef PlanCopyChoice = ({String name, bool copyTasks, bool asTemplate});

/// Sheet sao chép: tên (mặc định "Bản sao của …"), "Chép cả công việc",
/// "Lưu làm mẫu". Trả null khi huỷ.
Future<PlanCopyChoice?> showCopyPlanSheet(BuildContext context, Plan plan) =>
    showOmniSheet<PlanCopyChoice>(
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
    return OmniSheetBody(
      header: const OmniSheetHeader(title: 'Sao chép kế hoạch'),
      footer: FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : _submit,
        child: const Text('Sao chép'),
      ),
      children: [
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
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            OmniGroupRow(
              title: 'Chép cả công việc',
              chevron: false,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _copyTasks = !_copyTasks);
              },
              trailing: Switch.adaptive(
                value: _copyTasks,
                onChanged: (on) {
                  HapticFeedback.selectionClick();
                  setState(() => _copyTasks = on);
                },
              ),
            ),
            OmniGroupRow(
              title: 'Lưu làm mẫu',
              chevron: false,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _asTemplate = !_asTemplate);
              },
              // App chưa có chỗ dùng mẫu: nói trước, để bật công tắc không dẫn
              // vào ngõ cụt.
              subtitle: 'Mẫu chỉ dùng được trên web.',
              trailing: Switch.adaptive(
                value: _asTemplate,
                onChanged: (on) {
                  HapticFeedback.selectionClick();
                  setState(() => _asTemplate = on);
                },
              ),
            ),
          ],
        ),
      ],
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
}) => showOmniSheet<PlanTeamTarget>(
  context: context,
  builder: (ctx) {
    final current = plan.teamId ?? '';

    Widget row(String label, bool selected, PlanTeamTarget target) =>
        OmniGroupRow(
          title: label,
          selected: selected,
          semanticsLabel: selected ? '$label, đang chọn' : label,
          onTap: () => Navigator.of(ctx).pop(selected ? null : target),
        );

    return OmniSheetBody(
      header: const OmniSheetHeader(title: 'Chuyển sang team khác'),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            for (final team in teams)
              row(team.name, team.id == current, PlanTeamTo(team)),
            row('Không team', current.isEmpty, const PlanTeamNone()),
          ],
        ),
      ],
    );
  },
);
