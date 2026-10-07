import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/utils/media_url.dart';
import 'package:omni_app/modules/inbox/application/media_url_resolver.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_attachments.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_images.dart';
import 'package:video_player/video_player.dart';

/// Link media Hộp thư có chữ ký hết hạn sau 12 giờ (MS-I24). Ảnh đã tự xin URL
/// ký mới từ Đợt 6b; VIDEO thì chưa — việc dồn từ Đợt 7 ("video/tệp trong tin
/// app không tự tải lại khi link ký hết hạn"): một video mở sau 12 giờ đứng
/// mãi ở vòng xoay, không lỗi, không tải lại.
void main() {
  group('MediaUrlResolver', () {
    const old =
        'https://api.vn/api/v1/inbox/media/t1/a.mp4?expires=1'
        '&signature=v1';
    const fresh =
        'https://api.vn/api/v1/inbox/media/t1/a.mp4?expires=2'
        '&signature=v2';

    /// Resolver với một "server" giả: mỗi lượt tải lại đổi chữ ký.
    ({MediaUrlResolver resolver, List<int> reloads}) build({
      Map<String, String> table = const {},
      bool failReload = false,
      DateTime Function()? clock,
    }) {
      final reloads = <int>[];
      final resolver = MediaUrlResolver(
        onReload: () async {
          reloads.add(reloads.length);
          if (failReload) throw Exception('mất mạng');
        },
        lookup: (url) => table[mediaCacheKey(url)],
        clock: clock ?? () => DateTime(2026, 10, 7, 9),
      );
      return (resolver: resolver, reloads: reloads);
    }

    test('xin URL mới: tải lại tin một lượt rồi trả URL ký mới', () async {
      final it = build(table: {mediaCacheKey(old): fresh});

      expect(await it.resolver.refresh(old), fresh);
      expect(it.reloads, hasLength(1));
    });

    test('CÙNG một URL chỉ xin lại ĐÚNG một lần', () async {
      final it = build(table: {mediaCacheKey(old): fresh});

      await it.resolver.refresh(old);
      expect(await it.resolver.refresh(old), isNull);
      expect(
        it.reloads,
        hasLength(1),
        reason: 'Lần hỏng thứ hai rơi về trạng thái lỗi, không gọi API nữa.',
      );
    });

    test('URL ký mới cũng hỏng → vẫn chỉ một lượt nữa, rồi dừng', () async {
      final it = build(
        table: {mediaCacheKey(old): fresh, mediaCacheKey(fresh): fresh},
      );

      await it.resolver.refresh(old);
      // URL mới mang cùng khoá cache (chỉ đổi chữ ký) nên đã được tính.
      expect(await it.resolver.refresh(fresh), isNull);
      expect(it.reloads, hasLength(1));
    });

    test('người dùng bấm tải lại thì được xin lại (force)', () async {
      final it = build(table: {mediaCacheKey(old): fresh});

      await it.resolver.refresh(old);
      expect(await it.resolver.refresh(old, force: true), fresh);
      expect(it.reloads, hasLength(2));
    });

    test('hai tệp hỏng cùng lúc chỉ tốn MỘT lượt tải lại', () async {
      const other = 'https://api.vn/api/v1/inbox/media/t1/b.mp4?signature=v1';
      final it = build(
        table: {mediaCacheKey(old): fresh, mediaCacheKey(other): other},
      );

      final results = await Future.wait<String?>([
        it.resolver.refresh(old),
        it.resolver.refresh(other),
      ]);

      expect(results, [fresh, other]);
      expect(it.reloads, hasLength(1));
    });

    test('lượt tải lại hỏng → null, và không tiêu lượt của URL đó', () async {
      final it = build(failReload: true);

      expect(await it.resolver.refresh(old), isNull);
      expect(it.reloads, hasLength(1));
    });

    test('không tìm thấy URL mới (tệp đã xoá) → null', () async {
      final it = build();

      expect(await it.resolver.refresh(old), isNull);
    });

    test(
      'tải lại cả cửa sổ (đường của ảnh) tôn trọng thời gian nghỉ',
      () async {
        var now = DateTime(2026, 10, 7, 9);
        final it = build(clock: () => now);

        await it.resolver.reloadAll();
        await it.resolver.reloadAll();
        expect(it.reloads, hasLength(1));

        now = now.add(mediaReloadCooldown + const Duration(minutes: 1));
        await it.resolver.reloadAll();
        expect(it.reloads, hasLength(2));
      },
    );
  });

  group('video có link hết hạn', () {
    final created = <String>[];

    setUp(() {
      created.clear();
      videoControllerFactory = (uri) {
        created.add(uri.toString());
        return VideoPlayerController.networkUrl(uri);
      };
    });
    tearDown(resetVideoControllerFactory);

    const old = 'https://cdn.example/t1/a.mp4?signature=v1';
    const fresh = 'https://cdn.example/t1/a.mp4?signature=v2';

    Widget host(MediaUrlResolver resolver) => MaterialApp(
      home: Scaffold(
        body: MediaReloadScope(
          onLoadError: () {},
          resolver: resolver,
          child: const MessageVideoAttachments(
            attachments: [MessageAttachment(url: old, type: 'video/mp4')],
          ),
        ),
      ),
    );

    testWidgets('mở không được → xin URL mới MỘT lần rồi dựng lại', (
      tester,
    ) async {
      var lookups = 0;
      final resolver = MediaUrlResolver(
        onReload: () async {},
        lookup: (_) {
          lookups++;
          return fresh;
        },
      );

      await tester.pumpWidget(host(resolver));
      await tester.pumpAndSettle();

      expect(lookups, 1);
      expect(created, [
        old,
        fresh,
      ], reason: 'Đúng hai lượt: bản hết hạn, rồi bản ký mới.');
    });

    testWidgets('lần hai cũng hỏng → trạng thái lỗi sẵn có, không màn mới', (
      tester,
    ) async {
      final resolver = MediaUrlResolver(
        onReload: () async {},
        lookup: (_) => fresh,
      );

      await tester.pumpWidget(host(resolver));
      await tester.pumpAndSettle();

      // Không có lượt thứ ba.
      expect(created, hasLength(2));
      expect(find.byTooltip('Tải lại video'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('không có scope (xem trước) → không ném, chỉ hiện lỗi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageVideoAttachments(
              attachments: [MessageAttachment(url: old, type: 'video/mp4')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(created, [old]);
    });
  });
}
