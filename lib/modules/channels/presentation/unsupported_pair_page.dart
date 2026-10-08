import 'package:flutter/material.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';

/// Đích của đường dẫn ghép nối cho kênh mà điện thoại này không ghép được
/// (Facebook cá nhân ở mọi nơi, kênh cá nhân trên iOS).
///
/// Danh sách kênh đã ẩn các kênh này, nhưng đường dẫn `/channels/pair/:id` vẫn
/// tới được qua deep link hay bản app cũ lưu lại — trước đây nó mở thẳng màn
/// ghép nối, và với Facebook cá nhân là màn đăng nhập thu cookie.
class UnsupportedPairPage extends StatelessWidget {
  const UnsupportedPairPage({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text('Ghép nối ${channel.meta.name}'),
      ),
      body: const OmniEmptyState(
        icon: Icons.phonelink_off_rounded,
        title: 'Kênh này chưa hỗ trợ trên điện thoại',
        message: 'Kết nối kênh này từ Viomni trên máy tính.',
      ),
    );
  }
}
