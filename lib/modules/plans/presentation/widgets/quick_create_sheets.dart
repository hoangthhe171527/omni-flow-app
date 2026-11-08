import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/application/team_providers.dart';
import '../../application/plans_providers.dart';
import '../../data/plan_cover_upload.dart';
import '../../data/plans_api.dart';
import '../create_plan_page.dart' show kDefaultSections, kGatedDefaultSections;
import 'cover_picker.dart';

/// Kết quả một lượt tạo nhanh để màn Việc báo "Đã tạo": kế hoạch (mở bảng
/// được) hoặc chỉ team (chọn "Để sau" ở bước kế hoạch đầu tiên).
typedef QuickCreated = ({String id, String name, bool isTeam});

/// Sheet "Kế hoạch mới" (viec-quick-create-uiux.html): tạo ngay trên màn Việc,
/// không chuyển trang. Trả về kế hoạch vừa tạo, null khi đóng.
Future<QuickCreated?> showQuickCreatePlan(
  BuildContext context, {
  ProjectCoverImagePicker pickImage = pickProjectCoverImage,
}) => showOmniSheet<QuickCreated>(
  context: context,
  builder: (_) => QuickCreatePlanForm(pickImage: pickImage),
);

/// Sheet "Team mới": tạo xong chuyển NGAY trong sheet sang "Kế hoạch đầu
/// tiên" với team đã chọn sẵn (giữ luồng team → kế hoạch của trang cũ), có
/// "Để sau". Trả về kế hoạch nếu tạo luôn, team nếu "Để sau", null nếu đóng.
Future<QuickCreated?> showQuickCreateTeam(
  BuildContext context, {
  ProjectCoverImagePicker pickImage = pickProjectCoverImage,
}) => showOmniSheet<QuickCreated>(
  context: context,
  builder: (_) => _QuickCreateTeamSheet(pickImage: pickImage),
);

// ---------------------------------------------------------------------------
// Phần dùng chung

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: OmniType.body.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Một dòng gập/mở gọn: biểu tượng · nhãn · giá trị bên phải. Phần mở ra
/// nằm ngay dưới, trong cùng sheet — không cuộn ngang, không màn thứ hai.
class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.expanded,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// null = dòng hành động (không gập/mở).
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.onSurface.withValues(alpha: .08)),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                label,
                style: OmniType.body.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (expanded != null) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded! ? 0.25 : 0,
                  duration: OmniMotion.of(context).fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _errorText(BuildContext context, String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          error,
          style: OmniType.caption.copyWith(
            color: OmniColors.dangerTextOf(context),
          ),
        ),
      );

Widget _saveButton({
  required String label,
  required bool saving,
  required VoidCallback? onPressed,
  Key? key,
}) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: FilledButton(
    key: key,
    onPressed: saving ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    child: saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Text(label),
  ),
);

// ---------------------------------------------------------------------------
// Kế hoạch

/// Form tạo kế hoạch nằm trong sheet. [teamId] khác null: tới từ "vừa tạo
/// team xong" — ẩn chọn team, hiện dải xác nhận và nút "Để sau".
class QuickCreatePlanForm extends ConsumerStatefulWidget {
  const QuickCreatePlanForm({
    super.key,
    this.teamId,
    this.teamName,
    this.pickImage = pickProjectCoverImage,
  });

  final String? teamId;
  final String? teamName;
  final ProjectCoverImagePicker pickImage;

  @override
  ConsumerState<QuickCreatePlanForm> createState() =>
      _QuickCreatePlanFormState();
}

class _QuickCreatePlanFormState extends ConsumerState<QuickCreatePlanForm> {
  final _name = TextEditingController();
  final _newSection = TextEditingController();
  late String? _teamId = widget.teamId;
  late final List<String> _sections = [...kDefaultSections];
  String? _coverPath;
  bool _teamOpen = false;
  bool _sectionsOpen = false;
  bool _saving = false;
  String? _error;

  /// Kế hoạch đã tạo mà ảnh nền chưa lên: bấm lại chỉ tải ảnh, không tạo trùng.
  String? _createdId;

  bool get _chained => widget.teamId != null;

