import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_status_chip.dart';

/// Một tab trong [OmniTabStrip].
class OmniTab {
  const OmniTab({
    required this.label,
    this.count,
    this.alert = false,
    this.key,
  });

  final String label;

  /// Số đếm cạnh tên. Null hoặc 0 thì không hiện — đoán số là tệ hơn không
  /// có số.
  final int? count;

  /// Số đếm là chuyện CẦN XỬ LÝ ("Quá hạn 3"): hiện thành chip đỏ thay vì chữ
  /// xám, để màu đỏ chỉ xuất hiện khi có cái gì đó thật sự trễ.
  final bool alert;

  /// Khoá của ô tab — để cuộn tab đang chọn vào vùng nhìn.
  final Key? key;
}

/// MỘT kiểu tab cho cả app: gạch chân 2px màu chính, chữ mực 600; tab chưa
/// chọn chữ phụ 500; số đếm xám (`SPrinciples.dc.html` §8).
///
/// Thay cho hai kiểu tab phân đoạn cũ — rãnh xám có ô trắng nổi bóng ("Việc
/// của tôi") và dải viên trên nền mực (bảng dự án). Ba kiểu tab trên một app
/// là ba thứ phải học; một kiểu là một.
class OmniTabStrip extends StatelessWidget {
  const OmniTabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.gap = 20,
  });

  final List<OmniTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Cuộn ngang khi số tab không biết trước (nhóm việc của một dự án). Không
  /// cuộn thì các tab đứng sát trái theo đúng thứ tự.
  final bool scrollable;

  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          if (scrollable)
            _TabItem(
              key: tabs[i].key,
              tab: tabs[i],
              selected: i == selected,
              onTap: () => onSelected(i),
            )
          else
            Flexible(
              child: _TabItem(
                key: tabs[i].key,
                tab: tabs[i],
                selected: i == selected,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 44,
        child: scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: padding,
                child: row,
              )
            : Padding(padding: padding, child: row),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
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
      value: hasCount ? '$count' : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OmniMotion.of(context).fast,
          padding: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (hasCount) ...[
                const SizedBox(width: 6),
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
