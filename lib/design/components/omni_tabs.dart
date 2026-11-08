import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_glass.dart';
import 'omni_status_chip.dart';

/// Một tab trong [OmniTabStrip].
class OmniTab {
  const OmniTab({
    required this.label,
    this.count,
    this.alert = false,
    this.semanticValue,
    this.key,
  });

  final String label;

  /// Số đếm cạnh tên. Null hoặc 0 thì không hiện — đoán số là tệ hơn không
  /// có số.
  final int? count;

  /// Số đếm là chuyện CẦN XỬ LÝ ("Quá hạn 3"): hiện thành chip đỏ thay vì chữ
  /// xám, để màu đỏ chỉ xuất hiện khi có cái gì đó thật sự trễ.
  final bool alert;

  /// Giá trị đọc cho trợ năng thay cho con số trần ("3 việc").
  final String? semanticValue;

  /// Khoá của ô tab — để cuộn tab đang chọn vào vùng nhìn.
  final Key? key;
}

/// MỘT kiểu tab cho cả app, kiểu kính (viomni-apple-uiux.html "Việc của
/// tôi": "Tab thành bộ chọn đoạn kính"): viên kính dạng viên thuốc, các tab
/// chia đều, thấu kính trắng mờ trượt tới tab đang chọn; chữ tab chọn màu chủ
/// đạo 600, tab khác chữ phụ 500; số đếm xám, số "cần xử lý" là chip đỏ.
///
/// Chia đều nhưng không cắt chữ: chữ dài thì thu nhỏ vừa ô (FittedBox) thay
/// vì thành "Hôm …".
class OmniTabStrip extends StatelessWidget {
  const OmniTabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<OmniTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Lề ngoài của viên kính.
  final EdgeInsets padding;

  /// Cao của viên kính.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    if (n == 0) return const SizedBox.shrink();
    final sel = selected.clamp(0, n - 1);
    final motion = OmniMotion.enabled(context);

    return Padding(
      padding: padding,
      child: OmniGlass(
        radius: height / 2,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              const inset = 4.0;
              final w = (box.maxWidth - inset * 2) / n;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: motion
                        ? const Duration(milliseconds: 420)
                        : Duration.zero,
                    curve: const Cubic(0.34, 1.36, 0.64, 1),
                    left: inset + w * sel,
                    top: 4,
                    bottom: 4,
                    width: w,
                    child: const OmniGlassLens(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: inset),
                    child: Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: OmniTabItem(
                              key: tabs[i].key,
                              tab: tabs[i],
                              selected: i == sel,
                              onTap: () {
                                if (i != sel) {
                                  HapticFeedback.selectionClick();
                                }
                                onSelected(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Một ô tab của [OmniTabStrip]. Công khai để bài kiểm tìm được ô của MỘT
/// tab (kể cả số đếm bên trong nó); màn hình dựng tab qua [OmniTabStrip].
class OmniTabItem extends StatelessWidget {
  const OmniTabItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final OmniTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = tab.count;
    final hasCount = count != null && count > 0;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      value: tab.semanticValue ?? (hasCount ? '$count' : null),
      excludeSemantics: true,
      // Không gợn sóng: kính đổi chọn bằng thấu kính trượt.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    maxLines: 1,
                    style: OmniType.body.copyWith(
                      fontSize: 14,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (hasCount) ...[
                    const SizedBox(width: 5),
                    if (tab.alert)
                      OmniBadge(label: '$count', tone: OmniTone.danger)
                    else
                      Text(
                        '$count',
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontFeatures: OmniType.tabular,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh tiến độ của app: cao 4, màu chính trên rãnh xám, đầu bo 2.
///
/// Một widget chứ không phải mỗi chỗ tự dựng `LinearProgressIndicator`: chỗ
/// tự dựng là chỗ từng ghim màu quỹ đạo sáng (#14D3C8) và cao 6 — màu đó chỉ
/// dành cho logo và đồ hoạ.
class OmniProgressBar extends StatelessWidget {
  const OmniProgressBar({super.key, required this.value});

  /// 0..1. Null là đang chạy không biết bao lâu.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: scheme.outlineVariant,
        valueColor: AlwaysStoppedAnimation(scheme.primary),
      ),
    );
  }
}
