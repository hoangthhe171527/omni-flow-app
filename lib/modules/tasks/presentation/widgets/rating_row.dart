import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/task.dart';
import 'task_detail/section_title.dart';
import 'task_detail/task_attachments.dart';

/// Lưới 2 cột của nửa dưới màn chi tiết (`TaskDetail.dc.html`): trái
/// "ĐIỂM KIỂM TRA", phải "TỆP ĐÍNH KÈM (n)", cách nhau 10.
///
/// Ảnh đứng cạnh điểm: người kiểm nhìn ảnh rồi mới chấm, còn người bị trả việc
/// về xem lại chính tấm mình đã gửi.
class ScoreAndFilesRow extends StatelessWidget {
  const ScoreAndFilesRow({
    super.key,
    required this.task,
    required this.taskId,
    required this.canRate,
  });

  final Task task;
  final String taskId;
  final bool canRate;

  /// Cạnh chạm 5 sao (5x44) + đệm + nhãn "n/5": ô điểm hẹp hơn mức này thì
  /// xếp điểm TRÊN tệp (mỗi ô một hàng) để đủ 5 sao không phải cuộn. Thu sao
  /// lại sẽ thu luôn vùng chạm dưới 44.
  static const _scoreCellMin = 280.0;

  @override
  Widget build(BuildContext context) {
    final files = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSectionTitle('TỆP ĐÍNH KÈM (${task.attachments.length})'),
        TaskAttachments(attachments: task.attachments),
      ],
    );
    final score = RatingRow(task: task, taskId: taskId, canRate: canRate);

    return LayoutBuilder(
      builder: (context, box) {
        if ((box.maxWidth - 10) / 2 < _scoreCellMin) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              score,
              if (canRate || task.rating > 0) const SizedBox(height: 14),
              files,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: score),
            const SizedBox(width: 10),
            Expanded(child: files),
          ],
        );
      },
    );
  }
}

/// Điểm QC, 0–5 sao (§4, §B3): tiêu đề "ĐIỂM KIỂM TRA" + thẻ 5 sao.
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
    // môi trường test thì lời gọi này không bao giờ hoàn tất.
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

    final tones = OmniTaskTones.of(context);
    final motion = OmniMotion.enabled(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DetailSectionTitle('ĐIỂM KIỂM TRA'),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          // Màn hẹp xếp điểm cả hàng (ScoreAndFilesRow) nên 5 ô 44 = 220 vừa;
          // phòng khi vẫn thiếu chỗ thì hàng sao CUỘN ngang chứ không thu
          // (thu sao là thu luôn vùng chạm dưới 44). Nhãn "n/5" đứng NGOÀI
          // vùng cuộn để không bao giờ trôi khỏi màn.
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        _Star(
                          star: star,
                          rating: rating,
                          // Sao đã chọn: cam #E8890C; chưa chọn: xám nhạt.
                          selectedColor: tones.priorityNormal,
                          idleColor: OmniColors.mutedBarOf(context),
                          motion: motion,
                          onTap: widget.canRate && !_busy
                              ? () => _rate(star)
                              : null,
                          interactive: widget.canRate,
                        ),
                    ],
                  ),
                ),
              ),
              if (rating > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 12),
                  child: Text('$rating/5', style: OmniType.bodyStrong),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Một ngôi sao vẽ 30, vùng chạm 44×44.
class _Star extends StatelessWidget {
  const _Star({
    required this.star,
    required this.rating,
    required this.selectedColor,
    required this.idleColor,
    required this.motion,
    required this.onTap,
    required this.interactive,
  });

  final int star;
  final int rating;
  final Color selectedColor;
  final Color idleColor;
  final bool motion;
  final VoidCallback? onTap;

  /// Người chấm được (khác với đang bận): chỉ ảnh hưởng nhãn "nút" cho trình
  /// đọc màn hình.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final on = star <= rating;

    return Semantics(
      label: '$star điểm',
      button: interactive,
      selected: on,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedScale(
              scale: star == rating ? 1.2 : 1,
              duration: motion
                  ? const Duration(milliseconds: 200)
                  : Duration.zero,
              child: Icon(
                on ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 30,
                color: on ? selectedColor : idleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
