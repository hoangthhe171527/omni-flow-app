import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_glass.dart';

/// Every async screen renders through here, so loading, empty, error and
/// permission-denied always look and behave the same across modules.
///
/// Keeps showing the previous data while a refresh is in flight — a pull to
/// refresh must never blank the list the user is reading.
class OmniAsyncView<T> extends StatelessWidget {
  const OmniAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final cached = value.valueOrNull;
    // Thân chạy dưới thanh trên kính: trạng thái tải / trống / lỗi không được
    // nằm khuất sau thanh. Danh sách (`data`) tự cộng đệm để cuộn dưới kính.
    final inset = OmniTopBarOverlap.of(context);
    Widget clear(Widget child) => inset == 0
        ? child
        : Padding(
            padding: EdgeInsets.only(top: inset),
            child: child,
          );

    if (value.isLoading && cached == null) {
      return clear(loading ?? const OmniSkeletonList());
    }
    if (value.hasError && cached == null) {
      return clear(OmniErrorView(error: value.error!, onRetry: onRetry));
    }
    if (cached == null) {
      return clear(loading ?? const OmniSkeletonList());
    }
    if (isEmpty?.call(cached) == true) {
      return clear(empty ?? const OmniEmptyState(title: 'Chưa có dữ liệu'));
    }
    return data(cached);
  }
}

/// Tông của [OmniEmptyState]: [accent] cho trống thật (mời tạo cái đầu tiên),
/// [neutral] cho lỗi / không quyền (không mời gọi, chỉ báo).
enum OmniEmptyTone { accent, neutral }

/// Trạng thái trống (Chuẩn Mobile UI — EmptyState), ba kiểu:
///
/// - **Trống thật** (mặc định): ô icon 64 bo 16 nền nhấn nhạt + một câu
///   17/600 + (mô tả ≤ 2 dòng) + MỘT nút động từ ("Thêm khoản chi").
/// - **Trống trong khối** ([compact]): cùng hình, đệm nhỏ — đặt đúng chỗ nội
///   dung sẽ hiện (trong thẻ, dưới biểu đồ), không chiếm cả màn.
/// - **Trống do lọc / tìm** ([OmniEmptyState.filtered]): một câu + nút chữ
///   "Bỏ lọc", không icon lớn — người dùng không cần được an ủi.
///
/// Không: đoạn giải thích tính năng, hình minh hoạ lớn, một dòng chữ trơn.
class OmniEmptyState extends StatelessWidget {
  const OmniEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.tone = OmniEmptyTone.accent,
    this.compact = false,
  }) : _filtered = false;

  /// Trống vì bộ lọc / từ khoá: một câu + nút chữ [actionLabel] (mặc định
  /// "Bỏ lọc") gọi [onAction].
  const OmniEmptyState.filtered({
    super.key,
    required this.title,
    this.actionLabel = 'Bỏ lọc',
    this.onAction,
  }) : message = null,
       icon = LucideIcons.searchX,
       tone = OmniEmptyTone.neutral,
       compact = true,
       _filtered = true;

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final OmniEmptyTone tone;
  final bool compact;
  final bool _filtered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_filtered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.lg,
            vertical: OmniSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: OmniSpacing.xs),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
    }

    final accent = tone == OmniEmptyTone.accent;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? OmniSpacing.xl : OmniSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: OmniRadius.xlAll,
              ),
              child: Icon(
                icon,
                size: 28,
                color: accent
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            Semantics(
              header: !compact,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: OmniType.section.copyWith(
                  fontSize: 17,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: OmniSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null) ...[
              SizedBox(height: compact ? OmniSpacing.md : OmniSpacing.xl),
              accent
                  ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
                  : OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error surface that reads the app's own exception types — a 403 explains what
/// permission is missing instead of showing a stack trace.
class OmniErrorView extends StatelessWidget {
  const OmniErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message, retryable) = _describe(error);

    // Lỗi / không quyền: tông trung tính (không mời gọi), "Thử lại" là nút
    // phụ — Chuẩn Mobile UI: câu nói chuyện gì + cách sửa + Thử lại.
    return OmniEmptyState(
      icon: icon,
      title: title,
      message: message,
      tone: OmniEmptyTone.neutral,
      actionLabel: retryable && onRetry != null ? 'Thử lại' : null,
      onAction: onRetry,
    );
  }

  (IconData, String, String, bool) _describe(Object error) {
    if (error is ForbiddenException) {
      final missing = error.requiredPermissions.isEmpty
          ? error.message
          : '${error.message}\nCần quyền: ${error.requiredPermissions.join(", ")}';
      return (LucideIcons.lock, 'Không có quyền', missing, false);
    }
    if (error is NotFoundException) {
      return (LucideIcons.searchX, 'Không tìm thấy', error.message, false);
    }
    if (error is TimeoutException || error is NetworkException) {
      return (
        LucideIcons.wifiOff,
        'Mất kết nối',
        (error as AppException).message,
        true,
      );
    }
    if (error is RequestBlockedException) {
      return (LucideIcons.boxes, 'Chưa chọn workspace', error.message, false);
    }
    if (error is AppException) {
      return (LucideIcons.circleAlert, 'Đã có lỗi', error.message, true);
    }
    return (LucideIcons.circleAlert, 'Đã có lỗi', humanError(error), true);
  }
}

/// Skeleton placeholder rows. Shape-matched to the real list so the transition
/// doesn't jump.
class OmniSkeletonList extends StatelessWidget {
  const OmniSkeletonList({super.key, this.count = 6, this.height = 84});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(OmniSpacing.lg),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.md),
      itemBuilder: (_, _) => OmniSkeletonBox(height: height),
    );
  }
}

class OmniSkeletonBox extends StatefulWidget {
  const OmniSkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = OmniRadius.md,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<OmniSkeletonBox> createState() => _OmniSkeletonBoxState();
}

class _OmniSkeletonBoxState extends State<OmniSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nhấp nháy là chuyển động: một mảng sáng tối đều đặn khắp màn hình,
    // đúng thứ cài đặt "giảm chuyển động" nhắm tới. Tắt thì đứng yên ở một
    // sắc cố định — vẫn là khung xương, chỉ không thở.
    if (OmniMotion.enabled(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.55 + _controller.value * 0.35),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
