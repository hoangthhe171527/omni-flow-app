import 'package:flutter/material.dart';

import '../tokens/omni_task_tones.dart';

/// Chip nhỏ của màn Việc: hạn, "Trễ N", "Ưu tiên cao". Bo 4, đệm 2/6, chữ 12.
class OmniTaskChip extends StatelessWidget {
  const OmniTaskChip(this.label, {super.key, required this.pick});

  const OmniTaskChip.late(this.label, {super.key}) : pick = _late;
  const OmniTaskChip.today(this.label, {super.key}) : pick = _today;
  const OmniTaskChip.upcoming(this.label, {super.key}) : pick = _upcoming;
  const OmniTaskChip.none(this.label, {super.key}) : pick = _none;
  const OmniTaskChip.high(this.label, {super.key}) : pick = _high;

  final String label;

  /// Chọn cặp màu từ bảng đã theo chế độ sáng / tối.
  final OmniTaskTone Function(OmniTaskTones tones) pick;

  static OmniTaskTone _late(OmniTaskTones t) => t.late;
  static OmniTaskTone _today(OmniTaskTones t) => t.today;
  static OmniTaskTone _upcoming(OmniTaskTones t) => t.upcoming;
  static OmniTaskTone _none(OmniTaskTones t) => t.none;
  static OmniTaskTone _high(OmniTaskTones t) => t.highPriority;

  @override
  Widget build(BuildContext context) {
    final tone = pick(OmniTaskTones.of(context));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tone.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
