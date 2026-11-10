import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';

/// Mẩu giao diện dùng chung của Kho: thông báo ngắn, câu lỗi, tiền, dòng phụ.
abstract final class InvUi {
  static void toast(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String error(Object e) =>
      e is AppException && e.message.trim().isNotEmpty
      ? e.message
      : 'Không lưu được. Thử lại sau.';

  /// Tiền đồng luôn đủ số (`12.500.000đ`).
  static String vnd(num? n) => Formatters.vnd(n?.round());

  /// Màu chữ tình trạng: lỗi vàng cảnh báo, không thấy đỏ.
  static Color? conditionColor(BuildContext context, UnitCondition? c) =>
      switch (c) {
        UnitCondition.defective => OmniColors.warningTextOf(context),
        UnitCondition.missing => OmniColors.dangerTextOf(context),
        _ => null,
      };

  /// Rút gọn tên loại dài cho dòng phụ (`Piano Upright cũ` → `Upright`).
  static String shortCategory(String? c) => switch (c) {
    null => '',
    'Piano Upright cũ' => 'Upright',
    'Piano điện cũ' => 'Piano điện',
    'Piano Grand cũ' => 'Grand',
    _ => c,
  };

  /// `Ep 61 · Upright · 84 ngày`.
  static String stockSubtitle(InventoryUnit u, DateTime today) {
    final d = InventoryFormat.ageDays(u.receivedAt, today);
    return [
      if (u.lotCode != null) u.lotCode!,
      if (shortCategory(u.category).isNotEmpty) shortCategory(u.category),
      d == null ? 'chưa có ngày' : '$d ngày',
    ].join(' · ');
  }

  /// `Nhạc cụ Hoàng Long · 12.000.000đ` / `Để bán lẻ`.
  static String? holdLine(InventoryUnit u) {
    if (u.retailHold) return 'Để bán lẻ';
    if (u.customerName == null && u.customerId == null) return null;
    final name = u.customerName ?? 'Khách';
    if (u.sale == UnitSale.sold) return '$name · đã vào đơn';
    final p = u.reservedPrice;
    return p == null ? name : '$name · ${vnd(p)}';
  }
}

/// Chữ phụ màu chuẩn của dòng.
TextStyle invMuted(BuildContext context) => OmniType.caption.copyWith(
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Giá trị bên phải của dòng: số tiền (không bao giờ cắt) + dòng nhỏ dưới.
class InvValue extends StatelessWidget {
  const InvValue(this.value, {super.key, this.sub, this.subColor});

  final String value;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: OmniType.bodyStrong.copyWith(
            color: scheme.onSurface,
            fontFeatures: OmniType.tabular,
          ),
        ),
        if (sub != null && sub!.isNotEmpty)
          Text(
            sub!,
            style: OmniType.caption.copyWith(
              color: subColor ?? scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Một việc xưởng của cây trong nhóm "Xưởng": "Tân trang" / "Bảo hành", dòng
/// phụ công đoạn đang làm + người làm, vạch tiến độ, bên phải `8/10` / "Xong".
class InvWorkRow extends StatelessWidget {
  const InvWorkRow({super.key, required this.work, this.onTap});

  final UnitWork work;

  /// null = không mở được việc (thiếu quyền xem việc): không có mũi tên.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = work;
    final sub = w.subtitle;
    final value = w.progressLabel;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.roleLabel,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(sub, style: invMuted(context)),
                    ),
                  if (w.total > 0 || w.isDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: OmniProgressBar(value: w.progress),
                    ),
                ],
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                value,
                style: OmniType.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: OmniTaskTones.of(context).chevron,
              ),
            ],
          ],
        ),
      ),
    );
    final label = [
      w.roleLabel,
      if (sub.isNotEmpty) sub,
      if (value.isNotEmpty) value,
    ].join(', ');
    if (onTap == null) {
      return Semantics(label: label, excludeSemantics: true, child: row);
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
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

/// Dòng chữ mờ trong nhóm ("Chưa vào xưởng") — không bấm được.
class InvMutedRow extends StatelessWidget {
  const InvMutedRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: OmniType.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

/// Nút thả xuống của hàng lọc: kính trắng mờ khi đang lọc, mũi tên ▾.
class InvDropPill extends StatelessWidget {
  const InvDropPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: active
                ? OmniGlass.buttonDecoration(
                    context,
                  ).copyWith(color: OmniGlass.selectionOf(context))
                : BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: dark ? .08 : .05),
                    borderRadius: BorderRadius.circular(999),
                  ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: OmniType.chip.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bộ đếm −  n  + (số lượng cây).
class InvStepper extends StatelessWidget {
  const InvStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, String tip, int next, bool enabled) => IconButton(
      tooltip: tip,
      onPressed: enabled ? () => onChanged(next) : null,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, 'Bớt', value - 1, value > min),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 32),
          child: Text(
            suffix == null ? '$value' : '$value$suffix',
            textAlign: TextAlign.center,
            style: OmniType.bodyStrong.copyWith(
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
        btn(Icons.add_rounded, 'Thêm', value + 1, value < max),
      ],
    );
  }
}

/// Kết quả chọn của [showInvOptions]: `value == null` là "Tất cả".
typedef InvPicked<T> = ({T? value});

/// Sheet chọn một trong danh sách (thay DropdownButton). [allLabel] khác null
/// thì có dòng "Tất cả" đầu danh sách.
Future<InvPicked<T>?> showInvOptions<T>({
  required BuildContext context,
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? allLabel,
}) {
  return showOmniSheet<InvPicked<T>>(
    context: context,
    builder: (sheet) => OmniSheetBody(
      header: OmniSheetHeader(title: title),
      children: [
        OmniGroupSection(
          children: [
            if (allLabel != null)
              OmniGroupRow(
                title: allLabel,
                selected: selected == null,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop((value: null)),
              ),
            for (final (v, label) in options)
              OmniGroupRow(
                title: label,
                selected: v == selected,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop((value: v)),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Ô nhập một dòng trong nhóm: nhãn nhỏ trên, chữ nhập dưới, không viền.
class InvInputRow extends StatelessWidget {
  const InvInputRow({
    super.key,
    required this.label,
    required this.controller,
    required this.fieldKey,
    this.hint,
    this.phone = false,
    this.caps = false,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final String? hint;
  final bool phone;

  /// Viết hoa toàn bộ (hãng, serial).
  final bool caps;

  /// Bàn phím riêng (vd. số thập phân cho tỷ lệ) — mặc định theo [phone].
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: invMuted(context)),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType:
                keyboardType ??
                (phone ? TextInputType.phone : TextInputType.name),
            autocorrect: !caps,
            textCapitalization: phone
                ? TextCapitalization.none
                : caps
                ? TextCapitalization.characters
                : TextCapitalization.words,
            style: OmniType.body.copyWith(color: scheme.onSurface),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Khung chờ trong một danh sách đã cuộn (OmniSkeletonList là ListView — lồng
/// vào ListView khác sẽ vỡ chiều cao).
class InvSkeleton extends StatelessWidget {
  const InvSkeleton({super.key, this.count = 5, this.height = 56});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        OmniSkeletonBox(height: height),
      ],
    ],
  );
}
