import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';
import '../application/login_controller.dart';
import 'widgets/auth_widgets.dart';

/// Màn chọn công ty — cùng da hướng "Quỹ đạo" (duyệt 26/11/2026): nền đen, đã
/// đăng nhập nên KHÔNG còn logo — tiêu đề lớn 32/800 căn trái "Chọn công ty",
/// viên email tài khoản đang dùng, danh sách công ty trong thẻ bo 16 (ô viết
/// tắt mỗi công ty một tông, dòng cao 72) và "Đăng xuất" là nút chữ đỏ ở đáy,
/// không tranh việc chính.
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
      showOmniToast(context, error.message);
    }
  }

  void _logout() {
    ref.read(authSignedInEmailProvider.notifier).state = null;
    ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(tenantOptionsProvider);
    final email =
        ref.watch(sessionProvider.select((s) => s.user?.email)) ??
        ref.watch(authSignedInEmailProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Chọn công ty',
                          style: authTitleStyle(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccountChip(email: email),
                    ],
                  ),
                ),
                Expanded(
                  child: OmniAsyncView(
                    value: tenants,
                    onRetry: () => ref.invalidate(tenantOptionsProvider),
                    isEmpty: (list) => list.isEmpty,
                    empty: const OmniEmptyState(
                      icon: LucideIcons.boxes,
                      title: 'Tài khoản chưa thuộc công ty nào',
                      message:
                          'Liên hệ quản trị viên để được thêm vào công ty của '
                          'bạn.',
                    ),
                    data: (list) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      children: [
                        OmniGroupSection(
                          title: 'Công ty · ${list.length}',
                          dividerIndent: 72,
                          children: [
                            for (final tenant in list)
                              _WorkspaceRow(
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: OmniColors.dangerTextOf(context),
                      textStyle: OmniType.input.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Đăng xuất'),
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

/// Viên tài khoản: ô chữ đầu tròn + email đang đăng nhập.
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = email?.trim() ?? '';
    final shown = text.isEmpty ? 'Phiên đăng nhập đã xác thực' : text;
    final initial = text.isEmpty ? '?' : text.characters.first.toUpperCase();

    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.pillAll,
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.body.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.tenant,
    required this.busy,
    required this.onTap,
  });

  final TenantOption tenant;
  final bool busy;
  final VoidCallback? onTap;

  /// Mỗi công ty một tông cố định (theo id) để nhận ra nhanh giữa nhiều công
  /// ty — ngoại lệ màu như ô biểu tượng ứng dụng.
  static const _hues = [
    OmniHue.blue,
    OmniHue.teal,
    OmniHue.violet,
    OmniHue.orange,
  ];

  static String _initials(TenantOption tenant) {
    final code = tenant.code?.trim();
    if (code != null && code.isNotEmpty) {
      return code.characters.take(3).toString().toUpperCase();
    }
    final words = tenant.name.trim().split(RegExp(r'\s+'));
    return words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = OmniFeatureTones.of(
      context,
      // Tổng mã ký tự: ổn định giữa các lần mở app (hashCode thì không chắc).
      _hues[tenant.id.codeUnits.fold(0, (a, b) => a + b) % _hues.length],
    );
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(tenant),
                    style: OmniType.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.input.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: OmniType.bodySm.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  Semantics(
                    label: 'Đang vào',
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.primary,
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    LucideIcons.chevronRight,
                    color: scheme.onSurfaceVariant,
                    size: OmniIconSize.md,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