  @override
  void dispose() {
    _name.dispose();
    _newSection.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final path = await widget.pickImage();
      if (path != null && mounted) setState(() => _coverPath = path);
    } on Object {
      if (mounted) setState(() => _error = 'Chưa mở được thư viện ảnh.');
    }
  }

  void _addSection() {
    final name = _newSection.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _sections.add(name);
      _newSection.clear();
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var id = _createdId;
      if (id == null) {
        final plan = await ref
            .read(plansApiProvider)
            .createPlan(
              name: name,
              teamId: _teamId,
              sectionNames: [
                for (final s in _sections)
                  if (s.trim().isNotEmpty) s.trim(),
              ],
              gatedSectionNames: kGatedDefaultSections,
            );
        id = plan.id;
        _createdId = id;
      }
      if (_coverPath case final path?) {
        await ref.read(planCoverApiProvider).upload(id, path);
      }
      ref.invalidate(teamsWithPlansProvider);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(
        context,
      ).pop<QuickCreated>((id: id, name: name, isTeam: false));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _createdId == null
            ? e.message
            : 'Kế hoạch đã tạo nhưng ảnh nền chưa tải lên. ${e.message} '
                  'Bấm lại để thử, không tạo bản trùng.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _createdId == null
            ? 'Chưa tạo được kế hoạch. Vui lòng thử lại.'
            : 'Kế hoạch đã tạo nhưng ảnh nền chưa tải lên. '
                  'Bấm lại để thử, không tạo bản trùng.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teams = [
      for (final g in ref.watch(teamsWithPlansProvider).valueOrNull ?? const [])
        if (!g.synthetic) g.team,
    ];
    final teamLabel = _teamId == null
        ? 'Chưa thuộc team'
        : teams.where((t) => t.id == _teamId).firstOrNull?.name ??
              widget.teamName ??
              'Team';

    return SingleChildScrollView(
      key: const Key('quick-create-plan'),
      padding: const EdgeInsets.fromLTRB(18, 4, 10, 18),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(_chained ? 'Kế hoạch đầu tiên' : 'Kế hoạch mới'),
            if (_chained) ...[
              Container(
                key: const Key('quick-team-created'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.teamName ?? 'Team'} đã tạo. Thêm kế hoạch '
                        'đầu tiên cho team này?',
                        style: OmniType.caption.copyWith(color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            OmniField(
              label: 'Tên kế hoạch',
              child: TextField(
                key: const Key('quick-plan-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Đàn cơ'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 12),
            if (!_chained) ...[
              _DisclosureRow(
                key: const Key('quick-plan-team'),
                icon: Icons.groups_2_outlined,
                label: 'Thuộc team',
                value: teamLabel,
                expanded: _teamOpen,
                onTap: () => setState(() => _teamOpen = !_teamOpen),
              ),
              if (_teamOpen)
                RadioGroup<String?>(
                  groupValue: _teamId,
                  onChanged: (id) => setState(() {
                    _teamId = id;
                    _teamOpen = false;
                  }),
                  child: Column(
                    children: [
                      const _TeamOption(id: null, name: 'Chưa thuộc team'),
                      for (final t in teams)
                        _TeamOption(id: t.id, name: t.name),
                    ],
                  ),
                ),
            ],
            _DisclosureRow(
              key: const Key('quick-plan-sections'),
              icon: Icons.view_week_outlined,
              label: 'Nhóm việc',
              value: _sections.join(' · '),
              expanded: _sectionsOpen,
              onTap: () => setState(() => _sectionsOpen = !_sectionsOpen),
            ),
            if (_sectionsOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _sections.length; i++)
                          InputChip(
                            label: Text(_sections[i]),
                            onDeleted: _sections.length > 1
                                ? () => setState(() => _sections.removeAt(i))
                                : null,
                            deleteButtonTooltipMessage:
                                'Bỏ nhóm ${_sections[i]}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('quick-plan-new-section'),
                      controller: _newSection,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Thêm nhóm việc',
                        suffixIcon: IconButton(
                          tooltip: 'Thêm nhóm việc',
                          icon: const Icon(Icons.add_rounded),
                          onPressed: _addSection,
                        ),
                      ),
                      onSubmitted: (_) => _addSection(),
                    ),
                  ],
                ),
              ),
            _DisclosureRow(
              key: const Key('quick-plan-cover'),
              icon: Icons.image_outlined,
              label: 'Ảnh nền',
              value: _coverPath == null ? 'Tuỳ chọn' : 'Đã chọn ảnh',
              onTap: _pickCover,
            ),
            if (_coverPath != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _coverPath = null),
                  child: const Text('Bỏ ảnh'),
                ),
              ),
            _errorText(context, _error),
            _saveButton(
              key: const Key('quick-plan-save'),
              label: _createdId != null ? 'Thử tải ảnh lại' : 'Tạo kế hoạch',
              saving: _saving,
              onPressed: _name.text.trim().isEmpty ? null : _save,
            ),
            if (_chained)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop<QuickCreated>((
                        id: widget.teamId!,
                        name: widget.teamName ?? 'Team',
                        isTeam: true,
                      )),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Để sau'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamOption extends StatelessWidget {
  const _TeamOption({required this.id, required this.name});

  final String? id;
  final String name;

  @override
  Widget build(BuildContext context) => RadioListTile<String?>.adaptive(
    value: id,
    dense: true,
    contentPadding: const EdgeInsets.only(left: 32),
    controlAffinity: ListTileControlAffinity.trailing,
    title: Text(name),
  );
}

