import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Khoá của logo đang hiện trên màn hình, để màn mở app (và màn đăng nhập) biết
/// bay logo về ĐÚNG chỗ nó sẽ đứng, đọc rect từ `currentContext` của khoá này.
///
/// Null khi không có logo nào được neo.
final brandAnchorProvider = StateProvider<GlobalKey?>((ref) => null);

/// Đánh dấu một logo là "đích" của hiệu ứng bay. Khi dựng xong khung đầu nó ghi
/// khoá của mình vào [brandAnchorProvider]; khi gỡ, nó chỉ xoá nếu khoá đó vẫn
/// là của nó — một neo mới hơn (màn khác vừa dựng) không bị xoá nhầm.
class BrandAnchor extends StatefulWidget {
  const BrandAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<BrandAnchor> createState() => _BrandAnchorState();
}

class _BrandAnchorState extends State<BrandAnchor> {
  final _key = GlobalKey(debugLabel: 'BrandAnchor');
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _container = ProviderScope.containerOf(context, listen: false);
      _container!.read(brandAnchorProvider.notifier).state = _key;
    });
  }

  @override
  void dispose() {
    final container = _container;
    if (container != null) {
      // Hoãn một nhịp: đang gỡ cây widget, mà người nghe provider có thể đang
      // dựng lại — ghi đồng bộ ở đây là ghi giữa lúc dựng.
      scheduleMicrotask(() {
        try {
          final notifier = container.read(brandAnchorProvider.notifier);
          if (identical(notifier.state, _key)) notifier.state = null;
        } catch (_) {
          // Container đã bị huỷ cùng app: không còn gì để xoá.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
