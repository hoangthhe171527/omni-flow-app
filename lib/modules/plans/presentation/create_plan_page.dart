import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
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
  String _cover = OmniCovers.fallback;
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Bố cục `MCreatePlan.dc.html`: nền trắng, xem trước nền dự án, các ô có
    // nhãn phía trên, nút "Tạo dự án" ghim ở đáy.
    final label = OmniType.body.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: const CloseButton(),
        title: const Text('Dự án mới'),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tạo dự án'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, OmniSpacing.sm, 20, 24),
        children: [
          // Xem trước NGAY: tên hiện trên chính dải nền trong lúc gõ, nên
          // người tạo thấy kết quả thật thay vì đoán. Đây cũng là chỗ kiểm
          // được bằng mắt rằng nền đủ tối cho chữ trắng, ngay tại chỗ chọn.
          Container(
            height: 120,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: OmniCovers.gradientOf(_cover),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    _name.text.trim().isEmpty ? 'Dự án mới' : _name.text.trim(),
                    style: OmniType.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OmniField(
            label: 'Tên dự án',
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Đàn cơ'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 18),
          Text('Nền', style: label),
          const SizedBox(height: OmniSpacing.sm),
          CoverPicker(
            value: _cover,
            onChanged: (value) => setState(() => _cover = value),
          ),
          // Ô chọn team ẩn khi tới từ luồng "vừa tạo team xong": người dùng
          // vừa tạo đúng cái team đó, và cho họ đổi ở đây chỉ mời một cú bấm
          // nhầm ngay sau khi đã quyết định.
          if (widget.teamId == null) ...[
            const SizedBox(height: OmniSpacing.lg),
            _TeamPicker(
              teams: [
                for (final group in teams.valueOrNull ?? const []) group.team,
              ],
              selected: _teamId,
              onChanged: (id) => setState(() => _teamId = id),
            ),
          ],
          const SizedBox(height: OmniSpacing.xxl),
          Text('Nhóm việc', style: label),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Mỗi nhóm việc là một cột trên bảng.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.md),
          for (var i = 0; i < _sections.length; i++)
            _SectionRow(
              key: ValueKey('section-$i'),
              index: i,
              name: _sections[i],
              onChanged: (value) => _sections[i] = value,
              onRemove: _sections.length > 1
                  ? () => setState(() => _sections.removeAt(i))
                  : null,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _sections.add('')),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm nhóm việc'),
            ),
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(plansApiProvider)
          .createPlan(
            name: _name.text.trim(),
            teamId: _teamId,
            cover: _cover,
            // Bỏ dòng trống: người dùng bấm "Thêm nhóm việc" rồi đổi ý là
            // chuyện thường, và một cột không tên trên bảng thì vô dụng.
            sectionNames: [
              for (final s in _sections)
                if (s.trim().isNotEmpty) s.trim(),
            ],
            gatedSectionNames: kGatedDefaultSections,
          );

      ref.invalidate(teamsWithPlansProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }
}

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({
    required this.teams,
    required this.selected,
    required this.onChanged,
  });

  final List<Team> teams;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Chưa có team nào thì không hỏi: dự án không thuộc team vẫn chạy được,
    // và một ô chọn rỗng chỉ làm người dùng tưởng mình thiếu bước nào đó.
    final real = teams.where((t) => t.id.isNotEmpty).toList();
    if (real.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Thuộc team'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Chưa thuộc team nào')),
        for (final team in real)
          DropdownMenuItem(value: team.id, child: Text(team.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _SectionRow extends StatefulWidget {
  const _SectionRow({
    super.key,
    required this.index,
    required this.name,
    required this.onChanged,
    this.onRemove,
  });

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
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Tên nhóm việc ${widget.index + 1}',
                isDense: true,
              ),
              onChanged: widget.onChanged,
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Bỏ nhóm việc này',
          ),
        ],
      ),
    );
  }
}
