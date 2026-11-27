import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/tokens.dart';
import 'omni_tinted_buttons.dart';
import 'omni_glass.dart';

/// Nhóm lồng liquid (viomni-apple-uiux.html `.group`, đợt 1–3 duyệt
/// 08/11/2026): nhãn nhóm chữ phụ ngoài thẻ, thẻ trắng bo 18 không viền, các
/// dòng ngăn bằng vạch mảnh THỤT sau ô icon. Nhóm rỗng không vẽ gì.
///
/// Khoảng cách giữa hai nhóm liền nhau do chỗ gọi đặt bằng
/// [OmniGroupSection.gap] (trang) hoặc [OmniGroupSection.sheetGap] (trong
/// sheet) — không bao giờ để hai thẻ dính nhau.
class OmniGroupSection extends StatelessWidget {
  const OmniGroupSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.trailingTitle,
    this.dividerIndent,
    this.background,
  });

  /// Khoảng cách giữa hai nhóm trên trang.
  static const double gap = 12;

  /// Khoảng cách giữa hai nhóm trong sheet.
  static const double sheetGap = 10;

  final List<Widget> children;
  final String? title;

  /// Chữ phụ nhỏ dưới thẻ — chỉ khi thật sự cần (không chữ giải thích dư).
  final String? footer;

  /// Thứ nằm bên phải nhãn nhóm (vd số đếm).
  final Widget? trailingTitle;

  /// Vạch ngăn thụt bao nhiêu từ mép trái. Mặc định 54 (sau ô icon 28);
  /// nhóm không icon truyền 14.
  final double? dividerIndent;

  /// Nền thẻ; mặc định surface.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final indent = dividerIndent ?? 54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || trailingTitle != null)
          OmniGroupHeader(title: title ?? '', trailing: trailingTitle),
        DecoratedBox(
          // `shadow-card` của Chuẩn Mobile UI (lớp premium): thẻ nổi nhẹ khỏi
          // nền, tối chỉ còn vòng sáng 0.5, tương phản cao không bóng.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: OmniShadows.groupOf(context),
          ),
          child: Material(
            color: background ?? scheme.surface,
            // Nhóm bo 16 (spec phong cách iOS §3.5). Tương phản cao: nền trang và
            // thẻ cùng trắng nên ranh giới là viền, thay cho bóng.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: MediaQuery.highContrastOf(context)
                  ? BorderSide(color: scheme.outlineVariant)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            // Thẻ trắng: nút bên trong là kính nhuộm tông, không chìm.
            child: OmniTintedButtons(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: indent,
                        color: scheme.outlineVariant.withValues(alpha: .7),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              footer!,
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Đầu nhóm (spec phong cách iOS §3.4): chữ HOA 13/600 xám, giãn chữ nhẹ,
/// thụt 16 cho thẳng chữ trong dòng; [trailing] (vd "Chọn") bên phải. Trình
/// đọc màn hình đọc [title] gốc (chữ thường), không đánh vần chữ hoa.
class OmniGroupHeader extends StatelessWidget {
  const OmniGroupHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: title,
              excludeSemantics: true,
              child: Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          if (trailing case final t?) ...[const SizedBox(width: 12), t],
        ],
      ),
    );
  }
}

/// Ô icon 28 bo 8 nền xám nhạt, icon một tông — đầu dòng của [OmniGroupRow].
class OmniIconTile extends StatelessWidget {
  const OmniIconTile(this.icon, {super.key, this.color, this.background});

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color ?? scheme.onSurface),
    );
  }
}

