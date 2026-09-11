import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
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
/// là một cú chạm — và khi vuốt trang, viên đang mở tự cuộn vào vùng nhìn.
class SectionIndicator extends StatefulWidget {
  const SectionIndicator({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
    this.countOf,
  });

  final List<PlanSection> sections;
  final int current;
  final ValueChanged<int> onSelected;

  /// Số việc trong một nhóm, hiện cạnh tên MỌI nhóm.
  final int Function(int index)? countOf;

  @override
  State<SectionIndicator> createState() => _SectionIndicatorState();
}

class _SectionIndicatorState extends State<SectionIndicator> {
  /// Một khoá cho mỗi viên, để cuộn viên đang mở vào vùng nhìn.
  ///
  /// Theo chỉ số chứ không theo id: hai nhóm có thể trùng tên, và một nhóm
  /// vừa bị xoá thì chỉ số vẫn trỏ đúng viên đang đứng ở vị trí đó.
  final _keys = <int, GlobalKey>{};

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  @override
  void didUpdateWidget(SectionIndicator old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _reveal();
  }

  /// Cuộn viên đang mở vào giữa dải sau khi khung hình này vẽ xong.
  ///
  /// Mọi viên đều được DỰNG (một `Row` trong `SingleChildScrollView`, không
  /// phải `ListView.builder`), nên viên ngoài vùng nhìn vẫn có context để
  /// cuộn tới. Số nhóm việc của một dự án đếm trên đầu ngón tay, dựng hết là
  /// rẻ hơn đoán độ rộng.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[widget.current]?.currentContext;
      if (!mounted || target == null) return;

      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: OmniMotion.of(context).base,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.lg,
        vertical: OmniSpacing.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.sections.length; i++) ...[
            if (i > 0) const SizedBox(width: OmniSpacing.xs),
            // Nhãn trợ năng là TÊN, số việc là giá trị: "Chờ QC, 3 việc, nút,
            // đã chọn". Hai `Text` rời trong viên sẽ đọc thành hai nút.
            Semantics(
              key: _keyFor(i),
              button: true,
              selected: i == widget.current,
              label: widget.sections[i].name,
              value: switch (widget.countOf?.call(i)) {
                null => null,
                final n => '$n việc',
              },
              excludeSemantics: true,
              child: OmniFilterPill(
                label: widget.sections[i].name,
                selected: i == widget.current,
                count: widget.countOf?.call(i),
                onTap: () => widget.onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
