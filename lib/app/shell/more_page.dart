import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';
import '../../security/session/session_controller.dart';

/// The "Thêm" tab: the profile block, plus every module entry that didn't earn
/// a permanent tab, grouped by section.
///
/// Nothing here is hard-coded per module — modules declare entries, the registry
/// filters them by permission, this page renders whatever comes back. A module
/// that ships tomorrow appears here without this file changing.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final groups = ref.watch(visibleMenuEntriesProvider);
    final overflowTabs = ref.watch(visibleDestinationsProvider).skip(4).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          0,
          OmniSpacing.lg,
          OmniSpacing.bottomSafe,
        ),
        children: [
          OmniCard(
            child: Row(
              children: [
                OmniAvatar(
                  name: session.displayName,
                  imageUrl: session.user?.avatarUrl,
                  size: 52,
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName,
                        style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.roleLabel,
                        style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          OmniCard(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.lg,
              vertical: OmniSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.workspaces_outline, size: 20, color: scheme.primary),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Không gian làm việc',
                        style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        session.tenant?.name ?? '—',
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs that didn't fit in the bottom bar still need a way in.
          if (overflowTabs.isNotEmpty) ...[
            const OmniSectionHeader(title: 'Khu vực khác', padding: _headerPadding),
            OmniCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < overflowTabs.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: OmniSpacing.section),
                    _MenuTile(
                      icon: overflowTabs[i].icon,
                      label: overflowTabs[i].label,
                      onTap: () => context.goNamed(overflowTabs[i].routeName),
                    ),
                  ],
                ],
              ),
            ),
          ],

          for (final entry in groups.entries) ...[
            OmniSectionHeader(title: entry.key, padding: _headerPadding),
            OmniCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: OmniSpacing.section),
                    _MenuTile(
                      icon: entry.value[i].icon,
                      label: entry.value[i].label,
                      subtitle: entry.value[i].subtitle,
                      onTap: () => context.pushNamed(entry.value[i].routeName),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: OmniSpacing.xxl),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
        ],
      ),
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.xxl,
    bottom: OmniSpacing.md,
    left: OmniSpacing.xs,
  );

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục làm việc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: OmniRadius.smAll,
        ),
        child: Icon(icon, size: 18, color: scheme.primary),
      ),
      title: Text(
        label,
        style: OmniType.caption.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}
