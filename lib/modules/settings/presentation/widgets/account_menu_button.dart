import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../data/avatar_api.dart';
import '../../settings_module.dart';

/// Avatar ở góc trên bên phải, và menu tài khoản mở ra từ đó.
///
/// Cắm vào [OmniAccountSlot] một lần ở gốc app, nên mọi màn dựng [OmniAppBar]
/// đều có nó mà không phải nhớ gì.
///
/// Menu gộp luôn hai màn tài khoản đang nằm trong tab "Thêm" (Thông báo, Quyền
/// của tôi): chúng là màn tài khoản, và đây là chỗ người ta đi tìm chúng.
class AccountMenuButton extends ConsumerStatefulWidget {
  const AccountMenuButton({super.key});

  @override
  ConsumerState<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends ConsumerState<AccountMenuButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.fullName ?? 'Tài khoản';

    return Padding(
      // Đệm đều hai bên: nút giờ đứng ở `leading` (góc trái) của OmniAppBar,
      // trong một ô 56dp — 32dp ảnh ở giữa.
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
      child: InkResponse(
        onTap: _busy ? null : _open,
        radius: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Chéo mờ giữa ảnh cũ và ảnh mới, để người dùng thấy nó đã đổi
            // THẬT chứ không phải màn hình vừa nháy một cái. Theo thang chung
            // và về 0 khi người dùng tắt hiệu ứng — ảnh đổi tức thì.
            AnimatedSwitcher(
              duration: OmniMotion.of(context).base,
              child: OmniAvatar(
                key: ValueKey(user?.avatarUrl ?? name),
                name: name,
                imageUrl: user?.avatarUrl,
                size: 32,
              ),
            ),
            // Vành tiến độ mảnh trong lúc tải lên; ảnh cũ VẪN hiện bên dưới.
            // Thay nó bằng một ô xám là lấy mất mốc thị giác của người đang chờ.
            if (_busy)
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final user = ref.read(sessionProvider).user;
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);

    final choice = await showMenu<String>(
      context: context,
      // Neo ngay dưới avatar, không bật ra giữa màn.
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: OmniAvatar(
              name: user?.fullName ?? 'Tài khoản',
              imageUrl: user?.avatarUrl,
              size: 40,
            ),
            title: Text(user?.fullName ?? 'Tài khoản'),
            subtitle: Text(user?.email ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'photo',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.image_outlined),
            title: Text('Đổi ảnh đại diện'),
          ),
        ),
        const PopupMenuItem(
          value: 'background',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.wallpaper_outlined),
            title: Text('Nền'),
          ),
        ),
        const PopupMenuItem(
          value: 'notifications',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_outlined),
            title: Text('Thông báo'),
          ),
        ),
        const PopupMenuItem(
          value: 'permissions',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shield_outlined),
            title: Text('Quyền của tôi'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.power_settings_new_rounded),
            title: Text('Đăng xuất'),
          ),
        ),
      ],
    );

    if (!mounted) return;

    switch (choice) {
      case 'photo':
        await _pickAndUpload();
      case 'background':
        context.pushNamed(SettingsModule.background);
      case 'notifications':
        context.pushNamed(SettingsModule.notifications);
      case 'permissions':
        context.pushNamed(SettingsModule.myPermissions);
      case 'logout':
        await ref.read(sessionControllerProvider.notifier).logout();
      case _:
        break;
    }
  }

  Future<void> _pickAndUpload() async {
    // Nén ở CLIENT trước khi gửi. Một ảnh 12MB từ camera điện thoại sẽ bị API
    // từ chối ở trần 5MB, và "tệp quá lớn" là một cách tệ để nói "máy bạn chụp
    // ảnh to quá". Cùng tham số `thread_page.dart` và `task_detail_page.dart`
    // đang dùng.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(avatarApiProvider).upload(picked.path);
      // Đọc lại phiên thay vì tự vá URL vào: server là nơi biết URL cuối cùng,
      // và một bản sao ở client sẽ lệch ngay lần đầu server đổi cách sinh URL.
      await ref.read(sessionControllerProvider.notifier).refreshContext();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
