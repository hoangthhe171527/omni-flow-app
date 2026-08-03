import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../tokens/tokens.dart';

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

    if (value.isLoading && cached == null) {
      return loading ?? const OmniSkeletonList();
    }
    if (value.hasError && cached == null) {
      return OmniErrorView(error: value.error!, onRetry: onRetry);
    }
    if (cached == null) {
      return loading ?? const OmniSkeletonList();
    }
    if (isEmpty?.call(cached) == true) {
      return empty ?? const OmniEmptyState(title: 'Chưa có dữ liệu');
    }
    return data(cached);
  }
}

class OmniEmptyState extends StatelessWidget {
  const OmniEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: OmniSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: OmniType.section.copyWith(color: scheme.onSurface),
            ),
            if (message != null) ...[
              const SizedBox(height: OmniSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: OmniSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
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

    return OmniEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: retryable && onRetry != null ? 'Thử lại' : null,
      onAction: onRetry,
    );
  }

  (IconData, String, String, bool) _describe(Object error) {
    if (error is ForbiddenException) {
      final missing = error.requiredPermissions.isEmpty
          ? error.message
          : '${error.message}\nCần quyền: ${error.requiredPermissions.join(", ")}';
      return (Icons.lock_outline_rounded, 'Không có quyền', missing, false);
    }
    if (error is NotFoundException) {
      return (Icons.search_off_rounded, 'Không tìm thấy', error.message, false);
    }
    if (error is TimeoutException || error is NetworkException) {
      return (
        Icons.wifi_off_rounded,
        'Mất kết nối',
        (error as AppException).message,
        true,
      );
    }
    if (error is RequestBlockedException) {
      return (
        Icons.workspaces_outline,
        'Chưa chọn workspace',
        error.message,
        false,
      );
    }
    if (error is AppException) {
      return (Icons.error_outline_rounded, 'Đã có lỗi', error.message, true);
    }
    return (Icons.error_outline_rounded, 'Đã có lỗi', '$error', true);
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
  )..repeat(reverse: true);

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
