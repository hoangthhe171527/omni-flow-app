import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/client_id.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';

/// Sửa các nhóm việc của một dự án đã có.
///
/// Trước đây nhóm việc chỉ khai được LÚC TẠO, nên một cái tên gõ nhầm hay một
/// quy trình đổi đi là phải tạo lại cả dự án — mà công việc thì đã nằm
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

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId));
    final text = Theme.of(context).textTheme;

    final loaded = plan.valueOrNull;
    if (loaded != null && _sections == null) {
      _sections = [...loaded.sections];
    }
    final sections = _sections;

    return Scaffold(
      // "Lưu" nằm trên thanh trên như thiết kế (`MEditSections.dc.html`): danh
      // sách dài thì nút ở cuối trang phải cuộn mới thấy.
      appBar: OmniAppBar(
        title: 'Nhóm việc',
        fallbackBack: () => context.go('/plans/${widget.planId}'),
        actions: [
          if (sections != null)
            TextButton(
              onPressed: _canSave(sections) ? () => _save(sections) : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
                textStyle: OmniType.body.copyWith(fontWeight: FontWeight.w600),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
        ],
      ),
      body: sections == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
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
                    // Dự án phải còn ít nhất một cột, nếu không cái bảng
                    // không còn chỗ nào để hiện việc.
                    onRemove: sections.length > 1
                        ? () => setState(() => sections.removeAt(i))
                        : null,
                  ),
                OmniGroupSection(
                  children: [
                    OmniGroupRow.add(
                      title: 'Thêm nhóm việc',
                      onTap: () => setState(() {
                        sections.add(
                          PlanSection(
                            // Id ngẫu nhiên như server và web: id đoán được
                            // (`sN`) có thể trùng nhóm đã xoá mà việc còn trỏ
                            // tới, và các việc đó sẽ lặng lẽ hiện vào nhóm mới.
                            id: newClientId(),
                            name: '',
                            order: sections.length,
                          ),
                        );
                      }),
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

  bool _canSave(List<PlanSection> sections) =>
      !_saving && sections.every((s) => s.name.trim().isNotEmpty);

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

  /// Xoá không lặp ở từng nhóm: vào menu ⋯ của dòng tên, rồi hỏi xác nhận.
  Future<void> _options() async {
    final remove = await showOmniSheet<bool>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(
          title: widget.section.name.trim().isEmpty
              ? 'Nhóm việc'
              : widget.section.name.trim(),
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(sheet).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        children: [
          OmniGroupSection(
            children: [
              OmniGroupRow(
                icon: Icons.delete_outline_rounded,
                title: 'Xoá nhóm việc',
                destructive: true,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;

    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá nhóm việc này?',
      message:
          'Xoá một nhóm không xoá việc trong đó — việc sẽ hiện ở cột đầu '
          'tiên cho tới khi được xếp lại.',
      confirmLabel: 'Xoá nhóm',
      destructive: true,
    );
    if (confirmed && mounted) widget.onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gated =
        widget.section.requiresChecklist || widget.section.countsForKpi;

    // Mỗi nhóm việc là một nhóm lồng: dòng tên (chạm để đổi tên), hai dòng
    // công tắc — toàn bộ thẳng trục 54px với OmniIconTile 1 tông.
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
      child: OmniGroupSection(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              child: Row(
                children: [
                  const OmniIconTile(Icons.view_column_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          style: OmniType.bodyStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Tên nhóm việc',
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: widget.onChanged,
                        ),
                        if (gated)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              _rulesOf(widget.section),
                              style: OmniType.caption.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.onRemove != null)
                    IconButton(
                      onPressed: _options,
                      icon: const Icon(Icons.more_horiz_rounded),
                      tooltip: 'Tuỳ chọn nhóm việc',
                    ),
                ],
              ),
            ),
          ),
          // Đặt ngay tại đây chứ không giấu sau một màn khác: quản đốc đứng
          // giữa xưởng với cái điện thoại, và cho tới giờ hai cờ này chỉ bật
          // được từ web. Nhãn nói HẬU QUẢ chứ không nói tên cờ — bật nhầm thì
          // bảng trông y hệt, chỉ có con số cuối tháng khác đi.
          OmniGroupRow(
            icon: Icons.playlist_add_check_rounded,
            title: 'Chặn vào nhóm khi việc con chưa xong',
            trailing: Switch.adaptive(
              value: widget.section.requiresChecklist,
              onChanged: (on) {
                HapticFeedback.selectionClick();
                widget.onGateChanged(on);
              },
            ),
          ),
          OmniGroupRow(
            icon: Icons.flag_outlined,
            title: 'Nhóm này là đích đếm KPI tháng',
            trailing: Switch.adaptive(
              value: widget.section.countsForKpi,
              onChanged: (on) {
                HapticFeedback.selectionClick();
                widget.onKpiChanged(on);
              },
            ),
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
