import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/demo/demo_app.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/demo/demo_seed.dart';
import 'package:omni_app/modules/channels/data/channels_api.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';

/// Máy chủ demo của Hộp thư / Kênh / Thông báo: mọi đường các màn gọi phải
/// trả JSON mà API class THẬT của app đọc được, và thao tác ghi phải hiện lại ở
/// lượt đọc sau.
void main() {
  late InboxApi inbox;
  late ChannelsApi channels;
  late NotificationsApi notifications;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(
        buildDemoRoutes(),
        latency: Duration.zero,
      );
    final client = ApiClient(dio);
    inbox = InboxApi(client);
    channels = ChannelsApi(client);
    notifications = NotificationsApi(client);
  });

  Map<String, dynamic> openQuery([InboxQuickFilter q = InboxQuickFilter.all]) =>
      InboxFilter(quick: q).toQuery(currentUserId: demoMeId);

  group('Hộp thư — đọc', () {
    test(
      'danh sách mở có đủ kênh, chưa đọc, chưa gán, ghim tách riêng',
      () async {
        final page = await inbox.list(query: openQuery(), pinned: false);
        expect(page.items.length, greaterThanOrEqualTo(9));
        expect(page.hasMore, isFalse);
        final items = page.items;
        expect(items.every((c) => c.status == ConversationStatus.open), isTrue);
        expect(items.any((c) => c.isPinned), isFalse);
        expect(items.any((c) => c.isBlocked), isFalse);
        expect(
          items.map((c) => c.channel).toSet(),
          containsAll([Channel.facebook, Channel.zalo, Channel.zaloPersonal]),
        );
        expect(items.any((c) => c.unread > 0), isTrue);
        expect(items.any((c) => c.isUnassigned), isTrue);
        expect(
          items.any((c) => c.isGroup && c.groupMembers.isNotEmpty),
          isTrue,
        );
        expect(
          items.every((c) => c.outboundCapabilities?.canSendText == true),
          isTrue,
        );
        expect(items.first.lastMessageAt, isNotNull);
        // Mới nhất lên đầu.
        for (var i = 1; i < items.length; i++) {
          expect(
            items[i - 1].lastMessageAt!.isBefore(items[i].lastMessageAt!),
            isFalse,
          );
        }

        final pinned = await inbox.list(query: openQuery(), pinned: true);
        expect(pinned.items, isNotEmpty);
        expect(pinned.items.every((c) => c.isPinned), isTrue);
      },
    );

    test(
      'lọc nhanh: chưa đọc, của tôi, chưa gán, khẩn, đã đóng, đã chặn',
      () async {
        for (final q in InboxQuickFilter.values) {
          final page = await inbox.list(query: openQuery(q));
          expect(page.items, isNotEmpty, reason: q.name);
          for (final c in page.items) {
            expect(
              InboxFilter(quick: q).matches(c, currentUserId: demoMeId),
              isTrue,
              reason: '${q.name}: ${c.title}',
            );
          }
        }
      },
    );

    test('tìm kiếm không dấu và phân trang theo con trỏ', () async {
      final found = await inbox.list(
        query: const InboxFilter(search: 'sofa').toQuery(currentUserId: null),
      );
      expect(found.items.single.customerName, 'Nguyễn Thị Hồng Nhung');
      final folded = await inbox.list(
        query: const InboxFilter(
          search: 'tu lanh',
        ).toQuery(currentUserId: null),
      );
      expect(
        folded.items.map((c) => c.customerName),
        contains('Trần Văn Hùng'),
      );

      final first = await inbox.list(query: openQuery(), perPage: 4);
      expect(first.items.length, 4);
      expect(first.hasMore, isTrue);
      final second = await inbox.list(
        query: openQuery(),
        perPage: 4,
        before: first.cursor.nextBefore,
      );
      expect(second.items, isNotEmpty);
      expect(
        second.items
            .map((c) => c.id)
            .toSet()
            .intersection(first.items.map((c) => c.id).toSet()),
        isEmpty,
      );
    });

    test('facets, nhãn, mẫu trả lời, changes', () async {
      final facets = await inbox.facets(openQuery());
      expect(facets.total, greaterThan(0));
      expect(facets.unread, greaterThan(0));
      expect(facets.unassigned, greaterThan(0));
      expect(facets.closed, greaterThan(0));
      expect(
        facets.countFor(InboxQuickFilter.mine, currentUserId: demoMeId),
        greaterThan(0),
      );
      expect(facets.channels.keys, contains('facebook'));

      expect(await inbox.labels(), containsAll(['Khách mới', 'Bảo hành']));

      final replies = await inbox.quickReplies();
      expect(replies, isNotNull);
      expect(replies!.length, greaterThanOrEqualTo(3));

      final changes = await inbox.changes(null);
      expect(changes.cursor, isNotEmpty);
      expect(changes.count, 0);
    });

    test('chi tiết, tin nhắn theo con trỏ, tìm tin, assets, context', () async {
      final list = await inbox.list(query: openQuery());
      for (final c in list.items) {
        final page = await inbox.messages(c.id);
        expect(page.messages.length, greaterThanOrEqualTo(8), reason: c.title);
        expect(page.messages.any((m) => m.isOutbound), isTrue, reason: c.title);
        expect(page.messages.every((m) => m.sentAt != null), isTrue);
        // Mới nhất trước.
        expect(page.messages.first.text, c.lastMessage);
      }

      final id = list.items.first.id;
      final detail = await inbox.get(id);
      expect(detail.id, id);

      final firstPage = await inbox.messages(id, perPage: 3);
      expect(firstPage.messages.length, 3);
      expect(firstPage.cursor.hasMore, isTrue);
      final older = await inbox.messages(
        id,
        perPage: 3,
        before: firstPage.cursor.nextBefore,
      );
      expect(older.messages, isNotEmpty);
      expect(
        older.messages.first.sentAt!.isAfter(firstPage.messages.last.sentAt!),
        isFalse,
      );

      final nhung = (await inbox.list(
        query: const InboxFilter(search: 'Nhung').toQuery(currentUserId: null),
      )).items.single;
      final hits = await inbox.searchMessages(nhung.id, 'mien phi');
      expect(hits, isNotEmpty);

      final assets = await inbox.assets(id);
      expect(assets.media, isEmpty);
      final ctx = await inbox.context(id);
      expect(ctx.timeline, isNotEmpty);
    });

    test('hội thoại không có trả lỗi', () async {
      await expectLater(inbox.get('khong-co'), throwsA(isA<AppException>()));
    });
  });

  group('Hộp thư — ghi', () {
    test(
      'gửi tin: hiện trong luồng, đẩy lên đầu danh sách, chống trùng',
      () async {
        final before = await inbox.list(query: openQuery(), pinned: false);
        final target = before.items.last;

        final sent = await inbox.send(
          target.id,
          text: 'Dạ em gửi anh/chị báo giá ạ.',
          clientMessageId: 'khoa-1',
        );
        expect(sent.isOutbound, isTrue);
        expect(sent.clientId, 'khoa-1');

        final again = await inbox.send(
          target.id,
          text: 'Dạ em gửi anh/chị báo giá ạ.',
          clientMessageId: 'khoa-1',
        );
        expect(again.id, sent.id);

        final thread = await inbox.messages(target.id);
        expect(thread.messages.first.id, sent.id);
        expect(thread.messages.where((m) => m.id == sent.id).length, 1);

        final after = await inbox.list(query: openQuery(), pinned: false);
        expect(after.items.first.id, target.id);
        expect(after.items.first.lastMessage, 'Dạ em gửi anh/chị báo giá ạ.');
      },
    );

    test(
      'đọc / chưa đọc, giao người, nhãn, ghim, tắt báo, chặn, đóng',
      () async {
        final unread = (await inbox.list(
          query: openQuery(InboxQuickFilter.unread),
        )).items.first;
        await inbox.markRead(unread.id);
        expect((await inbox.get(unread.id)).unread, 0);
        expect(await inbox.markUnread(unread.id), 1);
        expect((await inbox.get(unread.id)).unread, 1);

        final assigned = await inbox.assign(unread.id, demoPeople[3].id);
        expect(assigned.assigneeName, demoPeople[3].name);
        expect((await inbox.assign(unread.id, null)).isUnassigned, isTrue);

        expect(await inbox.setLabels([unread.id], ['VIP']), 1);
        expect((await inbox.get(unread.id)).tags, contains('VIP'));
        expect(await inbox.labels(), contains('VIP'));

        expect(await inbox.setPinned(unread.id, true), isTrue);
        expect((await inbox.get(unread.id)).isPinned, isTrue);
        expect(await inbox.setMuted(unread.id, true), isTrue);
        expect((await inbox.get(unread.id)).isMuted, isTrue);

        final blocked = await inbox.setBlocked(unread.id, true);
        expect(blocked.isBlocked, isTrue);
        final hidden = await inbox.list(query: openQuery());
        expect(hidden.items.any((c) => c.id == unread.id), isFalse);
        expect((await inbox.setBlocked(unread.id, false)).isBlocked, isFalse);

        final closed = await inbox.setStatus(
          unread.id,
          ConversationStatus.closed,
        );
        expect(closed.status, ConversationStatus.closed);
        final closedList = await inbox.list(
          query: openQuery(InboxQuickFilter.closed),
        );
        expect(closedList.items.any((c) => c.id == unread.id), isTrue);
      },
    );

    test('ghim tin, cảm xúc nội bộ, gửi lại tin lỗi, tạo khách hàng', () async {
      final linh = (await inbox.list(
        query: const InboxFilter(
          search: 'Khánh Linh',
        ).toQuery(currentUserId: null),
      )).items.single;
      final thread = await inbox.messages(linh.id);
      final failed = thread.messages.firstWhere(
        (m) => m.status == DeliveryStatus.failed,
      );
      expect(failed.error, isNotNull);
      final resent = await inbox.resend(linh.id, failed.id);
      expect(resent.status, DeliveryStatus.sent);

      final msg = thread.messages.last;
      expect(await inbox.togglePin(linh.id, msg.id), isTrue);
      expect(await inbox.togglePin(linh.id, msg.id), isFalse);

      final reactions = await inbox.toggleTeamReaction(linh.id, msg.id, '👍');
      expect(reactions.single.userId, demoMeId);
      expect(await inbox.toggleTeamReaction(linh.id, msg.id, '👍'), isEmpty);

      final converted = await inbox.convert(linh.id);
      expect(converted.created, isTrue);
      expect((await inbox.get(linh.id)).isLinkedToCustomer, isTrue);
    });
  });

  group('Kênh', () {
    test('liệt kê kết nối và ngắt kết nối', () async {
      final list = await channels.list();
      expect(list.length, greaterThanOrEqualTo(3));
      expect(list.any((c) => c.status == ChannelStatus.connected), isTrue);
      expect(list.every((c) => c.label.isNotEmpty), isTrue);
      expect(list.any((c) => c.today > 0), isTrue);

      await channels.disconnect(list.last.id);
      expect((await channels.list()).length, list.length - 1);
    });

    test('OAuth / ghép nối báo rõ là bản demo', () async {
      await expectLater(
        channels.oauthUrl(Channel.facebook),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        channels.pairStart(Channel.zaloPersonal),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Thông báo', () {
    test('danh sách, chưa đọc, đánh dấu đã đọc', () async {
      final page = await notifications.list();
      expect(page.items.length, greaterThanOrEqualTo(8));
      expect(
        page.items.any((n) => n.kind == NotificationKind.inboxMessage),
        isTrue,
      );
      expect(page.items.any((n) => n.kind.isTask), isTrue);
      final inboxNote = page.items.firstWhere(
        (n) => n.kind == NotificationKind.inboxMessage,
      );
      expect(inboxNote.conversationId, isNotNull);
      expect(await inbox.get(inboxNote.conversationId!), isA<Conversation>());

      final unread = await notifications.unreadCount();
      expect(unread, greaterThan(0));
      final onlyUnread = await notifications.list(unreadOnly: true);
      expect(onlyUnread.items.length, unread);
      expect(onlyUnread.items.every((n) => n.isUnread), isTrue);

      await notifications.markRead(onlyUnread.items.first.id);
      expect(await notifications.unreadCount(), unread - 1);
      await notifications.markAllRead();
      expect(await notifications.unreadCount(), 0);
    });
  });
}
