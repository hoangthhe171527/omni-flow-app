import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/module/module_registry.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';

/// "Quyền của tôi" — every permission slug the app gates on, grouped by module,
/// with what this session actually holds.
///
/// This is possible only because each module declares its own slugs. It turns
/// "tại sao tôi không thấy nút này?" from a support ticket into something the
/// user and their admin can answer in ten seconds.
class MyPermissionsPage extends ConsumerWidget {
  const MyPermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final declared = ref.watch(declaredPermissionsProvider);
    final session = ref.watch(sessionProvider);
    final held = session.policy.slugs;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quyền của tôi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.md,
          OmniSpacing.lg,
          OmniSpacing.xxl,
        ),
        children: [
          OmniCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vai trò: ${session.roleLabel}',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Đang giữ ${held.length} quyền',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final entry in declared.entries) ...[
            if (entry.value.isNotEmpty) ...[
              OmniSectionHeader(
                title: entry.key,
                padding: const EdgeInsets.only(
                  top: OmniSpacing.xxl,
                  bottom: OmniSpacing.md,
                ),
              ),
              OmniCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.lg,
                  vertical: OmniSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final slug in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              held.contains(slug)
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_circle_outline_rounded,
                              size: 16,
                              color: held.contains(slug)
                                  ? OmniColors.success
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: OmniSpacing.sm),
                            Expanded(
                              child: Text(
                                slug,
                                style: OmniType.micro.copyWith(
                                  color: held.contains(slug)
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
