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
class AccountMenuButton extends ConsumerStatefulWidget {
  const AccountMenuButton({super.key, this.tile = false});

  /// Avatar tròn 36 trong vùng chạm 44 — kiểu của [OmniTopBar]. Mặc định vẫn
  /// là ảnh tròn 32 có đệm ngang của [OmniAppBar].
  final bool tile;

  @override
  ConsumerState<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends ConsumerState<AccountMenuButton> {
  final _buttonKey = GlobalKey(debugLabel: 'AccountMenuButton');

  /// Bấm avatar mở thẳng màn Tài khoản (`tat-ca-tai-khoan-uiux.html`): menu
  /// nhỏ 2 dòng ở giữa chỉ thêm một chạm.
  void _open() => context.pushNamed(SettingsModule.account);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.fullName ?? 'Tài khoản';

    if (widget.tile) return _buildTile(context, name);

    return Padding(
      key: _buttonKey,
      // Đệm đều hai bên: nút giờ đứng ở `leading` (góc trái) của OmniAppBar,
      // trong một ô 56dp — 32dp ảnh ở giữa.
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
      child: Semantics(
        button: true,
        label: 'Tài khoản $name',
        excludeSemantics: true,
        onTap: _open,
        child: InkResponse(
          onTap: _open,
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

  Widget _buildTile(BuildContext context, String name) {
    final user = ref.watch(sessionProvider).user;
    return Semantics(
      key: _buttonKey,
      button: true,
      label: 'Tài khoản $name',
      excludeSemantics: true,
      onTap: _open,
      // Hình 36, vùng chạm 44: lớp ngoài bắt chạm cả phần đệm.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Material(
              key: const ValueKey('account-avatar-face'),
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _open,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 36,
                  child: AnimatedSwitcher(
                    duration: OmniMotion.of(context).base,
                    child: OmniAvatar(
                      key: ValueKey(user?.avatarUrl ?? name),
                      name: name,
                      imageUrl: user?.avatarUrl,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
