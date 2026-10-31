import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HapticFeedback.selectionClick();
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
    } catch (_) {
      // Lỗi không phải AppException cũng phải mở lại nút "Lưu", không để
      // vòng xoay quay mãi.
      messenger.showSnackBar(
        const SnackBar(content: Text('Không lưu được thứ tự. Thử lại nhé.')),
      );
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

    // Một vùng cuộn duy nhất (K11): bộ tự cuộn ở mép của SliverReorderableList
    // bám vào chính Scrollable này. Trước đây danh sách shrinkWrap nằm trong
    // SingleChildScrollView nên bộ tự cuộn bám vào Scrollable bên trong
    // (max = 0) và kéo tới mép thì đứng im.
    final rows = reorderable
        ? SliverReorderableList(
            itemCount: shown.length,
            itemBuilder: (context, i) => rowOf(i),
            // onReorderItem đã trừ sẵn dòng đang kéo khỏi chỉ số đích
            // (onReorder cũ thì chưa, và đã bị đánh dấu deprecated).
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderItem: _move,
            proxyDecorator: (child, _, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // Bóng lớn dần khi nhấc, nhỏ dần lúc bản nổi bay về (K13).
                final t = OmniCurves.standard.transform(animation.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: OmniRadius.smAll,
                    boxShadow: BoxShadow.lerpList(
                      const [],
                      OmniShadows.dragging,
                      t,
                    ),
                  ),
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: OmniRadius.smAll,
                child: Material(color: scheme.surface, child: child),
              ),
            ),
          )
        : SliverList.list(
            children: [for (var i = 0; i < shown.length; i++) rowOf(i)],
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
                ? const Center(child: CircularProgressIndicator.adaptive())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
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
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: DecoratedSliver(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: OmniRadius.smAll,
                          ),
                          // Viền vẽ ĐÈ lên nền các dòng, không bị dòng che.
                          sliver: DecoratedSliver(
                            position: DecorationPosition.foreground,
                            decoration: BoxDecoration(
                              borderRadius: OmniRadius.smAll,
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            sliver: rows,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text:
                                      'Chỉ chủ hoặc quản lý kế hoạch thấy màn này. '
                                      'Đổi tên, xoá, cờ QC/KPI: mục “Sửa nhóm việc” '
                                      'trong menu ',
                                ),
                                _glyph(Icons.more_horiz_rounded, tones.faint),
                                const TextSpan(text: ' của cột.'),
                              ],
                            ),
                            style: OmniType.micro.copyWith(
                              color: tones.faint,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: OmniSpacing.bottomSafe,
                        ),
                      ),
                    ],
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
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
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

    // Dòng đầu/cuối tự bo góc (K11): DecoratedSliver không cắt con, nên nền
    // vuông của dòng sẽ lòi ra khỏi góc bo của khung viền.
    const corner = Radius.circular(OmniRadius.sm);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? corner : Radius.zero,
          bottom: last ? corner : Radius.zero,
        ),
      ),
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
                _InstantDragStartListener(
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

/// Tay cầm nhấc ngay (K12): nhận kéo sau 2px thay vì touch slop 18px, nên bản
/// nổi đi theo ngón từ khung đầu thay vì đứng ở +0 rồi nhảy một phát. Chỉ tay
/// cầm dùng nó; vuốt ở chỗ khác của dòng vẫn cuộn danh sách như thường.
class _InstantDragStartListener extends ReorderableDragStartListener {
  const _InstantDragStartListener({required super.index, required super.child});

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      _InstantMultiDragRecognizer(debugOwner: this);
}

class _InstantMultiDragRecognizer extends MultiDragGestureRecognizer {
  _InstantMultiDragRecognizer({super.debugOwner});

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _InstantPointerState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'instant multidrag';
}

class _InstantPointerState extends MultiDragPointerState {
  _InstantPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );

  /// Nhận sau 2px thay vì touch slop 18px: bản nổi đi theo ngón ngay.
  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > 2) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

/// Font của app không có ký tự ⋮ và ⋯ (`font_glyph_coverage_test`), nên đoạn
/// chữ nhắc tới tay cầm và nút ⋯ dùng chính biểu tượng đó chen vào dòng.
InlineSpan _glyph(IconData icon, Color color) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Icon(icon, size: 16, color: color),
);
