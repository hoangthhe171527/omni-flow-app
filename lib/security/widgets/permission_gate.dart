import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permissions/access_policy.dart';
import '../session/session_controller.dart';

/// Renders [child] only when the session holds the required permission.
///
/// For a single button, prefer reading [accessProvider] directly — this widget
/// earns its keep when a whole block (a card, an action row, a tab) appears or
/// disappears together.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permissions,
    required this.child,
    this.requireAll = false,
    this.fallback,
  });

  /// Convenience for the common single-slug case.
  PermissionGate.one(
    String permission, {
    Key? key,
    required Widget child,
    Widget? fallback,
  }) : this(
          key: key,
          permissions: [permission],
          child: child,
          fallback: fallback,
        );

  final List<String> permissions;
  final bool requireAll;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(accessProvider);
    final allowed = requireAll
        ? policy.canAll(permissions)
        : policy.canAny(permissions);
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Gives a builder direct access to the policy — for enabling/disabling rather
/// than hiding, and for scope-dependent copy ("Của tôi" vs "Toàn công ty").
class AccessBuilder extends ConsumerWidget {
  const AccessBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AccessPolicy policy) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      builder(context, ref.watch(accessProvider));
}
