import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/module/module_registry.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../domain/permission_labels.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Nền xám; thẻ đầu là nhóm tóm tắt (tên, vai trò, số quyền), rồi mỗi
    // module một nhóm lồng cách nhau 12px. Ô icon 28×28 một tông chuẩn 54px.
    return Scaffold(
      appBar: const OmniAppBar(title: 'Quyền của tôi'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, OmniSpacing.bottomSafe),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(title: session.displayName),
              OmniGroupRow(title: 'Vai trò', value: session.roleLabel),
              OmniGroupRow(title: 'Đang giữ', value: '${held.length} quyền'),
            ],
          ),
          for (final entry in declared.entries)
            if (entry.value.isNotEmpty) ...[
              const SizedBox(height: OmniGroupSection.gap),
              OmniGroupSection(
                title: entry.key,
                children: [
                  for (final slug in entry.value)
                    OmniGroupRow(
                      title: permissionLabel(entry.key, slug),
                      maxTitleLines: 2,
                      leading: OmniIconTile(
                        held.contains(slug)
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        color: held.contains(slug)
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        background: held.contains(slug)
                            ? scheme.primary.withValues(alpha: dark ? .16 : .10)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
