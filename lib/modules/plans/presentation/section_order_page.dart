import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';

/// Trang 'Sắp xếp nhóm việc' (`AppSections.dc.html`): đổi thứ tự cột của bảng
/// bằng cách kéo tay cầm hoặc bấm mũi tên lên/xuống.
///
/// Chỉ đổi THỨ TỰ. Tên, xoá, cờ QC vẫn ở menu ⋯ của từng cột; trang này giữ
/// nguyên id và hai cờ (QC, KPI) của mọi nhóm vì API thay cả mảng `sections`.
///
/// Trả `true` qua `Navigator.pop` khi đã lưu.
class SectionOrderPage extends ConsumerStatefulWidget {
  const SectionOrderPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<SectionOrderPage> createState() => _SectionOrderPageState();
}

class _SectionOrderPageState extends ConsumerState<SectionOrderPage> {
  /// Thứ tự đang xếp. Nạp MỘT lần từ kế hoạch; tên và cờ thì luôn đọc từ bản
  /// kế hoạch mới nhất, chỉ thứ tự là của trang này.
  List<String>? _ids;
  List<String> _original = const [];
  bool _saving = false;

  bool get _dirty => _ids != null && !listEquals(_ids, _original);

  void _move(int from, int to) {
    final ids = _ids;
    if (ids == null || _saving) return;
    if (to < 0 || to >= ids.length || from == to) return;
    setState(() {
      final next = [...ids];
      next.insert(to, next.removeAt(from));
      _ids = next;
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    setState(() => _saving = true);
    try {
      // R8: ghép vào bản MỚI NHẤT, không ghi đè bằng bản lúc mở trang. Nhóm
      // người khác vừa thêm nối cuối, nhóm họ vừa xoá thì bỏ, tên mới giữ.
      final latest = await container.read(planProvider(widget.planId).future);
      final byId = {for (final s in latest.sections) s.id: s};
      final ids = _ids!;
      final merged = [
        for (final id in ids) ?byId[id],
        for (final s in latest.sections)
          if (!ids.contains(s.id)) s,
      ];
      await container
          .read(plansApiProvider)
          .updateSections(widget.planId, merged);
      container.invalidate(planProvider(widget.planId));
      if (!mounted) return;
      navigator.pop(true);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId)).valueOrNull;
    if (plan != null && _ids == null) {
      _original = [for (final s in plan.sections) s.id];
      _ids = [..._original];
    }
    final ids = _ids;
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);
    final byId = {
      for (final s in plan?.sections ?? const <PlanSection>[]) s.id: s,
    };
    final shown = [for (final id in ids ?? const <String>[]) ?byId[id]];

    final tasks = ref.watch(planTasksProvider(widget.planId)).valueOrNull;
    String? countOf(String sectionId) {
      if (tasks == null) return null;
      final n = tasks.tasks.where((t) => t.sectionId == sectionId).length;
      return '${tasks.truncated ? '≥' : ''}$n việc';
    }

    final reorderable = OmniMotion.enabled(context);

    Widget rowOf(int i) => _SectionRow(
      key: ValueKey('section-row-${shown[i].id}'),
      section: shown[i],
      index: i,
      first: i == 0,
      last: i == shown.length - 1,
      count: countOf(shown[i].id),
      showGrip: reorderable,
      onUp: () => _move(i, i - 1),
      onDown: () => _move(i, i + 1),
    );

    Widget box(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.smAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(borderRadius: OmniRadius.smAll, child: child),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          _TopBar(
            dirty: _dirty,
            saving: _saving,
            onSave: _dirty && !_saving ? _save : null,
          ),
          Expanded(
            child: ids == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      bottom: OmniSpacing.bottomSafe,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Giữ tay cầm '),
                                _glyph(
                                  Icons.drag_indicator_rounded,
                                  scheme.onSurfaceVariant,
                                ),
                                const TextSpan(
                                  text:
                                      ' rồi kéo lên/xuống, hoặc dùng mũi tên. '
                                      'Thứ tự này là thứ tự cột trên bảng.',
                                ),
                              ],
                            ),
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: box(
                            reorderable
                                ? ReorderableListView(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    proxyDecorator: (child, _, _) =>
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: scheme.surface,
                                            borderRadius: OmniRadius.smAll,
                                            boxShadow: OmniShadows.dragging,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: OmniRadius.smAll,
                                            child: Material(
                                              color: scheme.surface,
                                              child: child,
                                            ),
                                          ),
                                        ),
                                    onReorderItem: _move,
                                    children: [
                                      for (var i = 0; i < shown.length; i++)
                                        rowOf(i),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0; i < shown.length; i++)
                                        rowOf(i),
                                    ],
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text:
                                      'Chỉ chủ hoặc quản lý kế hoạch thấy màn này. '
                                      'Đổi tên, xoá, gắn cờ QC vẫn ở menu ',
                                ),
                                _glyph(Icons.more_horiz_rounded, tones.faint),
                                const TextSpan(text: ' của từng cột.'),
                              ],
                            ),
                            style: OmniType.micro.copyWith(
                              color: tones.faint,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          4,
          MediaQuery.paddingOf(context).top,
          8,
          0,
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Quay lại',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              Expanded(
                child: Text(
                  'Sắp xếp nhóm việc',
                  style: OmniType.section.copyWith(color: scheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: onSave,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: scheme.primary,
                  disabledForegroundColor: tones.faint,
                  textStyle: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.first,
    required this.last,
    required this.count,
    required this.showGrip,
    required this.onUp,
    required this.onDown,
  });

  final PlanSection section;
  final int index;
  final bool first;
  final bool last;
  final String? count;
  final bool showGrip;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);

    Widget arrow(
      String tooltip,
      IconData icon,
      bool enabled,
      VoidCallback cb,
    ) => Opacity(
      opacity: enabled ? 1 : 0.3,
      child: IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        onPressed: enabled ? cb : null,
        icon: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      ),
    );

    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: OmniColors.trackOf(context))),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              if (showGrip)
                ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label: 'Kéo để đổi chỗ ${section.name}',
                    child: ExcludeSemantics(
                      // Nền trong suốt chứ không SizedBox trần: chỉ ColoredBox
                      // mới nhận chạm trên cả vùng 44, không chỉ nét biểu tượng.
                      child: ColoredBox(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 16,
                            color: tones.faint,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (count != null)
                        Text(
                          count!,
                          style: OmniType.micro.copyWith(
                            fontWeight: FontWeight.w400,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (section.requiresChecklist)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: OmniColors.byBrightness(
                        context,
                        OmniColors.warningSoft,
                        OmniColors.darkWarningSoft,
                      ),
                      borderRadius: OmniRadius.xsAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'QC',
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w600,
                          color: OmniColors.warningTextOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              arrow('Lên trên', Icons.keyboard_arrow_up_rounded, !first, onUp),
              arrow(
                'Xuống dưới',
                Icons.keyboard_arrow_down_rounded,
                !last,
                onDown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Font của app không có ký tự ⋮ và ⋯ (`font_glyph_coverage_test`), nên đoạn
/// chữ nhắc tới tay cầm và nút ⋯ dùng chính biểu tượng đó chen vào dòng.
InlineSpan _glyph(IconData icon, Color color) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Icon(icon, size: 16, color: color),
);
