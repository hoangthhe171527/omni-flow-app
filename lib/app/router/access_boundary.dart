import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens/tokens.dart';
import '../../security/guard/access_requirement.dart';
import '../../security/session/session_controller.dart';

/// Wraps every routed screen and renders "không có quyền" instead of the screen
/// when the session doesn't satisfy the route's requirement.
///
/// Applied by the router to *all* routes, so a screen cannot ship ungated by
/// forgetting to register it somewhere. Deep links, notification taps and
/// programmatic navigation all pass through here.
class AccessBoundary extends ConsumerWidget {
  const AccessBoundary({
    super.key,
    required this.requirement,
    required this.child,
  });

  final AccessRequirement requirement;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requirement.isOpen) return child;

    final policy = ref.watch(accessProvider);
    if (requirement.isSatisfiedBy(policy)) return child;

    return NoAccessView(requirement: requirement);
  }
}

/// Màn "không có quyền" theo `MNoAccess.dc.html`: ổ khoá trong vòng tròn,
/// tên quyền còn thiếu in đậm, và một nút quay lại khi còn chỗ để quay lại.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, required this.requirement});

  final AccessRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    // `any` đủ MỘT quyền là vào được, `all` phải đủ cả — câu phải nói đúng
    // điều đó, không thì quản trị viên cấp thừa quyền.
    final permissions = requirement.permissions.join(
      requirement.requireAll ? ' và ' : ' hoặc ',
    );
    // Chữ cấp 2 (#3A4760) ở chế độ sáng; chế độ tối không có bậc đó nên dùng
    // chữ phụ.
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? scheme.onSurfaceVariant
        : OmniColors.secondaryForeground;
    final body = OmniType.bodyStrong.copyWith(
      fontWeight: FontWeight.w400,
      height: 22 / 15,
      color: secondary,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.section,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  Text(
                    'Bạn không có quyền xem mục này',
                    textAlign: TextAlign.center,
                    style: OmniType.title.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Cần quyền '),
                        TextSpan(
                          text: permissions,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(
                          text: '. Liên hệ quản trị viên để được cấp quyền.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: body,
                  ),
                  if (canPop) ...[
                    const SizedBox(height: OmniSpacing.xxl),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Quay lại'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
