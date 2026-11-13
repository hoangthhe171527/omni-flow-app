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
    final scheme = Theme.of(context).colorScheme;
    final nameLen = _name.text.characters.length;
    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Sao chép kế hoạch',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      footer: FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : _submit,
        child: const Text('Sao chép'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tên kế hoạch mới *',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (nameLen >= 204)
                        Text(
                          '$nameLen/255',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: _name,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      counterText: '',
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
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
          chevron: false,
          semanticsLabel: selected ? '$label, đang chọn' : label,
          onTap: () => Navigator.of(ctx).pop(selected ? null : target),
        );

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Chuyển sang team khác',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(ctx).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
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
