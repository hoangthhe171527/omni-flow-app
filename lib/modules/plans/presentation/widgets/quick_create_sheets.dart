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

OmniSheetHeader _sheetHeader(BuildContext context, String title) =>
    OmniSheetHeader(
      title: title,
      trailing: OmniGlassCircle(
        child: IconButton(
          tooltip: 'Đóng',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );

Widget _chevron(BuildContext context, bool expanded) => AnimatedRotation(
  turns: expanded ? 0.25 : 0,
  duration: OmniMotion.of(context).fast,
  child: Icon(
    Icons.chevron_right_rounded,
    size: 18,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
);

Widget _groupField({
  required BuildContext context,
  required String label,
  required Widget child,
  bool required = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (required)
              Text(' *', style: OmniType.caption.copyWith(color: scheme.error)),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

InputDecoration _bareDecoration(BuildContext context, String hint) {
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    hintStyle: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
    isDense: true,
    contentPadding: EdgeInsets.zero,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );
}

Widget _errorText(BuildContext context, String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
}) => FilledButton(
  key: key,
  onPressed: saving ? null : onPressed,
  child: saving
      ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        )
      : Text(label),
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

    final iconBg = scheme.primary.withValues(alpha: .10);

    return OmniSheetBody(
      key: const Key('quick-create-plan'),
      header: _sheetHeader(
        context,
        _chained ? 'Kế hoạch đầu tiên' : 'Kế hoạch mới',
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _saveButton(
            key: const Key('quick-plan-save'),
            label: _createdId != null ? 'Thử tải ảnh lại' : 'Tạo kế hoạch',
            saving: _saving,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
          if (_chained) ...[
            const SizedBox(height: 4),
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
        ],
      ),
      children: [
        if (_chained)
          Container(
            key: const Key('quick-team-created'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
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
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            _groupField(
              context: context,
              label: 'Tên kế hoạch',
              child: TextField(
                key: const Key('quick-plan-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                decoration: _bareDecoration(context, 'Đàn cơ'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
        OmniGroupSection(
          dividerIndent: 54,
          children: [
            if (!_chained) ...[
              OmniGroupRow(
                key: const Key('quick-plan-team'),
                leading: OmniIconTile(
                  Icons.groups_2_outlined,
                  color: scheme.primary,
                  background: iconBg,
                ),
                title: 'Thuộc team',
                value: teamLabel,
                chevron: false,
                trailing: _chevron(context, _teamOpen),
                onTap: () => setState(() => _teamOpen = !_teamOpen),
              ),
              if (_teamOpen)
                for (final (id, name) in <(String?, String)>[
                  (null, 'Chưa thuộc team'),
                  for (final t in teams) (t.id, t.name),
                ])
                  OmniGroupRow(
                    title: name,
                    selected: _teamId == id,
                    chevron: false,
                    onTap: () => setState(() {
                      _teamId = id;
                      _teamOpen = false;
                    }),
                  ),
            ],
            OmniGroupRow(
              key: const Key('quick-plan-sections'),
              leading: OmniIconTile(
                Icons.view_week_outlined,
                color: scheme.primary,
                background: iconBg,
              ),
              title: 'Nhóm việc',
              value: _sections.join(' · '),
              chevron: false,
              trailing: _chevron(context, _sectionsOpen),
              onTap: () => setState(() => _sectionsOpen = !_sectionsOpen),
            ),
            if (_sectionsOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _sections.length; i++)
                          if (_sections.length > 1)
                            Tooltip(
                              message: 'Bỏ nhóm ${_sections[i]}',
                              child: OmniChoicePill(
                                label: _sections[i],
                                selected: true,
                                icon: Icons.close_rounded,
                                onTap: () =>
                                    setState(() => _sections.removeAt(i)),
                              ),
                            )
                          else
                            OmniChoicePill(
                              label: _sections[i],
                              selected: true,
                              onTap: null,
                            ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('quick-plan-new-section'),
                            controller: _newSection,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            style: OmniType.body.copyWith(
                              color: scheme.onSurface,
                            ),
                            decoration: _bareDecoration(
                              context,
                              'Thêm nhóm việc',
                            ),
                            onSubmitted: (_) => _addSection(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Thêm nhóm việc',
                          icon: Icon(Icons.add_rounded, color: scheme.primary),
                          onPressed: _addSection,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            OmniGroupRow(
              key: const Key('quick-plan-cover'),
              leading: OmniIconTile(
                Icons.image_outlined,
                color: scheme.primary,
                background: iconBg,
              ),
              title: 'Ảnh nền',
              value: _coverPath == null ? 'Tuỳ chọn' : 'Đã chọn ảnh',
              onTap: _pickCover,
            ),
            if (_coverPath != null)
              OmniGroupRow(
                title: 'Bỏ ảnh',
                destructive: true,
                onTap: () => setState(() => _coverPath = null),
              ),
          ],
        ),
        if (_error != null) _errorText(context, _error),
      ],
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    final iconBg = scheme.primary.withValues(alpha: .10);
    final members = ref.watch(teamMembersProvider);
    final byId = ref.watch(teamMemberByIdProvider);
    final picked = [for (final id in _memberIds) ?byId[id]];

    return OmniSheetBody(
      key: const Key('quick-create-team'),
      header: _sheetHeader(context, 'Team mới'),
      footer: _saveButton(
        key: const Key('quick-team-save'),
        label: 'Tạo team',
        saving: _saving,
        onPressed: _name.text.trim().isEmpty ? null : _save,
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            _groupField(
              context: context,
              label: 'Tên team',
              child: TextField(
                key: const Key('quick-team-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                decoration: _bareDecoration(
                  context,
                  'Tổ sản xuất, Nhóm kinh doanh…',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        OmniGroupSection(
          dividerIndent: 54,
          children: [
            OmniGroupRow(
              key: const Key('quick-team-desc'),
              leading: OmniIconTile(
                Icons.notes_rounded,
                color: scheme.primary,
                background: iconBg,
              ),
              title: 'Mô tả',
              value: _description.text.trim().isEmpty
                  ? 'Tuỳ chọn'
                  : _description.text.trim(),
              chevron: false,
              trailing: _chevron(context, _descOpen),
              onTap: () => setState(() => _descOpen = !_descOpen),
            ),
            if (_descOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: TextField(
                  controller: _description,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: OmniType.body.copyWith(color: scheme.onSurface),
                  decoration: _bareDecoration(context, 'Team này làm gì'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            OmniGroupRow(
              key: const Key('quick-team-members'),
              leading: OmniIconTile(
                Icons.person_add_alt_outlined,
                color: scheme.primary,
                background: iconBg,
              ),
              title: 'Thành viên',
              value: _memberIds.isEmpty
                  ? 'Thêm sau cũng được'
                  : '${_memberIds.length} người',
              chevron: false,
              trailing: _chevron(context, _membersOpen),
              onTap: () => setState(() => _membersOpen = !_membersOpen),
            ),
            if (picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(54, 8, 14, 10),
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
              ...switch (members) {
                AsyncData(:final value) => () {
                  final shown = withPickedMembers(value, _memberIds, byId);
                  if (shown.isEmpty) {
                    return <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Chưa có ai trong workspace. Mời người vào trước.',
                          style: OmniType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ];
                  }
                  return <Widget>[
                    for (final m in shown)
                      OmniGroupRow(
                        leading: OmniAvatar(
                          name: m.name,
                          imageUrl: m.avatarUrl,
                          size: 32,
                        ),
                        title: m.name,
                        selected: _memberIds.contains(m.userId),
                        chevron: false,
                        onTap: () => setState(() {
                          if (!_memberIds.remove(m.userId)) {
                            _memberIds.add(m.userId);
                          }
                        }),
                      ),
                  ];
                }(),
                AsyncError(:final error) => <Widget>[
                  OmniErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(teamDirectoryProvider),
                  ),
                ],
                _ => <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ],
              },
          ],
        ),
        if (_error != null) _errorText(context, _error),
      ],
    );
  }
}
