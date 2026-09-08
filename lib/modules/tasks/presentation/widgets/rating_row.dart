import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/task.dart';

/// Điểm QC, 0–5 sao (§4, §B3).
///
/// §B3: QC đạt thì "up ảnh sau, chấm sao, kéo sang Hoàn thiện (đạt)". Web đã
/// chấm được từ lâu; app thì chưa — mà QC đứng ở xưởng với cây đàn trước mặt,
/// không ngồi trước máy tính.
///
/// Chỉ NGƯỜI KIỂM chấm được. Người làm vẫn thấy điểm của mình nhưng không đổi
/// được: ai cũng tự chấm được thì con số thôi là một đánh giá. Người làm thấy
/// điểm là cố ý — §7 cấm bảng xếp hạng cá nhân trong xưởng, không cấm một
/// người biết việc của chính mình được kiểm ra sao.
class RatingRow extends ConsumerStatefulWidget {
  const RatingRow({
    super.key,
    required this.task,
    required this.taskId,
    required this.canRate,
  });

  final Task task;
  final String taskId;

  /// Người kiểm, không phải người làm.
  final bool canRate;

  @override
  ConsumerState<RatingRow> createState() => _RatingRowState();
}

class _RatingRowState extends ConsumerState<RatingRow> {
  bool _busy = false;

  Future<void> _rate(int star) async {
    final messenger = ScaffoldMessenger.of(context);
    // Chạm lại đúng ngôi sao đang chọn là XOÁ điểm. Chấm nhầm thì phải gỡ
    // được, và không có nút nào khác để làm việc đó.
    final next = widget.task.rating == star ? 0 : star;

    // KHÔNG await: rung là phản hồi, không phải một bước của thao tác. Chờ nó
    // là để người dùng đợi một cái rung trước khi việc thật bắt đầu — và trong
    // môi trường test thì lời gọi này không bao giờ hoàn tất, nên chờ nó cũng
    // là tự bịt mắt mình.
    unawaited(HapticFeedback.selectionClick());
    setState(() => _busy = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          .setRating(next);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa lưu được. Thử lại khi có mạng.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rating = widget.task.rating;

    // Chưa chấm và cũng không được chấm: không có gì để nói.
    if (!widget.canRate && rating == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Điểm kiểm tra',
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  // Vùng chạm mặc định của IconButton là 48dp — đúng thứ cần
                  // khi người bấm đang đứng cạnh cây đàn.
                  onPressed: widget.canRate && !_busy
                      ? () => _rate(star)
                      : null,
                  tooltip: widget.canRate ? '$star sao' : null,
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= rating
                        ? OmniColors.warning
                        : scheme.onSurfaceVariant,
                  ),
                ),
              if (rating > 0) ...[
                const SizedBox(width: OmniSpacing.sm),
                Text('$rating/5', style: OmniType.bodyStrong),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
