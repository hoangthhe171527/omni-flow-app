import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../security/session/session_controller.dart';
import '../../data/plans_api.dart';
import '../../domain/board_unit.dart';

/// Lựa chọn ở tấm "Thêm việc": gõ tên, chọn cây, hoặc mở trang tạo đầy đủ.
sealed class AddTaskChoice {
  const AddTaskChoice();
}

class AddTypedTask extends AddTaskChoice {
  const AddTypedTask(this.title);
  final String title;
}

class AddUnitTasks extends AddTaskChoice {
  const AddUnitTasks(this.unitIds);
  final List<String> unitIds;
}

class OpenFullCreate extends AddTaskChoice {
  const OpenFullCreate();
}

/// Kiểu thêm dùng lần trước (bản mẫu: "Mặc định nhớ kiểu dùng lần trước").
final addTaskModeProvider = StateProvider<int>((ref) => 0);

/// Có xem được Kho để chọn cây không: capability `inventory` + `inventory.read`.
final canPickUnitsProvider = Provider<bool>((ref) {
  final s = ref.watch(sessionProvider);
  return s.apiSupports('inventory') && s.policy.can('inventory.read');
});

/// Tấm "Thêm việc" khi bấm + ở cột (TNP_DON_HANG_THEO_CAY §6, bản mẫu 7LZPEX
/// "App · Thêm việc"): Gõ tên / Chọn đàn. Trang tạo đầy đủ vẫn mở được.
Future<AddTaskChoice?> showAddTaskSheet(
  BuildContext context, {
  required String sectionName,
}) => showOmniSheet<AddTaskChoice>(
  context: context,
  builder: (_) => _AddTaskSheet(sectionName: sectionName),
);

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({required this.sectionName});
  final String sectionName;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  final _picked = <String, BoardUnit>{};
  String _q = '';
  List<BoardUnit> _found = const [];
  bool _loading = false;
  Object? _error;
  int _seq = 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final needle = q.trim();
    setState(() => _q = needle);
    if (needle.length < 2) {
      setState(() => _found = const []);
      return;
    }
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(plansApiProvider).searchUnits(needle);
      if (!mounted || seq != _seq) return;
      setState(() => _found = rows);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e);
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  void _toggle(BoardUnit u) => setState(() {
    if (_picked.remove(u.id) == null) _picked[u.id] = u;
  });

  @override
  Widget build(BuildContext context) {
    final canPick = ref.watch(canPickUnitsProvider);
    final mode = canPick ? ref.watch(addTaskModeProvider) : 0;
    final title = _title.text.trim();

    final Widget footer;
    final List<Widget> children;
    if (mode == 0) {
      children = [
        TextField(
          key: const Key('add-task-title'),
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Tên việc'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              Navigator.of(context).pop(AddTypedTask(v.trim()));
            }
          },
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const Key('add-task-full'),
              title: 'Thêm chi tiết',
              icon: Icons.tune_rounded,
              onTap: () => Navigator.of(context).pop(const OpenFullCreate()),
            ),
          ],
        ),
      ];
      footer = FilledButton(
        key: const Key('add-task-submit'),
        onPressed: title.isEmpty
            ? null
            : () => Navigator.of(context).pop(AddTypedTask(title)),
        child: const Text('Thêm việc'),
      );
    } else {
      // Cây đã chọn luôn hiện đầu danh sách, kể cả khi đổi từ khoá.
      final rows = [
        ..._picked.values,
        for (final u in _found)
          if (!_picked.containsKey(u.id)) u,
      ];
      children = [
        OmniSearchField(
          key: const Key('add-task-unit-search'),
          hint: 'Tìm serial, model',
          onChanged: _search,
        ),
        if (rows.isNotEmpty)
          OmniGroupSection(
            children: [
              for (final u in rows)
                OmniGroupRow(
                  key: ValueKey('add-task-unit-${u.id}'),
                  title: [u.label, ?u.serial].join(' '),
                  subtitle: u.busy
                      ? 'Đang ở ${u.busySection ?? 'xưởng'}'
                      : [?u.customerName, ?u.lotCode].join(' · '),
                  selected: _picked.containsKey(u.id),
                  chevron: false,
                  onTap: u.busy ? null : () => _toggle(u),
                ),
            ],
          )
        else if (_loading)
          const OmniGroupSection(
            children: [OmniGroupRow(title: 'Đang tìm…', chevron: false)],
          )
        else if (_error != null)
          const OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Không tải được danh sách cây',
                chevron: false,
              ),
            ],
          )
        else if (_q.length >= 2)
          const OmniGroupSection(
            children: [
              OmniGroupRow(title: 'Không có cây khớp', chevron: false),
            ],
          ),
      ];
      footer = FilledButton(
        key: const Key('add-task-submit'),
        onPressed: _picked.isEmpty
            ? null
            : () => Navigator.of(
                context,
              ).pop(AddUnitTasks(_picked.keys.toList())),
        child: Text(
          _picked.isEmpty ? 'Thêm việc' : 'Thêm ${_picked.length} việc',
        ),
      );
    }

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Thêm việc',
        subtitle: 'vào ${widget.sectionName}',
      ),
      footer: footer,
      children: [
        if (canPick)
          OmniSegmented(
            labels: const ['Gõ tên', 'Chọn đàn'],
            index: mode,
            onChanged: (i) => ref.read(addTaskModeProvider.notifier).state = i,
          ),
        ...children,
      ],
    );
  }
}
