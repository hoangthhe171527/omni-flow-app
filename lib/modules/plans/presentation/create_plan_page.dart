import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plan_cover_upload.dart';
import '../data/plans_api.dart';
import 'widgets/cover_picker.dart';
import '../domain/team.dart';

/// Bốn nhóm việc điền sẵn cho một dự án mới.
///
/// Cố ý CHUNG, không theo ngành nào. App này dùng cho nhiều loại công việc —
/// xưởng phục chế đàn chỉ là một khách hàng — nên thứ điền sẵn cho mọi tenant
/// phải là thứ ai đọc cũng hiểu. Bộ trước đây là năm cột của xưởng piano
/// ("Nhập xưởng → Đang phục chế → Chờ QC → …"), và mọi khách mới đều nhận
/// đúng năm chữ đó.
///
/// Điền sẵn chứ không bắt buộc: sửa, xoá, thêm đều được ngay trên màn tạo.
/// Khách có quy trình riêng khai một lần rồi nhân bản dự án hằng tháng
/// (`POST /projects/{id}/copy`), nên không ai phải gõ lại mỗi tháng.
const kDefaultSections = <String>['Cần làm', 'Đang làm', 'Chờ duyệt', 'Xong'];

/// Nhóm việc nào đặt CỔNG: vào đây thì mọi việc con phải xong trước.
///
/// "Chờ duyệt" và "Xong" là hai chỗ một công việc được tuyên bố là làm xong —
/// và tuyên bố đó sai khi việc con còn dở. Hai nhóm đầu không có cổng, vì
/// chúng là nơi việc đang chạy.
///
/// Chỉ áp cho dự án tạo MỚI bằng bộ điền sẵn. Dự án đã có và nhóm việc
/// người dùng tự thêm đều không có cổng — bật cổng cho dữ liệu cũ là chặn
/// công việc đang chạy bằng một quy tắc nó chưa từng biết.
const kGatedDefaultSections = <String>{'Chờ duyệt', 'Xong'};

class CreatePlanPage extends ConsumerStatefulWidget {
  const CreatePlanPage({super.key, this.teamId});

  /// Team điền sẵn khi tới từ luồng "vừa tạo team xong".
  ///
  /// Không null thì ô chọn team KHÔNG hiện: người dùng vừa tạo đúng cái team
  /// đó xong, và cho họ đổi ở đây chỉ mời một cú bấm nhầm.
  final String? teamId;

  @override
  ConsumerState<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends ConsumerState<CreatePlanPage> {
  final _name = TextEditingController();
  final _sections = [...kDefaultSections];
  String? _teamId;
  String? _coverPath;
  String? _createdPlanId;
  int _generation = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _teamId = widget.teamId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsWithPlansProvider);
    final text = Theme.of(context).textTheme;

    final realTeams = <Team>[
      for (final TeamWithPlans group in teams.valueOrNull ?? const [])
        if (group.team.id.isNotEmpty) group.team,
    ];
    final teamName = realTeams.where((t) => t.id == _teamId).firstOrNull?.name;

