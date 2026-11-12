import 'package:flutter/material.dart';

import '../../core/nav/shell_bar_inset.dart';
import '../tokens/tokens.dart';
import 'omni_glass.dart';
import 'omni_liquid_fab.dart';

/// Thân màn + nút + kính nổi ở góc phải dưới (rà soát 12/11/2026, artifact
/// `ra-soat-app-mobile`). Nút luôn nằm TRÊN thanh tab kính và vùng an toàn —
/// không dùng `Scaffold.floatingActionButton` trong màn của shell: Scaffold
/// lồng không biết thanh kính của shell nên nút bị đè.
///
/// Danh sách trong [body] chừa đáy bằng [OmniFabLayer.listBottom].
class OmniFabLayer extends StatelessWidget {
  const OmniFabLayer({super.key, required this.body, this.fab});

  final Widget body;

  /// Thường là [OmniLiquidFab]. null = không có nút (thiếu quyền).
  final Widget? fab;

  /// Khe giữa nút và thanh tab: 16 thì bóng nút chạm bóng thanh (đã thử ở
  /// /teams), nên 20.
  static const double gap = 20;

  /// Đệm đáy cho danh sách dưới nút: dòng cuối cuộn lên khỏi nút.
  static double listBottom(BuildContext context, {bool hasFab = true}) =>
      ShellBarInset.coveredBottom(context) +
      (hasFab ? gap + OmniLiquidFab.size + 12 : OmniSpacing.xxl);

  @override
  Widget build(BuildContext context) {
    final fab = this.fab;
    if (fab == null) return body;
    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          right: 20,
          bottom: ShellBarInset.floatingBottom(context, gap: gap),
          child: fab,
        ),
      ],
    );
  }
}

/// Thân màn + khay kính đáy chứa nút chính (Nhận hàng, Ghi đã trả, Bán…).
///
/// Khay là một viên kính mờ cách mép 16, bên trái có dòng tóm tắt
/// ([title]/[subtitle]) để người dùng biết nút sẽ làm gì; phía trên khay nội
/// dung mờ dần. Thay cho `FilledButton` nổi tự do trên danh sách.
class OmniDockLayer extends StatelessWidget {
  const OmniDockLayer({super.key, required this.body, this.dock});

  final Widget body;
  final OmniBottomDock? dock;

  /// Đệm đáy cho danh sách dưới khay ([rows] dòng nút xếp chồng).
  static double listBottom(BuildContext context, {int rows = 1}) =>
      ShellBarInset.coveredBottom(context) + 12 + 70.0 * rows + 16;

  @override
  Widget build(BuildContext context) {
    final dock = this.dock;
    if (dock == null) return body;
    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: listBottom(context) - 24,
              child: const OmniScrollEdge(atTop: false),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: ShellBarInset.floatingBottom(context, gap: 10),
          child: dock,
        ),
      ],
    );
  }
}

class OmniBottomDock extends StatelessWidget {
  const OmniBottomDock({
    super.key,
    required this.action,
    this.title,
    this.subtitle,
    this.extra = const [],
  });

  /// Nút chính (FilledButton của theme — đã là nút kính).
  final Widget action;
  final String? title;
  final String? subtitle;

  /// Nút phụ xếp trên hàng chính (vd "Đưa vào xưởng" khi đang chọn nhiều).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = this.title;
    final subtitle = this.subtitle;
    final hasText = title != null || subtitle != null;
    final main = LayoutBuilder(
      builder: (context, box) {
        final maxAction = box.maxWidth * 0.6;
        return Row(
          children: [
            if (hasText) ...[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        maxLines: 2,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 2,
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Nút không chiếm quá 60% khay: chữ dài ("Bán / Đặt trước · 12 cây")
              // co lại thay vì đẩy tràn dòng tóm tắt.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxAction),
                child: action,
              ),
            ] else
              Expanded(child: action),
          ],
        );
      },
    );
    return OmniGlass(
      radius: 26,
      padding: EdgeInsets.fromLTRB(hasText ? 16 : 10, 10, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in extra) ...[e, const SizedBox(height: 8)],
          main,
        ],
      ),
    );
  }
}
