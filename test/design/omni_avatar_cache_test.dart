import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_avatar.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';

/// Avatar không được giải mã ảnh gốc.
///
/// Một avatar Zalo là 640×640, và thẻ việc vẽ nó ở 24dp. `Image.network` giải
/// mã đủ 640×640 (1,6 MB bitmap) cho MỖI avatar trên màn — một danh sách 30
/// việc với hai người mỗi việc là ~100 MB bitmap để vẽ những vòng tròn 24dp,
/// và bộ nhớ đệm ảnh của Flutter đầy sau hai lần cuộn. Giải mã ở đúng cỡ vẽ
/// (nhân với tỉ lệ điểm ảnh) là 72×72: nhỏ hơn tám mươi lần.
///
/// Và bộ nhớ đệm đĩa: cùng một khuôn mặt hiện ở mười chỗ, và `Image.network`
/// tải lại nó mỗi lần cuộn ra khỏi bộ nhớ đệm. Ngoài xưởng sóng yếu, đó là
/// những vòng tròn trống nhấp nháy.
void main() {
  const url = 'https://x/a.png';

  Widget host({
    double dpr = 3,
    bool disableAnimations = false,
    String? imageUrl = url,
    double size = 24,
  }) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(
        devicePixelRatio: dpr,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: OmniAvatar(name: 'Hằng Ni', imageUrl: imageUrl, size: size),
      ),
    ),
  );

  CachedNetworkImage imageOf(WidgetTester tester) =>
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

  testWidgets('giải mã ở đúng cỡ vẽ nhân tỉ lệ điểm ảnh, không phải cỡ gốc', (
    tester,
  ) async {
    await tester.pumpWidget(host(dpr: 3, size: 24));

    final image = imageOf(tester);
    expect(image.imageUrl, url);
    expect(image.memCacheWidth, 72);
    // Chỉ khoá theo CHIỀU RỘNG: đặt cả hai chiều là `ResizeImage` giải mã đúng
    // cỡ đó bất kể tỉ lệ khung — một ảnh 3:4 bị bóp thành hình vuông rồi mới
    // được `cover` cắt. Một chiều thì chiều kia theo tỉ lệ gốc.
    expect(image.memCacheHeight, isNull);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('cỡ khác, tỉ lệ khác thì con số khác theo', (tester) async {
    await tester.pumpWidget(host(dpr: 2.625, size: 44));

    expect(imageOf(tester).memCacheWidth, (44 * 2.625).round());
  });

  testWidgets('không còn Image.network', (tester) async {
    await tester.pumpWidget(host());

    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
      findsNothing,
    );
  });

  testWidgets('đang tải thì chữ tắt đứng chỗ, không để vòng tròn trống', (
    tester,
  ) async {
    // Trong test ảnh không bao giờ tải xong (bộ nhớ đệm đĩa chờ I/O thật,
    // ngoài đồng hồ giả của pumpAndSettle) — nên đây là trạng thái đang tải.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('HN'), findsOneWidget);
  });

  testWidgets('ảnh hỏng thì rơi về chữ tắt', (tester) async {
    await tester.pumpWidget(host());
    final image = imageOf(tester);

    // Dựng đúng widget mà đường lỗi sẽ dựng: Android từ chối một URL nền tảng
    // hết hạn, và vòng tròn không được để trống.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => image.errorWidget!(context, url, Object()),
          ),
        ),
      ),
    );

    expect(find.text('HN'), findsOneWidget);
  });

  testWidgets('không có URL thì không dựng ảnh mạng', (tester) async {
    await tester.pumpWidget(host(imageUrl: null));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('HN'), findsOneWidget);
  });

  group('hiệu ứng mờ dần theo cài đặt trợ năng', () {
    testWidgets('bình thường thì theo thang chung', (tester) async {
      await tester.pumpWidget(host(disableAnimations: false));

      expect(imageOf(tester).fadeInDuration, OmniDuration.fast);
    });

    testWidgets('tắt hiệu ứng thì hiện ngay', (tester) async {
      await tester.pumpWidget(host(disableAnimations: true));

      final image = imageOf(tester);
      expect(image.fadeInDuration, Duration.zero);
      expect(image.fadeOutDuration, Duration.zero);
    });
  });
}
