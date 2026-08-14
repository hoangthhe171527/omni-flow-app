import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';
import '../application/login_controller.dart';

/// Workspace (tenant) picker. Reached only when the signed-in account belongs to
/// more than one — a single-workspace user is entered automatically.
class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  String? _entering;

  Future<void> _enter(TenantOption tenant) async {
    setState(() => _entering = tenant.id);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .selectTenant(tenant.id);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _entering = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(tenantOptionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn workspace'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
      body: OmniAsyncView(
        value: tenants,
        onRetry: () => ref.invalidate(tenantOptionsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const OmniEmptyState(
          icon: Icons.workspaces_outline,
          title: 'Tài khoản chưa thuộc workspace nào',
          message: 'Liên hệ quản trị viên để được thêm vào công ty của bạn.',
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                child: Text(
                  'Chọn workspace để bắt đầu phiên làm việc.',
                  style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
                ),
              );
            }
            final tenant = list[index - 1];
            final busy = _entering == tenant.id;

            return OmniCard(
              onTap: _entering == null ? () => _enter(tenant) : null,
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: OmniRadius.smAll,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (tenant.code ?? tenant.name).characters
                          .take(3)
                          .toString()
                          .toUpperCase(),
                      style: OmniType.micro.copyWith(color: scheme.primary),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.name,
                          style: OmniType.bodyStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        if (tenant.memberCount != null ||
                            tenant.planLabel != null)
                          Text(
                            [
                              if (tenant.memberCount != null)
                                '${tenant.memberCount} nhân viên',
                              if (tenant.planLabel != null) tenant.planLabel!,
                            ].join(' · '),
                            style: OmniType.micro.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
