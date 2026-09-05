import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/team.dart';

/// Năm công đoạn của xưởng piano, điền sẵn.
///
/// Lấy từ `docs/TNP_PIANO_WORKSHOP_FLOW.md`: Nhập xưởng → Đang phục chế →
/// Chờ QC → Hoàn thiện → Đã giao. Điền sẵn chứ không bắt buộc — một xưởng
/// khác sửa được, nhưng xưởng này thì không phải gõ lại năm lần cho mỗi kế
/// hoạch mới.
const kWorkshopSections = <String>[
  'Nhập xưởng',
  'Đang phục chế',
  'Chờ QC',
  'Hoàn thiện',
  'Đã giao',
];

class CreatePlanPage extends ConsumerStatefulWidget {
  const CreatePlanPage({super.key});

  @override
  ConsumerState<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends ConsumerState<CreatePlanPage> {
  final _name = TextEditingController();
  final _sections = [...kWorkshopSections];
  String? _teamId;
  bool _saving = false;
  String? _error;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Kế hoạch mới')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.bottomSafe,
        ),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên kế hoạch',
              hintText: 'Đàn cơ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OmniSpacing.lg),
          _TeamPicker(
            teams: [
              for (final group in teams.valueOrNull ?? const []) group.team,
            ],
            selected: _teamId,
            onChanged: (id) => setState(() => _teamId = id),
          ),
          const SizedBox(height: OmniSpacing.xxl),
          Text(
            'Nhóm việc',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Mỗi nhóm việc là một công đoạn, và là một cột trên bảng.',
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
          const SizedBox(height: OmniSpacing.xxl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tạo kế hoạch'),
          ),
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
            // Bỏ dòng trống: người dùng bấm "Thêm nhóm việc" rồi đổi ý là
            // chuyện thường, và một cột không tên trên bảng thì vô dụng.
            sectionNames: [
              for (final s in _sections)
                if (s.trim().isNotEmpty) s.trim(),
            ],
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
    // Chưa có team nào thì không hỏi: kế hoạch không thuộc team vẫn chạy được,
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
                hintText: 'Tên công đoạn ${widget.index + 1}',
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
