import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';

/// Sửa các nhóm việc của một kế hoạch đã có.
///
/// Trước đây nhóm việc chỉ khai được LÚC TẠO, nên một cái tên gõ nhầm hay một
/// quy trình đổi đi là phải tạo lại cả kế hoạch — mà công việc thì đã nằm
/// trong đó rồi.
///
/// Hai điều màn này giữ chặt:
///
///  * Id của nhóm ĐÃ CÓ không bao giờ đổi. `section_id` trên từng công việc
///    trỏ vào chính những id đó, nên sinh id mới cho một nhóm chỉ đổi tên sẽ
///    làm mọi công việc trong nhóm rơi về cột đầu.
///  * Cờ cổng QC và cờ đếm KPI đi theo nguyên vẹn. API thay cả mảng
///    `sections`, nên đánh rơi chúng là xoá lặng lẽ hai quy tắc mà cả cơ chế
///    trả thưởng dựa vào.
class EditSectionsPage extends ConsumerStatefulWidget {
  const EditSectionsPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<EditSectionsPage> createState() => _EditSectionsPageState();
}

class _EditSectionsPageState extends ConsumerState<EditSectionsPage> {
  List<PlanSection>? _sections;
  bool _saving = false;
  String? _error;

  /// Id đã từng dùng trong kế hoạch này, KỂ CẢ nhóm vừa xoá khỏi màn.
  ///
  /// Nhóm mới không được nhận lại id của một nhóm vừa bị bỏ: công việc cũ vẫn
  /// đang trỏ vào id đó, và chúng sẽ lặng lẽ xuất hiện trong nhóm mới.
  final _usedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final loaded = plan.valueOrNull;
    if (loaded != null && _sections == null) {
      _sections = [...loaded.sections];
      _usedIds.addAll(loaded.sections.map((s) => s.id));
    }
    final sections = _sections;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm việc')),
      body: sections == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                Text(
                  'Mỗi nhóm việc là một cột trên bảng.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: OmniSpacing.lg),
                for (var i = 0; i < sections.length; i++)
                  _SectionRow(
                    key: ValueKey(sections[i].id),
                    section: sections[i],
                    // setState chứ không gán suông: nút Lưu tắt/bật theo chỗ
                    // có nhóm nào chưa đặt tên hay không, nên gõ xong một cái
                    // tên mà không dựng lại thì nút vẫn cứ tắt.
                    onChanged: (name) => setState(() {
                      sections[i] = PlanSection(
                        id: sections[i].id,
                        name: name,
                        order: i,
                        requiresChecklist: sections[i].requiresChecklist,
                        countsForKpi: sections[i].countsForKpi,
                      );
                    }),
                    // Hai cờ này là quy tắc TRẢ TIỀN, không phải trình bày:
                    // chúng quyết định một việc có bị chặn ở cổng QC hay
                    // không, và nhóm nào là đích đếm KPI tháng. Trước đây màn
                    // này chỉ mang chúng đi theo khi lưu, nên chúng chỉ đặt
                    // được từ web — tức là ở xưởng thì không đặt được.
                    onGateChanged: (on) => setState(() {
                      sections[i] = PlanSection(
                        id: sections[i].id,
                        name: sections[i].name,
                        order: i,
                        requiresChecklist: on,
                        countsForKpi: sections[i].countsForKpi,
                      );
                    }),
                    onKpiChanged: (on) => setState(() {
                      sections[i] = PlanSection(
                        id: sections[i].id,
                        name: sections[i].name,
                        order: i,
                        requiresChecklist: sections[i].requiresChecklist,
                        countsForKpi: on,
                      );
                    }),
                    // Kế hoạch phải còn ít nhất một cột, nếu không cái bảng
                    // không còn chỗ nào để hiện việc.
                    onRemove: sections.length > 1
                        ? () => setState(() => sections.removeAt(i))
                        : null,
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      sections.add(
                        PlanSection(
                          id: _nextId(),
                          name: '',
                          order: sections.length,
                        ),
                      );
                    }),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm nhóm việc'),
                  ),
                ),
                const SizedBox(height: OmniSpacing.lg),
                Text(
                  'Xoá một nhóm không xoá việc trong đó — việc sẽ hiện ở cột '
                  'đầu tiên cho tới khi được xếp lại.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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
                const SizedBox(height: OmniSpacing.xl),
                FilledButton(
                  onPressed: _canSave(sections) ? () => _save(sections) : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ],
            ),
    );
  }

  bool _canSave(List<PlanSection> sections) =>
      !_saving && sections.every((s) => s.name.trim().isNotEmpty);

  /// Id chưa từng dùng trong kế hoạch này.
  String _nextId() {
    var n = _usedIds.length + 1;
    while (_usedIds.contains('s$n')) {
      n++;
    }
    _usedIds.add('s$n');

    return 's$n';
  }

  Future<void> _save(List<PlanSection> sections) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(plansApiProvider).updateSections(widget.planId, [
        for (final s in sections)
          PlanSection(
            id: s.id,
            name: s.name.trim(),
            order: s.order,
            requiresChecklist: s.requiresChecklist,
            countsForKpi: s.countsForKpi,
          ),
      ]);

      if (!mounted) return;
      // Bảng đang mở phía sau đọc từ hai provider này.
      ref.invalidate(planProvider(widget.planId));
      ref.invalidate(planTasksProvider(widget.planId));
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }
}

class _SectionRow extends StatefulWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.onChanged,
    required this.onGateChanged,
    required this.onKpiChanged,
    this.onRemove,
  });

  final PlanSection section;
  final ValueChanged<String> onChanged;

  /// Bật/tắt cổng QC của nhóm này.
  ///
  /// Bắt buộc chứ không cho null: một hàng không đổi được cờ trông y hệt một
  /// hàng đổi được, và im lặng như thế đúng là cách khiếm khuyết này sống
  /// được nhiều tháng.
  final ValueChanged<bool> onGateChanged;

  /// Bật/tắt việc nhóm này có phải đích đếm KPI tháng hay không.
  final ValueChanged<bool> onKpiChanged;

  final VoidCallback? onRemove;

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow> {
  late final _controller = TextEditingController(text: widget.section.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gated =
        widget.section.requiresChecklist || widget.section.countsForKpi;

    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Tên nhóm việc',
                    isDense: true,
                    // Nói ra nhóm nào đang mang quy tắc, để người sửa biết
                    // mình đang đụng vào thứ gì trước khi xoá nó.
                    helperText: gated ? _rulesOf(widget.section) : null,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(
                  Icons.close_rounded,
                  color: widget.onRemove == null
                      ? scheme.onSurfaceVariant
                      : null,
                ),
                tooltip: 'Bỏ nhóm việc này',
              ),
            ],
          ),
          // Đặt ngay tại đây chứ không giấu sau một màn khác: quản đốc đứng
          // giữa xưởng với cái điện thoại, và cho tới giờ hai cờ này chỉ bật
          // được từ web. Nhãn nói HẬU QUẢ chứ không nói tên cờ — bật nhầm thì
          // bảng trông y hệt, chỉ có con số cuối tháng khác đi.
          SwitchListTile(
            value: widget.section.requiresChecklist,
            onChanged: widget.onGateChanged,
            title: const Text('Chặn vào nhóm khi việc con chưa xong'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: widget.section.countsForKpi,
            onChanged: widget.onKpiChanged,
            title: const Text('Nhóm này là đích đếm KPI tháng'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  static String _rulesOf(PlanSection section) => [
    if (section.requiresChecklist) 'cần xong hết việc con',
    if (section.countsForKpi) 'đếm vào KPI tháng',
  ].join(' · ');
}
