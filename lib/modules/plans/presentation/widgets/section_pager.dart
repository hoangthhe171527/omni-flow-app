import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Dải nhóm việc CÓ TÊN: đang ở đâu, các nhóm khác tên gì và mỗi nhóm có bao
/// nhiêu việc — nhìn một lần, không cần vuốt qua từng trang để biết.
///
/// Bản đầu là một hàng chấm: chấm thứ ba không nói nó là "Chờ QC", và số việc
/// chỉ hiện cho nhóm đang mở. Mọi bảng công việc trên thị trường đều đặt tên
/// cột lên thanh chuyển; chấm là cho ảnh trong một album, nơi các trang không
/// có tên. Dải này chạm được, nên khoảng cách giữa hai công đoạn bất kỳ vẫn
/// là một cú chạm — và khi vuốt trang, tab đang mở tự cuộn vào giữa vùng nhìn.
///
/// Gạch chân 2px màu chính TRƯỢT giữa các tab (`Plan.dc.html`): tab rộng theo
/// chữ nên vị trí phải đo sau khung hình, không tính trước được.
class SectionTabs extends StatefulWidget {
  const SectionTabs({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
    this.countOf,
  });

  /// Chiều cao một tab — cũng là vùng chạm tối thiểu.
  static const double height = 44;

  final List<PlanSection> sections;
  final int current;
  final ValueChanged<int> onSelected;

  /// Số việc trong một nhóm, hiện cạnh tên MỌI nhóm.
  final int Function(int index)? countOf;

  @override
  State<SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<SectionTabs> {
  /// Một khoá cho mỗi tab, để đo chỗ đứng và cuộn tab đang mở vào vùng nhìn.
  ///
  /// Theo chỉ số chứ không theo id: hai nhóm có thể trùng tên, và một nhóm
  /// vừa bị xoá thì chỉ số vẫn trỏ đúng tab đang đứng ở vị trí đó.
  final _keys = <int, GlobalKey>{};
  final _rects = <int, Rect>{};
  final _stackKey = GlobalKey();

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _measure();
    _reveal();
  }

  @override
  void didUpdateWidget(SectionTabs old) {
    super.didUpdateWidget(old);
    _measure();
    if (old.current != widget.current) _reveal();
  }

  /// Đo vị trí từng tab sau khung hình để đặt gạch chân.
  void _measure() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.attached) return;

    final next = <int, Rect>{};
    for (var i = 0; i < widget.sections.length; i++) {
      final box = _keys[i]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      next[i] = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    }
    if (!mapEquals(next, _rects)) {
      setState(
        () => _rects
          ..clear()
          ..addAll(next),
      );
    }
  });

  /// Cuộn tab đang mở vào giữa dải sau khi khung hình này vẽ xong.
  ///
  /// Mọi tab đều được DỰNG (một `Row` trong `SingleChildScrollView`, không
  /// phải `ListView.builder`), nên tab ngoài vùng nhìn vẫn có context để
  /// cuộn tới. Số nhóm việc của một dự án đếm trên đầu ngón tay, dựng hết là
  /// rẻ hơn đoán độ rộng.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[widget.current]?.currentContext;
      if (target == null) return;

      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: OmniMotion.enabled(context)
            ? OmniMotion.of(context).base
            : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final rect = _rects[widget.current];
    final underline = DecoratedBox(
      key: const Key('section-underline'),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );

    return SizedBox(
      height: SectionTabs.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          key: _stackKey,
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.sections.length; i++)
                  SectionTabItem(
                    key: _keyFor(i),
                    label: widget.sections[i].name,
                    count: widget.countOf?.call(i),
                    selected: i == widget.current,
                    onTap: () => widget.onSelected(i),
                  ),
              ],
            ),
            if (rect != null)
              // Tắt hiệu ứng thì đặt thẳng, không qua bộ hoạt hoạ: một
              // `AnimatedPositioned` thời lượng 0 vẫn giữ ticker thêm một khung.
              if (motion)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: const Cubic(.2, .8, .2, 1),
                  left: rect.left + 12,
                  width: (rect.width - 24).clamp(0, double.infinity),
                  bottom: 0,
                  height: 2,
                  child: underline,
                )
              else
                Positioned(
                  left: rect.left + 12,
                  width: (rect.width - 24).clamp(0, double.infinity),
                  bottom: 0,
                  height: 2,
                  child: underline,
                ),
          ],
        ),
      ),
    );
  }
}

/// Một tab của [SectionTabs]: cao 44, tên + viên số.
class SectionTabItem extends StatelessWidget {
  const SectionTabItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;

  /// Null hoặc 0 thì không hiện viên số — "0" cạnh tên là tiếng ồn, và cột
  /// rỗng đã nói rõ là rỗng khi mở ra.
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = count;
    final hasCount = n != null && n > 0;

    // Nhãn trợ năng là TÊN, số việc là giá trị: "Chờ QC, 3 việc, nút, đã chọn".
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      value: n == null ? null : '$n việc',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SectionTabs.height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (hasCount) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.all(Radius.circular(9)),
                    ),
                    child: Text(
                      '$n',
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: OmniType.tabular,
                        color: selected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
