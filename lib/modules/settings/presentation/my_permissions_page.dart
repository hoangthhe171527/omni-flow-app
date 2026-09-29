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

    final dark = Theme.of(context).brightness == Brightness.dark;

    // `MPermissions.dc.html`: thẻ mực tóm tắt (tên, vai trò, số quyền màu quỹ
    // đạo sáng), rồi mỗi module một thẻ trắng có tên ở đầu.
    return Scaffold(
      appBar: const OmniAppBar(title: 'Quyền của tôi'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, OmniSpacing.xxl),
        children: [
          Container(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            decoration: BoxDecoration(
              color: dark ? OmniColors.darkMuted : OmniColors.ink,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: OmniType.money.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vai trò: ${session.roleLabel}',
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: OmniColors.inkMutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đang giữ ${held.length} quyền',
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OmniColors.orbit,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ),
          ),
          for (final entry in declared.entries)
            if (entry.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: OmniCard(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          entry.key,
                          style: OmniType.bodyStrong.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      for (final slug in entry.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              // Hình dạng nói có/không (tick đặc / vòng gạch),
                              // màu chỉ nhắc lại.
                              Icon(
                                held.contains(slug)
                                    ? Icons.check_circle_rounded
                                    : Icons.remove_circle_outline_rounded,
                                size: OmniIconSize.md,
                                color: held.contains(slug)
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  slug,
                                  style: OmniType.caption.copyWith(
                                    // Thiết kế dùng chữ đơn cách, nhưng app
                                    // không đóng gói font đơn cách và bí danh
                                    // 'monospace' không có trên mọi máy (ảnh
                                    // chụp ra ô trống). Giữ Be Vietnam Pro với
                                    // chữ số đều cột.
                                    fontFeatures: OmniType.tabular,
                                    fontWeight: FontWeight.w400,
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
              ),
        ],
      ),
    );
  }
}