    return Scaffold(
      appBar: OmniAppBar(title: 'Kế hoạch mới', close: true),
      bottomNavigationBar: OmniActionBar(
        children: [
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(
                    _createdPlanId != null && _coverPath != null
                        ? 'Thử tải ảnh lại'
                        : 'Tạo kế hoạch',
                  ),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, OmniGroupSection.gap, 16, 24),
        children: [
          CoverPicker(
            localPath: _coverPath,
            title: _name.text.trim().isEmpty
                ? 'Kế hoạch mới'
                : _name.text.trim(),
            busy: _saving && _createdPlanId != null && _coverPath != null,
            onPicked: (path) => setState(() {
              _coverPath = path;
              _error = null;
            }),
            onRemove: _coverPath == null
                ? null
                : () => setState(() => _coverPath = null),
            onError: (message) => setState(() => _error = message),
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: OmniField(
                  label: 'Tên kế hoạch',
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Đàn cơ'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              // Dòng chọn team ẩn khi tới từ luồng "vừa tạo team xong": người
              // dùng vừa tạo đúng cái team đó, và cho họ đổi ở đây chỉ mời một
              // cú bấm nhầm ngay sau khi đã quyết định. Chưa có team nào thì
              // không hỏi: dự án không thuộc team vẫn chạy được.
              if (widget.teamId == null && realTeams.isNotEmpty)
                OmniGroupRow(
                  icon: Icons.groups_2_outlined,
                  title: 'Thuộc team',
                  value: teamName ?? 'Chưa thuộc team nào',
                  onTap: () => _pickTeam(realTeams),
                ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            title: 'Nhóm việc',
            dividerIndent: 14,
            children: [
              for (var i = 0; i < _sections.length; i++)
                _SectionRow(
                  key: ValueKey('section-$i'),
                  rowKey: ValueKey('section-$_generation-$i'),
                  index: i,
                  name: _sections[i],
                  onChanged: (value) => _sections[i] = value,
                  // Vuốt ngang để bỏ (thay cho nút X mỗi dòng). Còn ít nhất
                  // một cột, nếu không bảng không còn chỗ nào để hiện việc.
                  onRemove: _sections.length > 1
                      ? () => setState(() {
                          _sections.removeAt(i);
                          _generation++;
                        })
                      : null,
                ),
              OmniGroupRow.add(
                title: 'Thêm nhóm việc',
                onTap: () => setState(() => _sections.add('')),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: OmniSpacing.lg),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: OmniColors.dangerTextOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Sheet chọn team thay cho Dropdown Material.
  Future<void> _pickTeam(List<Team> teams) async {
    final picked = await showOmniSheet<({String? id})>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: const OmniSheetHeader(title: 'Thuộc team'),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(
                title: 'Chưa thuộc team nào',
                selected: _teamId == null,
                onTap: () => Navigator.of(sheet).pop((id: null)),
              ),
              for (final team in teams)
                OmniGroupRow(
                  title: team.name,
                  selected: _teamId == team.id,
                  onTap: () => Navigator.of(sheet).pop((id: team.id)),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _teamId = picked.id);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var planId = _createdPlanId;
      if (planId == null) {
        final created = await ref
            .read(plansApiProvider)
            .createPlan(
              name: _name.text.trim(),
              teamId: _teamId,
              // Bỏ dòng trống: người dùng bấm "Thêm nhóm việc" rồi đổi ý là
              // chuyện thường, và một cột không tên trên bảng thì vô dụng.
              sectionNames: [
                for (final s in _sections)
                  if (s.trim().isNotEmpty) s.trim(),
              ],
              gatedSectionNames: kGatedDefaultSections,
            );
        planId = created.id;
        _createdPlanId = planId;
        if (mounted && _coverPath != null) setState(() {});
      }

      if (_coverPath case final path?) {
        await ref.read(planCoverApiProvider).upload(planId, path);
      }

      ref.invalidate(teamsWithPlansProvider);
      ref.invalidate(planProvider(planId));
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(true);
      } else {
        setState(() => _saving = false);
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _createdPlanId == null
            ? e.message
            : 'Kế hoạch đã được tạo nhưng ảnh nền chưa tải lên. '
                  '${e.message} Bạn có thể thử lại mà không tạo bản trùng.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _createdPlanId == null
            ? 'Chưa tạo được kế hoạch. Vui lòng thử lại.'
            : 'Kế hoạch đã được tạo nhưng ảnh nền chưa tải lên. '
                  'Bạn có thể thử lại mà không tạo bản trùng.';
      });
    }
  }
}

class _SectionRow extends StatefulWidget {
  const _SectionRow({
    super.key,
    required this.rowKey,
    required this.index,
    required this.name,
    required this.onChanged,
    this.onRemove,
  });

  /// Khoá của lớp vuốt-để-bỏ; đổi khi danh sách đổi để ô nhập dựng lại đúng
  /// chữ của dòng mới đứng ở chỗ đó.
  final Key rowKey;
  final int index;
  final String name;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Tên nhóm việc ${widget.index + 1}',
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: widget.onChanged,
      ),
    );
    if (widget.onRemove == null) return field;

    return Dismissible(
      key: widget.rowKey,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onRemove!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: OmniColors.dangerTextOf(context).withValues(alpha: .12),
        child: Icon(
          Icons.delete_outline_rounded,
          color: OmniColors.dangerTextOf(context),
        ),
      ),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: field,
      ),
    );
  }
}
