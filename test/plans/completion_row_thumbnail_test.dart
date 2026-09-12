import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/presentation/widgets/completion_row.dart';

/// Ảnh bằng chứng trên dòng việc không được giải mã ảnh gốc.
///
/// Ảnh chụp từ điện thoại là 3000×4000; dải ảnh vẽ nó ở 88dp. `Image.network`
/// giải mã đủ 12 triệu điểm ảnh (48 MB bitmap) cho MỖI ô — một buổi sáng có
/// hai chục công đoạn xong kèm ảnh là cả dòng việc giật khi cuộn, và bộ nhớ
/// đệm ảnh bị đẩy sạch sau vài dòng. Giải mã ở cỡ vẽ nhân tỉ lệ điểm ảnh là
/// 264 điểm ảnh bề ngang: nhỏ hơn hơn trăm lần.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const photo = 'https://cdn.x/m/1.jpg';

  FeedEntry entry({List<String> photos = const [photo]}) => FeedEntry(
    id: 'a1',
    kind: FeedKind.subtaskCompleted,
    taskId: 't1',
    taskTitle: 'KAWAI HAT-5',
    at: DateTime(2026, 9, 10, 9, 35),
    userName: 'Hằng Ni',
    detail: 'Body ngoài',
    planName: 'Phục chế T9',
    photos: photos,
    day: '2026-09-10',
  );

  Widget host({double dpr = 3, bool disableAnimations = false}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(
        devicePixelRatio: dpr,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: CompletionRow(entry: entry())),
    ),
  );

  CachedNetworkImage imageOf(WidgetTester tester) =>
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

  testWidgets('ô 88dp giải mã ở 88 × tỉ lệ điểm ảnh, khoá theo chiều rộng', (
    tester,
  ) async {
    await tester.pumpWidget(host(dpr: 3));

    final image = imageOf(tester);
    expect(image.imageUrl, photo);
    expect(image.memCacheWidth, 264);
    // Một chiều: ảnh 3:4 giữ tỉ lệ rồi mới được `cover` cắt vuông. Đặt cả hai
    // chiều là bóp nó thành hình vuông trước.
    expect(image.memCacheHeight, isNull);
    expect(image.fit, BoxFit.cover);
    expect(image.width, 88);
    expect(image.height, 88);
  });

  testWidgets('không còn Image.network', (tester) async {
    await tester.pumpWidget(host());

    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
      findsNothing,
    );
  });

  testWidgets('đang tải thì ô giữ chỗ 88dp đứng đó, không phải lỗ 0dp', (
    tester,
  ) async {
    // Trong test ảnh không bao giờ tải xong (bộ nhớ đệm đĩa chờ I/O thật,
    // ngoài đồng hồ giả của pumpAndSettle). Kích thước cố định là thứ giữ bố
    // cục không nhảy, ảnh tới hay không.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('photo:$photo'))),
      const Size(88, 88),
    );
  });

  testWidgets('ảnh hỏng thì ô giữ chỗ mang biểu tượng ảnh vỡ, vẫn 88dp', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final image = imageOf(tester);

    // Dựng đúng widget mà đường lỗi sẽ dựng.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => image.errorWidget!(context, photo, Object()),
          ),
        ),
      ),
    );

    final icon = find.byIcon(Icons.broken_image_outlined);
    expect(icon, findsOneWidget);
    expect(
      tester.getSize(find.ancestor(of: icon, matching: find.byType(Container))),
      const Size(88, 88),
    );
  });

  testWidgets('mờ dần theo cài đặt trợ năng', (tester) async {
    await tester.pumpWidget(host(disableAnimations: false));
    expect(imageOf(tester).fadeInDuration, OmniDuration.fast);

    await tester.pumpWidget(host(disableAnimations: true));
    expect(imageOf(tester).fadeInDuration, Duration.zero);
  });
}
