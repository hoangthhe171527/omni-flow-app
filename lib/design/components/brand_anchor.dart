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
///
/// Chỉ neo đang HIỆN mới ghi: các tab gốc sống chung trong một `IndexedStack`,
/// nên nhiều neo cùng được dựng một lúc. Tab bị ẩn có `Visibility.of` (hoặc
/// `TickerMode`) tắt — neo ở đó không ghi; khi tab đổi thì neo ghi lại / tự gỡ.
class BrandAnchor extends StatefulWidget {
  const BrandAnchor({
    super.key,
    this.withWordmark = false,
    required this.child,
  });

  /// Neo gồm logo VÀ chữ "Viomni" bên phải (header các tab gốc). Màn mở app
  /// dựa vào đây để cho chữ bay theo; false (màn đăng nhập) thì chữ mờ đi.
  final bool withWordmark;

  final Widget child;

  @override
  State<BrandAnchor> createState() => _BrandAnchorState();
}

class _BrandAnchorState extends State<BrandAnchor> {
  final _key = GlobalKey(debugLabel: 'BrandAnchor');
  ProviderContainer? _container;
  bool? _active;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (active == _active) return;
    _active = active;
    // Sau khung hình: đang dựng, mà người nghe provider có thể cũng đang dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _active != active) return;
      _container ??= ProviderScope.containerOf(context, listen: false);
      final notifier = _container!.read(brandAnchorProvider.notifier);
      if (active) {
        notifier.state = _key;
      } else if (identical(notifier.state, _key)) {
        notifier.state = null;
      }
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