/// Một dòng trong [OmniGroupSection]: đầu dòng (ô icon / avatar / chấm màu),
/// nhãn, dòng phụ, giá trị, mũi tên hoặc dấu chọn ✓.
///
/// - [selected]: dòng đang chọn trong một danh sách chọn — dấu ✓ màu chính
///   ở cuối, chữ đậm. KHÔNG tô nền xanh (gu đã chốt: chọn = nhẹ, không khối).
/// - [destructive]: chữ và icon đỏ, không mũi tên.
/// - [accent]: dòng "+ Thêm …" — chữ và ô icon màu chính.
class OmniGroupRow extends StatelessWidget {
  const OmniGroupRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron,
    this.selected = false,
    this.destructive = false,
    this.accent = false,
    this.maxTitleLines = 2,
    this.semanticsLabel,
  });

  /// Dòng "+ Thêm …" chuẩn.
  const OmniGroupRow.add({
    super.key,
    required this.title,
    required this.onTap,
    this.icon = LucideIcons.plus,
    this.semanticsLabel,
  }) : subtitle = null,
       leading = null,
       value = null,
       trailing = null,
       chevron = false,
       selected = false,
       destructive = false,
       accent = true,
       maxTitleLines = 2;

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Đầu dòng tuỳ ý (avatar, chấm màu) thay cho [icon].
  final Widget? leading;

  /// Giá trị chữ phụ bên phải (không bao giờ cắt tiền: chỗ gọi truyền đủ số).
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Mặc định có mũi tên khi dòng bấm được và không phải dòng chọn / đỏ.
  final bool? chevron;
  final bool selected;
  final bool destructive;
  final bool accent;
  final int maxTitleLines;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniColors.dangerTextOf(context);
    final fg = destructive
        ? danger
        : accent
        ? scheme.primary
        : scheme.onSurface;
    final showChevron =
        chevron ??
        (onTap != null &&
            !selected &&
            !destructive &&
            !accent &&
            trailing == null);

    Widget? lead = leading;
    if (lead == null && icon != null) {
      lead = OmniIconTile(
        icon!,
        color: destructive
            ? danger
            : accent
            ? scheme.primary
            : null,
        background: accent ? scheme.primary.withValues(alpha: .10) : null,
      );
    }

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: maxTitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.body.copyWith(
                        fontWeight: selected || accent
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (subtitle case final sub? when sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          sub,
                          style: OmniType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (value case final v?) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.56),
                  child: Text(
                    v,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: OmniType.body.copyWith(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              if (trailing case final t?) ...[const SizedBox(width: 10), t],
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(LucideIcons.check, size: 20, color: scheme.primary),
              ],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: OmniTaskTones.of(context).chevron,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: semanticsLabel, child: row);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: row,
      ),
    );
  }
}

/// Đầu sheet liquid: [leading] (ô màu / avatar), tiêu đề 17 đậm, dòng phụ,
/// nút bên phải. Đệm 18 ngang, 12 dưới — dùng cho MỌI sheet để các sheet
/// cùng một dáng.
class OmniSheetHeader extends StatelessWidget {
  const OmniSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.close = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Không có [trailing] thì hiện nút ✕ (spec phong cách iOS §3.4) — chỉ khi
  /// đầu sheet nằm trong sheet thật (`showOmniSheet` → ModalBottomSheetRoute).
  /// Trong trang thì không (lỡ đóng cả màn), trong menu bật lên (popover) cũng
  /// không — popover đóng bằng chạm ra ngoài như iOS.
  final bool close;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing =
        this.trailing ??
        (close && ModalRoute.of(context) is ModalBottomSheetRoute
            ? const OmniSheetCloseButton()
            : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 14, 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Tiêu đề sheet 20/700 (spec phong cách iOS §3.4).
                    style: OmniType.body.copyWith(
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (subtitle case final sub? when sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.bodySm.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}

/// Nút ✕ đóng sheet (spec §3.4): tròn 32 nền xám, vùng chạm 44. Đặt ở
/// `trailing` của [OmniSheetHeader]; đóng bằng `Navigator.pop` không kết quả.
class OmniSheetCloseButton extends StatelessWidget {
  const OmniSheetCloseButton({super.key, this.onPressed});

  /// Mặc định `Navigator.maybePop(context)`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Đóng',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: 'Đóng',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.onSurface.withValues(alpha: dark ? .14 : .07),
                ),
                child: SizedBox.square(
                  dimension: 32,
                  child: Icon(
                    LucideIcons.x,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thân sheet liquid: các nhóm cách mép sheet 10, cách nhau
/// [OmniGroupSection.sheetGap], đáy 14. Cuộn khi dài.
class OmniSheetBody extends StatelessWidget {
  const OmniSheetBody({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.semanticsLabel,
  });

  final Widget? header;
  final List<Widget> children;

  /// Nút cuối sheet (nút kính) — nằm ngoài vùng cuộn.
  final Widget? footer;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // Đáy 22: viên kính bo 30 — chừa 14 thì hàng cuối (chip, nhóm)
            // nằm trong đường cong góc dưới, trông dính viền.
            padding: EdgeInsets.fromLTRB(10, 0, 10, footer == null ? 22 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: OmniGroupSection.sheetGap),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
            child: OmniTintedButtons.dock(context, footer!),
          ),
      ],
    );

    if (semanticsLabel == null) return body;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: body,
    );
  }
}

/// Chip chọn (spec phong cách iOS 25/11/2026 §3.4): ô bo 10 nền xám nhạt;
/// đang chọn = nền xanh nhạt + viền xanh 1.5 + chữ xanh đậm. Dùng cho lựa
/// chọn trong form và sheet thay ChoiceChip / FilterChip Material.
class OmniChoicePill extends StatelessWidget {
  const OmniChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = scheme.onSurface.withValues(alpha: dark ? .08 : .05);
    final shape = BorderRadius.circular(10);
    // Chữ trên nền xanh nhạt: dùng chính màu chính (đã đạt AA trên nền thẻ;
    // nền chỉ pha 10–16% nên tương phản gần như giữ nguyên).
    final selectedInk = scheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? OmniGlass.selectionOf(context) : base,
              borderRadius: shape,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? selectedInk : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: OmniType.chip.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? selectedInk : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
