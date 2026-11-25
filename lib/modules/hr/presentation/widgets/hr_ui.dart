import 'package:flutter/material.dart';

import '../../../../core/nav/shell_bar_inset.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/clock_state.dart';

/// Mảnh giao diện dùng chung của Nhân sự (bản duyệt `nhan-su-app.html`):
/// thẻ trắng có con số lớn, viên trạng thái, thanh tiến độ, bộ chọn tháng,
/// dòng vị trí. Mọi thứ khác là `OmniGroupSection`/`OmniGroupRow`.

/// Đệm của danh sách trong màn Nhân sự (thanh trên + thanh tab kính).
EdgeInsets hrListPadding(
  BuildContext context,
  double top, {
  bool fab = false,
}) => EdgeInsets.fromLTRB(
  16,
  top + 8,
  16,
  fab
      ? OmniFabLayer.listBottom(context)
      : ShellBarInset.coveredBottom(context) + OmniSpacing.xxl,
);

/// Viên trạng thái nhỏ: `Chưa chấm`, `Đang trong ca`, `Chờ duyệt`, `Mới`.
class HrPill extends StatelessWidget {
  const HrPill(this.label, {super.key, this.tone = OmniTone.neutral});

  final String label;
  final OmniTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, bg) = tone.resolve(
      theme.colorScheme,
      dark: theme.brightness == Brightness.dark,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label,
          style: OmniType.caption.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Giá trị bên phải một dòng, không bao giờ cắt (tiền đủ số).
class HrValue extends StatelessWidget {
  const HrValue(this.text, {super.key, this.strong = false, this.tone});

  final String text;

  /// Chữ mực đậm (số chính của dòng).
  final bool strong;

  /// Sắc riêng: thành công (xanh lá) / nguy hiểm (đỏ) / cảnh báo.
  final OmniTone? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      OmniTone.success => OmniColors.successTextOf(context),
      OmniTone.danger => OmniColors.dangerTextOf(context),
      OmniTone.warning => OmniColors.warningTextOf(context),
      OmniTone.info => scheme.primary,
      _ => strong ? scheme.onSurface : scheme.onSurfaceVariant,
    };
    // Nửa bề ngang màn: giá trị dài (ngày + buổi) xuống dòng thay vì đẩy
    // tràn hàng; số tiền đủ số luôn vừa một dòng.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .5,
      ),
      child: Text(
        text,
        textAlign: TextAlign.right,
        softWrap: true,
        style: OmniType.body.copyWith(
          color: color,
          fontWeight: strong || tone != null
              ? FontWeight.w600
              : FontWeight.w400,
          fontFeatures: OmniType.tabular,
        ),
      ),
    );
  }
}

/// Dòng "nhãn — giá trị" cho số liệu; giá trị là [HrValue] (không cắt).
class HrStatRow extends StatelessWidget {
  const HrStatRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.strong = false,
    this.tone,
    this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final bool strong;
  final OmniTone? tone;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OmniGroupRow(
    title: title,
    subtitle: subtitle,
    icon: icon,
    onTap: onTap,
    trailing: HrValue(value, strong: strong, tone: tone),
    chevron: onTap != null,
  );
}

/// Khối đầu thẻ: nhãn nhỏ + viên trạng thái, con số lớn (đơn vị nhỏ nhạt),
/// dòng phụ, thanh tiến độ, vạch mốc.
class HrHero extends StatelessWidget {
  const HrHero({
    super.key,
    required this.label,
    required this.number,
    this.unit,
    this.pill,
    this.subtitle,
    this.progress,
    this.ticks = const [],
    this.bottom,
  });

  final String label;
  final String number;

  /// `đ`, `/ 26 công`, `/ 50 cây`.
  final String? unit;
  final Widget? pill;
  final String? subtitle;

  /// 0..1 — có thì vẽ thanh.
  final double? progress;
  final List<String> ticks;

  /// Nội dung thêm trong khối (nút chấm).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: OmniType.bodySm.copyWith(color: muted),
                ),
              ),
              ?pill,
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: number,
                  style: OmniType.moneyHero.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: OmniType.body.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: OmniType.bodySm.copyWith(color: muted)),
          if (progress != null) ...[
            const SizedBox(height: 10),
            HrProgressBar(value: progress!),
          ],
          if (ticks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in ticks)
                  Text(
                    t,
                    style: OmniType.micro.copyWith(
                      color: muted,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
              ],
            ),
          ],
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}

