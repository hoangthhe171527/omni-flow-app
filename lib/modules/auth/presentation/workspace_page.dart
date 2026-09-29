import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';
import '../application/login_controller.dart';

/// Workspace (tenant) picker. Reached when the signed-in account belongs to
/// more than one — a single-workspace user is entered automatically — and from
/// the "Đổi" button in "Tất cả".
///
/// Bố cục theo `MWorkspace.dc.html`: logo và "Đăng xuất" trên cùng, tiêu đề
/// lớn, mỗi không gian một thẻ với ô chữ viết tắt.
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.xl,
                    OmniSpacing.sm,
                    OmniSpacing.sm,
                    OmniSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const OmniBrandMark(semanticLabel: 'OmniCRM'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => ref
                            .read(sessionControllerProvider.notifier)
                            .logout(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.xl,
                    OmniSpacing.md,
                    OmniSpacing.xl,
                    OmniSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Chọn không gian làm việc',
                          style: OmniType.largeTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tài khoản của bạn đang tham gia nhiều không gian.',
                        style: OmniType.bodyStrong.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
                    data: (list) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        OmniSpacing.xl,
                        0,
                        OmniSpacing.xl,
                        OmniSpacing.section,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: OmniSpacing.md),
                      itemBuilder: (context, index) {
                        final tenant = list[index];
                        return _WorkspaceCard(
                          tenant: tenant,
                          tone: _WorkspaceTone.at(index),
                          busy: _entering == tenant.id,
                          onTap: _entering == null
                              ? () => _enter(tenant)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màu ô chữ viết tắt, xoay vòng theo thứ tự — chỉ để các thẻ khác nhau
/// liếc là phân biệt, không mang nghĩa gì.
class _WorkspaceTone {
  const _WorkspaceTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const _tones = [
    _WorkspaceTone(OmniColors.ink, OmniColors.orbit),
    _WorkspaceTone(OmniColors.accent, OmniColors.primaryPressed),
    _WorkspaceTone(OmniColors.warningSoft, OmniColors.warningText),
    _WorkspaceTone(OmniColors.infoSoft, OmniColors.infoText),
  ];

  static _WorkspaceTone at(int index) => _tones[index % _tones.length];
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.tenant,
    required this.tone,
    required this.busy,
    required this.onTap,
  });

  final TenantOption tenant;
  final _WorkspaceTone tone;
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
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: OmniRadius.xlAll,
        side: busy
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: OmniRadius.lgAll,
                ),
                alignment: Alignment.center,
                child: Text(
                  (tenant.code ?? tenant.name).characters
                      .take(3)
                      .toString()
                      .toUpperCase(),
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.28,
                    color: tone.foreground,
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
                        fontWeight: FontWeight.w700,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                      backgroundColor: scheme.primaryContainer,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.outline,
                  size: OmniIconSize.lg,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
