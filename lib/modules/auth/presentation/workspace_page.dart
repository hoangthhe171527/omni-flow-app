import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';
import '../application/login_controller.dart';
import 'widgets/auth_widgets.dart';

/// Màn chọn không gian làm việc (`#s-auth-workspace`): biểu tượng V-Orbit 64×64,
/// viên thuốc hiển thị email tài khoản đang đăng nhập, danh sách tổ chức trong
/// `OmniGroupSection` (bo 18) với ô chữ tắt 40×40 một tông thương hiệu và nút
/// `Đăng xuất` ở vùng ngón cái dưới màn.
class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  String? _entering;

  Future<void> _enter(TenantOption tenant) async {
    HapticFeedback.selectionClick();
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

  void _logout() {
    ref.read(authSignedInEmailProvider.notifier).state = null;
    ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(tenantOptionsProvider);
    final scheme = Theme.of(context).colorScheme;
    final email =
        ref.watch(sessionProvider.select((s) => s.user?.email)) ??
        ref.watch(authSignedInEmailProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        const AuthBrandHeader(
                          title: 'Chọn không gian làm việc',
                          showWordmark: false,
                          brandSemanticLabel: 'Viomni',
                          headerSemantics: true,
                        ),
                        const SizedBox(height: 10),
                        _AccountIdentityPill(email: email),
                      ],
                    ),
                  ),
                  Expanded(
                    child: OmniAsyncView(
                      value: tenants,
                      onRetry: () => ref.invalidate(tenantOptionsProvider),
                      isEmpty: (list) => list.isEmpty,
                      empty: const OmniEmptyState(
                        icon: Icons.workspaces_outline,
                        title: 'Tài khoản chưa thuộc workspace nào',
                        message:
                            'Liên hệ quản trị viên để được thêm vào công ty của '
                            'bạn.',
                      ),
                      data: (list) => ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          OmniGroupSection(
                            title: 'Công ty của bạn (${list.length})',
                            dividerIndent: 68,
                            children: [
                              for (final tenant in list)
                                _WorkspaceCard(
                                  tenant: tenant,
                                  busy: _entering == tenant.id,
                                  onTap: _entering == null
                                      ? () => _enter(tenant)
                                      : null,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Đăng xuất'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountIdentityPill extends StatelessWidget {
  const _AccountIdentityPill({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasEmail = email != null && email!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: OmniRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              hasEmail ? email!.trim() : 'Phiên đăng nhập đã xác thực',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.tenant,
    required this.busy,
    required this.onTap,
  });

  final TenantOption tenant;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (tenant.memberCount != null) '${tenant.memberCount} nhân viên',
      if (tenant.planLabel != null) tenant.planLabel!,
    ].join(' · ');

    return Material(
      color: busy
          ? scheme.onSurface.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              // Ô chữ tắt 40×40 bo 12 đồng bộ một tông màu thương hiệu.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  (tenant.code ?? tenant.name).characters
                      .take(3)
                      .toString()
                      .toUpperCase(),
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.28,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: OmniType.listTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: OmniType.tabular,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                Semantics(
                  label: 'Đang vào',
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                      backgroundColor: scheme.primaryContainer,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: OmniIconSize.lg,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