// ---------------------------------------------------------------------------
// Team

class _QuickCreateTeamSheet extends ConsumerStatefulWidget {
  const _QuickCreateTeamSheet({required this.pickImage});

  final ProjectCoverImagePicker pickImage;

  @override
  ConsumerState<_QuickCreateTeamSheet> createState() =>
      _QuickCreateTeamSheetState();
}

class _QuickCreateTeamSheetState extends ConsumerState<_QuickCreateTeamSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _memberIds = {};
  bool _descOpen = false;
  bool _membersOpen = false;
  bool _saving = false;
  String? _error;

  /// Team đã tạo: sheet chuyển sang bước "Kế hoạch đầu tiên".
  ({String id, String name})? _created;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final team = await ref
          .read(plansApiProvider)
          .createTeam(
            name: name,
            description: _description.text,
            memberIds: _memberIds,
          );
      ref.invalidate(teamsWithPlansProvider);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _created = (id: team.id, name: team.name));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return AnimatedSwitcher(
      duration: OmniMotion.of(context).base,
      child: created != null
          ? QuickCreatePlanForm(
              key: const ValueKey('chained-plan'),
              teamId: created.id,
              teamName: created.name,
              pickImage: widget.pickImage,
            )
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final members = ref.watch(teamMembersProvider);
    final byId = ref.watch(teamMemberByIdProvider);
    final picked = [for (final id in _memberIds) ?byId[id]];

    return SingleChildScrollView(
      key: const Key('quick-create-team'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader('Team mới'),
          OmniField(
            label: 'Tên team',
            child: TextField(
              key: const Key('quick-team-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Tổ sản xuất, Nhóm kinh doanh…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          _DisclosureRow(
            key: const Key('quick-team-desc'),
            icon: Icons.notes_rounded,
            label: 'Mô tả',
            value: _description.text.trim().isEmpty
                ? 'Tuỳ chọn'
                : _description.text.trim(),
            expanded: _descOpen,
            onTap: () => setState(() => _descOpen = !_descOpen),
          ),
          if (_descOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _description,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Team này làm gì'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          _DisclosureRow(
            key: const Key('quick-team-members'),
            icon: Icons.person_add_alt_outlined,
            label: 'Thành viên',
            value: _memberIds.isEmpty
                ? 'Thêm sau cũng được'
                : '${_memberIds.length} người',
            expanded: _membersOpen,
            onTap: () => setState(() => _membersOpen = !_membersOpen),
          ),
          if (picked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in picked)
                    Tooltip(
                      message: m.name,
                      child: OmniAvatar(
                        name: m.name,
                        imageUrl: m.avatarUrl,
                        size: 30,
                      ),
                    ),
                ],
              ),
            ),
          if (_membersOpen)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: members.when(
                data: (all) {
                  final shown = withPickedMembers(all, _memberIds, byId);
                  if (shown.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Chưa có ai trong workspace. Mời người vào trước.',
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final m = shown[i];
                      final on = _memberIds.contains(m.userId);
                      return CheckboxListTile.adaptive(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 4),
                        value: on,
                        secondary: OmniAvatar(
                          name: m.name,
                          imageUrl: m.avatarUrl,
                          size: 32,
                        ),
                        title: Text(m.name),
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (on) {
                              _memberIds.remove(m.userId);
                            } else {
                              _memberIds.add(m.userId);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
                error: (e, _) => OmniErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(teamDirectoryProvider),
                ),
              ),
            ),
          _errorText(context, _error),
          _saveButton(
            key: const Key('quick-team-save'),
            label: 'Tạo team',
            saving: _saving,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
