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
      // `MBackground.dc.html`: một dòng giải thích, lưới ba cột, ô đang chọn
      // có vành đôi màu chính.
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Nền cho khung chat và bảng dự án.',
                style: OmniType.body.copyWith(
                  color: OmniColors.byBrightness(
                    context,
                    OmniColors.secondaryForeground,
                    scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              OmniSpacing.bottomSafe,
            ),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 3 / 5.4,
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
                    preview: OmniBackdrop(
                      name: n,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
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
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: OmniRadius.lgAll,
                  border: selected
                      ? null
                      : Border.all(color: scheme.outlineVariant),
                  // Vành đôi: khe màu nền + vành màu chính.
                  boxShadow: selected
                      ? [
                          BoxShadow(color: scheme.primary, spreadRadius: 4),
                          BoxShadow(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
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
            const SizedBox(height: 6),
            Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.micro.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
