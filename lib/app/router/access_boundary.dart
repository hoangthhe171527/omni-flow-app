import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/components.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Không có quyền')),
      body: OmniEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Bạn không có quyền xem mục này',
        message: 'Cần quyền: ${requirement.permissions.join(", ")}.\n'
            'Liên hệ quản trị viên để được cấp quyền.',
        actionLabel: Navigator.of(context).canPop() ? 'Quay lại' : null,
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
