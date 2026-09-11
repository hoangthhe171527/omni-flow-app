import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/appearance_providers.dart';

/// Chọn nền cho cả app: lưới ô, mỗi ô là bản vẽ THẬT thu nhỏ của nền đó.
///
/// Chạm là đổi ngay — không nút Lưu: nền là thứ nhìn thấy tức thì, và một
/// nút Lưu chỉ thêm một bước giữa mắt và quyết định. Lỗi mạng thì hoàn về
/// (provider lo) và nói ra ở đây.
class BackgroundPage extends ConsumerWidget {
  const BackgroundPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(backgroundProvider);
    final scheme = Theme.of(context).colorScheme;

    Future<void> pick(String? name) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(backgroundProvider.notifier).set(name);
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } on Object {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được nền. Thử lại khi có mạng.'),
          ),
        );
      }
    }

    return Scaffold(
      // OmniAppBar như hai màn tài khoản kia: màn đẩy vào nên nó tự giữ nút
      // quay lại và không vẽ avatar (xem OmniAppBar).
      appBar: const OmniAppBar(title: 'Nền'),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.bottomSafe,
        ),
        mainAxisSpacing: OmniSpacing.md,
        crossAxisSpacing: OmniSpacing.md,
        childAspectRatio: 3 / 4.6,
        children: [
          _Tile(
            label: 'Mặc định',
            selected: current == null,
            onTap: () => pick(null),
            preview: ColoredBox(color: scheme.surfaceContainerHighest),
          ),
          for (final n in OmniBackdrops.names)
            _Tile(
              label: OmniBackdrops.labelOf(n)!,
              selected: current == n,
              onTap: () => pick(n),
              preview: OmniBackdrop(name: n, child: const SizedBox.expand()),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: OmniRadius.lgAll,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (selected)
                      Positioned(
                        right: OmniSpacing.sm,
                        top: OmniSpacing.sm,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              label,
              style: text.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