class HrProgressBar extends StatelessWidget {
  const HrProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        width: double.infinity,
        child: ColoredBox(
          color: OmniColors.trackOf(context),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1).toDouble(),
              heightFactor: 1,
              child: ColoredBox(color: scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// `‹  Tháng 11/2026  ›` — mũi tên tắt khi không đi tiếp được.
class HrMonthSwitcher extends StatelessWidget {
  const HrMonthSwitcher({
    super.key,
    required this.label,
    this.onPrev,
    this.onNext,
    this.onTapLabel,
  });

  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onTapLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => Opacity(
      opacity: onTap == null ? .4 : 1,
      child: OmniGlassCircle(
        child: IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: scheme.onSurface),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        arrow(Icons.chevron_left_rounded, 'Tháng trước', onPrev),
        const SizedBox(width: 10),
        Flexible(
          child: OmniGlass(
            radius: 999,
            blur: false,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (onTapLabel != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        arrow(Icons.chevron_right_rounded, 'Tháng sau', onNext),
      ],
    );
  }
}

IconData locationIconData(LocationIcon icon) => switch (icon) {
  LocationIcon.wifi => Icons.wifi_rounded,
  LocationIcon.gps => Icons.location_on_outlined,
  LocationIcon.gpsOff => Icons.location_off_outlined,
  LocationIcon.device => Icons.phonelink_lock_outlined,
  LocationIcon.offline => Icons.cloud_off_outlined,
  LocationIcon.lock => Icons.lock_outline_rounded,
  LocationIcon.unknown => Icons.my_location_rounded,
};

OmniTone locationTone(LocationTone tone) => switch (tone) {
  LocationTone.ok => OmniTone.success,
  LocationTone.warn => OmniTone.warning,
  LocationTone.bad => OmniTone.danger,
  LocationTone.neutral => OmniTone.neutral,
};

/// Dòng vị trí: `WiFi xưởng · Xưởng 50 Dân Chủ ........ Trong xưởng`.
class HrLocationRow extends StatelessWidget {
  const HrLocationRow({super.key, required this.line, this.onTap});

  final LocationLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = locationTone(line.tone);
    return OmniGroupRow(
      icon: locationIconData(line.icon),
      title: line.title,
      subtitle: line.subtitle,
      onTap: onTap,
      chevron: onTap != null,
      trailing: HrValue(
        line.value,
        tone: tone == OmniTone.neutral ? null : tone,
      ),
    );
  }
}

/// Nút chấm lớn (cao 52, rộng cả thẻ) hoặc gọn (trên thẻ Tổng quan).
class HrClockButton extends StatelessWidget {
  const HrClockButton({
    super.key,
    required this.action,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
  });

  final ClockAction action;
  final VoidCallback onPressed;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (action) {
      ClockAction.clockIn => (Icons.login_rounded, 'Chấm vào'),
      ClockAction.clockOut => (Icons.logout_rounded, 'Chấm ra'),
      ClockAction.done => (Icons.check_circle_rounded, 'Đã xong ca'),
      ClockAction.blocked => (Icons.block_rounded, 'Không chấm được'),
    };
    final off = action == ClockAction.done || action == ClockAction.blocked;
    final child = busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1)),
            ],
          );
    final size = Size(compact ? 0 : double.infinity, compact ? 46 : 52);
    final button = off
        ? OutlinedButton(
            key: const ValueKey('hr-clock-button'),
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(minimumSize: size),
            child: child,
          )
        : FilledButton(
            key: const ValueKey('hr-clock-button'),
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(minimumSize: size),
            child: child,
          );
    return Semantics(button: true, label: label, child: button);
  }
}

/// Toast nổi của Nhân sự (SnackBar theo theme).
void hrToast(BuildContext context, String message) {
  if (message.isEmpty) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Chữ ký tắt tên: `Vũ Văn Hoàng` → `H`.
String hrInitial(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final last = parts.isEmpty ? '' : parts.last;
  return last.isEmpty ? '?' : last.characters.first.toUpperCase();
}

/// Ô chữ cái tròn nhạt (không khối mực) cho dòng người.
class HrInitialTile extends StatelessWidget {
  const HrInitialTile(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: .10),
      ),
      child: Text(
        hrInitial(name),
        style: OmniType.caption.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
