import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../settings_module.dart';

/// Avatar ở góc trên bên phải; bấm vào mở màn Tài khoản.
///
/// Cắm vào [OmniAccountSlot] một lần ở gốc app, nên mọi màn dựng [OmniAppBar]
/// đều có nó mà không phải nhớ gì.
///
/// Trước đây nút bật một menu nổi (đổi ảnh, nền, thông báo, quyền, đăng xuất).
/// Mọi việc đó giờ nằm trong [SettingsModule.account] — đổi ảnh ở thẻ hồ sơ.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key, this.tile = false});

  /// Avatar tròn 36 trong vùng chạm 44 — kiểu của [OmniTopBar]. Mặc định vẫn
  /// là ảnh tròn 32 có đệm ngang của [OmniAppBar].
  final bool tile;

  void _open(BuildContext context) => context.pushNamed(SettingsModule.account);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.fullName ?? 'Tài khoản';

    if (tile) return _buildTile(context, name, user?.avatarUrl);

    return Padding(
      // Đệm đều hai bên: nút giờ đứng ở `leading` (góc trái) của OmniAppBar,
      // trong một ô 56dp — 32dp ảnh ở giữa.
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
      child: Semantics(
        button: true,
        label: 'Tài khoản $name',
        excludeSemantics: true,
        onTap: () => _open(context),
        child: InkResponse(
          onTap: () => _open(context),
          radius: 24,
          // Chéo mờ giữa ảnh cũ và ảnh mới, để người dùng thấy nó đã đổi
          // THẬT chứ không phải màn hình vừa nháy một cái. Theo thang chung
          // và về 0 khi người dùng tắt hiệu ứng — ảnh đổi tức thì.
          child: AnimatedSwitcher(
            duration: OmniMotion.of(context).base,
            child: OmniAvatar(
              key: ValueKey(user?.avatarUrl ?? name),
              name: name,
              imageUrl: user?.avatarUrl,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, String name, String? imageUrl) {
    return Semantics(
      button: true,
      label: 'Tài khoản $name',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: SizedBox.square(
        dimension: 44,
        child: InkResponse(
          radius: 22,
          onTap: () => _open(context),
          child: Center(
            child: AnimatedSwitcher(
              duration: OmniMotion.of(context).base,
              child: OmniAvatar(
                key: ValueKey(imageUrl ?? name),
                name: name,
                imageUrl: imageUrl,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
