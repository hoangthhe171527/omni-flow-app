import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/preferences_store.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Giới thiệu Kho lần đầu (rà soát app mobile 12/11, `#s-intro`): 3 trang
/// Hàng về → Nhận → Bán, mỗi trang một câu, hình dựng bằng chính các thẻ của
/// app, một nút chính và "Bỏ qua".
///
/// Hiện MỘT lần cho mỗi máy, ngay lần đầu mở Tồn kho hoặc Hàng sắp về; xem lại
/// từ menu ⋯ của Tồn kho. Không đọc được bộ nhớ máy (test không override
/// `sharedPreferencesProvider`) thì không hiện gì.
const inventoryIntroSeenKey = 'inventory.intro_seen_v1';

/// Gọi sau khung đầu tiên của màn Kho. An toàn khi gọi nhiều lần: cờ ghi
/// trước khi mở nên màn thứ hai không mở lại.
Future<void> maybeShowInventoryIntro(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(inventoryIntroSeenKey) ?? false) return;
    await prefs.setBool(inventoryIntroSeenKey, true);
  } on Object {
    return;
  }
  if (!context.mounted) return;
  await showInventoryIntro(context);
}

/// Mở giới thiệu (cả khi đã xem — dùng cho lối "Giới thiệu Kho").
Future<void> showInventoryIntro(BuildContext context) => showOmniSheet<void>(
  context: context,
  builder: (_) => const _InventoryIntro(),
);

class _IntroPage {
  const _IntroPage(this.title, this.body, this.art);

  final String title;
  final String body;
  final Widget art;
}

class _InventoryIntro extends StatefulWidget {
  const _InventoryIntro();

  @override
  State<_InventoryIntro> createState() => _InventoryIntroState();
}

class _InventoryIntroState extends State<_InventoryIntro> {
  final _pager = PageController();
  int _page = 0;

  static const _pages = [
    _IntroPage(
      'Hàng về',
      'Lô đang về nằm ở Sắp về. Mở lô để xem từng cây.',
      _ArtCard(
        icon: Icons.local_shipping_outlined,
        title: 'Lô đang về',
        sub: '24 cây · dự kiến về',
        badge: 'Đang về',
      ),
    ),
    _IntroPage(
      'Nhận hàng',
      'Hàng tới thì Nhận hàng: đánh dấu từng cây, cây vào Tồn kho.',
      _ArtCard(
        icon: Icons.qr_code_scanner_rounded,
        title: 'Nhận hàng',
        sub: 'Đánh dấu từng serial',
        badge: '✓',
      ),
    ),
    _IntroPage(
      'Giữ và bán',
      'Ở Tồn kho, giữ cây cho khách hoặc bán ngay.',
      _ArtCard(
        icon: Icons.inventory_2_outlined,
        title: 'Còn bán',
        sub: 'Giữ cho khách · Bán',
        badge: 'Tồn kho',
      ),
    ),
  ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pager.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pages.length - 1;
    return Semantics(
      label: 'Giới thiệu Kho',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('inv-intro-skip'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Bỏ qua'),
              ),
            ),
            SizedBox(
              height: 260,
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final p in _pages)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        p.art,
                        const SizedBox(height: 24),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: OmniType.title.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: OmniType.body.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('inv-intro-next'),
              onPressed: _next,
              child: Text(last ? 'Bắt đầu' : 'Tiếp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hình minh hoạ: một thẻ giống dòng của app (ô icon, tên, dòng phụ, nhãn).
class _ArtCard extends StatelessWidget {
  const _ArtCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            OmniIconTile(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 2,
                    style: OmniType.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OmniBadge(label: badge, tone: OmniTone.info),
          ],
        ),
      ),
    );
  }
}
