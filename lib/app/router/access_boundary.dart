import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/components.dart';
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

/// Màn "không có quyền" theo chuẩn Liquid Glass (`#s-no-access`): nền xám
/// chuẩn, thanh đầu `OmniAppBar`, thẻ nhóm trắng bo 18, ô khoá 64 bo 18 một
/// tông màu chính, tên quyền còn thiếu in đậm, và nút quay lại khi có đường lùi.
class NoAccessView extends StatelessWidget {
  const NoAccessView({
    super.key,
    required this.requirement,
    this.fallbackBack,
  });

  final AccessRequirement requirement;
  final VoidCallback? fallbackBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? Navigator.of(context).canPop();
    final effectiveBack = canPop
        ? () => Navigator.of(context).maybePop()
        : fallbackBack;
    // `any` đủ MỘT quyền là vào được, `all` phải đủ cả — câu phải nói đúng
    // điều đó, không thì quản trị viên cấp thừa quyền.
    final permissions = requirement.permissions.join(
      requirement.requireAll ? ' và ' : ' hoặc ',
    );
    final secondary = dark
        ? scheme.onSurfaceVariant
        : OmniColors.secondaryForeground;
    final body = OmniType.bodyStrong.copyWith(
      fontWeight: FontWeight.w400,
      height: 22 / 15,
      color: secondary,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: OmniAppBar(
        title: 'Quyền truy cập',
        showAccount: false,
        fallbackBack: fallbackBack,
      ),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final topInset = OmniTopBarOverlap.of(context);
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  OmniSpacing.xl,
                  topInset + OmniSpacing.lg,
                  OmniSpacing.xl,
                  MediaQuery.viewPaddingOf(context).bottom + OmniSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: OmniCard(
                    flat: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.xl,
                      vertical: OmniSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: dark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 28,
                            color: scheme.primary,
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
                        const SizedBox(height: OmniSpacing.md),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Cần quyền '),
                              TextSpan(
                                text: permissions,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    '. Liên hệ quản trị viên để được cấp quyền.',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: body,
                        ),
                        if (effectiveBack != null) ...[
                          const SizedBox(height: OmniSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: effectiveBack,
                              child: const Text('Quay lại'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
