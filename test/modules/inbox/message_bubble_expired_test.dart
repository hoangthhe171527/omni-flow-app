import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_images.dart';

/// Link media Hộp thư có chữ ký hết hạn sau 12 giờ (MS-I24, API Đợt 6b B5).
/// Màn chat mở lâu hơn thế: ảnh trả 403 và cứ thế vỡ. Ảnh lỗi phải báo lên để
/// màn tải lại tin (lấy URL ký mới) — đúng một lần, không vòng lặp.
void main() {
  group('ảnh lỗi tải báo MediaReloadScope', () {
    Widget bubble(List<MessageAttachment> attachments, VoidCallback onError) =>
        MaterialApp(
          home: Scaffold(
            body: MediaReloadScope(
              onLoadError: onError,
              child: MessageBubble(
                message: Message(
                  id: 'm1',
                  author: MessageAuthor.customer,
                  text: '',
                  sentAt: null,
                  attachments: attachments,
                ),
              ),
            ),
          ),
        );

    // Môi trường test không tải ảnh thật (cache manager cần plugin), nên gọi
    // thẳng errorListener của CachedNetworkImage — cách test avatar đã làm.
    void failAll(WidgetTester tester) {
      for (final image in tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      )) {
        image.errorListener!(Exception('HTTP 403'));
      }
    }

    testWidgets('ảnh lỗi → báo đúng một lần, vẽ lại / lỗi lặp không báo thêm', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        bubble(const [
          MessageAttachment(
            url:
                'https://api.khac.vn/api/v1/inbox/media/t-1/a.jpg?expires=1&signature=ab',
            type: 'image/jpeg',
          ),
        ], () => calls++),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      // Chữ ký đi nguyên vào URL tải.
      expect(image.imageUrl, contains('expires=1&signature=ab'));
      expect(image.errorListener, isNotNull);

      failAll(tester);
      expect(calls, 1);

      await tester.pump();
      failAll(tester);
      expect(calls, 1, reason: 'Cùng URL hỏng lại không báo lần nữa.');
    });

    testWidgets('không có scope (xem trước) → lỗi ảnh không ném', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: Message(
                id: 'm1',
                author: MessageAuthor.customer,
                text: '',
                sentAt: null,
                attachments: const [
                  MessageAttachment(
                    url: 'https://cdn.example/a.jpg',
                    type: 'image/jpeg',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      failAll(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('khoá ảnh bỏ chữ ký (link ký lại mỗi giờ)', () {
    String signed(String sig) =>
        'https://api.khac.vn/api/v1/inbox/media/t-1/a.jpg?expires=$sig&signature=s$sig';

    Widget host(String url, {VoidCallback? onError, VoidCallback? onRetry}) =>
        MaterialApp(
          home: Scaffold(
            body: MediaReloadScope(
              onLoadError: onError ?? () {},
              onUserRetry: onRetry,
              child: MessageBubble(
                message: Message(
                  id: 'm1',
                  author: MessageAuthor.customer,
                  text: '',
                  sentAt: null,
                  attachments: [
                    MessageAttachment(url: url, type: 'image/jpeg'),
                  ],
                ),
              ),
            ),
          ),
        );

    CachedNetworkImage imageOf(WidgetTester tester) =>
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

    testWidgets('cacheKey và key widget không chứa expires/signature', (
      tester,
    ) async {
      await tester.pumpWidget(host(signed('1')));
      final image = imageOf(tester);
      expect(image.imageUrl, contains('signature=s1'));
      expect(image.cacheKey, isNotNull);
      expect(image.cacheKey, isNot(contains('signature')));
      expect(image.cacheKey, isNot(contains('expires')));
      expect(image.cacheKey, endsWith('/api/v1/inbox/media/t-1/a.jpg'));
    });

    testWidgets(
      'chữ ký đổi khi ảnh đang tốt → giữ nguyên phần tử ảnh (không nháy)',
      (tester) async {
        await tester.pumpWidget(host(signed('1')));
        final before = tester.element(find.byType(CachedNetworkImage));
        final keyBefore = imageOf(tester).key;

        await tester.pumpWidget(host(signed('2')));
        expect(imageOf(tester).imageUrl, contains('signature=s2'));
        expect(imageOf(tester).key, keyBefore);
        expect(tester.element(find.byType(CachedNetworkImage)), same(before));
      },
    );

    testWidgets('ảnh đã hỏng rồi nhận URL ký mới → dựng lại để tải URL mới', (
      tester,
    ) async {
      await tester.pumpWidget(host(signed('1')));
      final keyBefore = imageOf(tester).key;
      imageOf(tester).errorListener!(Exception('HTTP 403'));

      await tester.pumpWidget(host(signed('2')));
      expect(imageOf(tester).key, isNot(keyBefore));
    });

    testWidgets('nút "Tải lại ảnh" nhờ màn chat lấy URL ký mới', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(host(signed('1'), onRetry: () => retries++));
      final finder = find.byType(CachedNetworkImage);
      final image = imageOf(tester);
      final box =
          image.errorWidget!(tester.element(finder), image.imageUrl, Object())
              as ColoredBox;
      final button = (box.child! as Center).child! as IconButton;
      button.onPressed!();
      expect(retries, 1);
    });
  });

  group('ThreadController.reloadMedia', () {
    test(
      'lấy lại cả cửa sổ đang giữ (kể cả trang cũ) với URL mới, giữ con trỏ',
      () async {
        final api = _PagedApi();
        final container = ProviderContainer(
          overrides: [inboxApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        final sub = container.listen(threadProvider('c1'), (_, _) {});
        addTearDown(sub.close);

        await container.read(threadProvider('c1').future);
        await container.read(threadProvider('c1').notifier).loadOlder();
        var state = container.read(threadProvider('c1')).requireValue;
        expect(state.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
        expect(state.messages.first.attachments.single.url, contains('sig=v1'));

        api.signature = 'v2';
        api.calls.clear();
        await container.read(threadProvider('c1').notifier).reloadMedia();

        state = container.read(threadProvider('c1')).requireValue;
        expect(state.messages.map((m) => m.id), ['m1', 'm2', 'm3', 'm4']);
        expect(
          state.messages.every(
            (m) => m.attachments.single.url.contains('sig=v2'),
          ),
          isTrue,
          reason: 'Ảnh ở trang cũ cũng phải có chữ ký mới.',
        );
        // Đi từ trang mới nhất lùi tới trang chứa tin cũ nhất đang giữ.
        expect(api.calls, [null, 'cur-2']);
        expect(state.hasMore, isFalse);
      },
    );
  });
}

/// Hai trang, mỗi trang hai tin có ảnh; chữ ký đổi theo [signature].
class _PagedApi extends InboxApi {
  _PagedApi() : super(ApiClient(Dio()));

  String signature = 'v1';
  final calls = <String?>[];

  Message _msg(String id, int minute) => Message(
    id: id,
    author: MessageAuthor.customer,
    text: '',
    sentAt: DateTime.utc(2026, 10, 4, 8, minute),
    attachments: [
      MessageAttachment(
        url: '${AppConfig.apiBaseUrl}/inbox/media/t-1/$id.jpg?sig=$signature',
        type: 'image/jpeg',
      ),
    ],
  );

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    calls.add(before);
    if (before == null) {
      // Mới nhất trước, như API.
      return MessagePage(
        messages: [_msg('m4', 4), _msg('m3', 3)],
        cursor: const CursorPage(
          perPage: 2,
          hasMore: true,
          nextBefore: 'cur-2',
        ),
      );
    }
    return MessagePage(
      messages: [_msg('m2', 2), _msg('m1', 1)],
      cursor: const CursorPage.empty(),
    );
  }
}
