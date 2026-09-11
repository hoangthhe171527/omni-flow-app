import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/appearance_providers.dart';

/// Nền cả app phía sau một màn "không gian" — chat, bảng dự án.
///
/// Mảnh nối duy nhất giữa provider (module settings) và widget vẽ (design):
/// hai màn kia chỉ bọc thân mình trong đây, không màn nào phải nhớ provider.
class SurfaceBackdrop extends ConsumerWidget {
  const SurfaceBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      OmniBackdrop(name: ref.watch(backgroundProvider), child: child);
}
