import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';

/// Fix vòng 2 (RI8): vị từ phía client phải trùng tham số gửi server
/// (`MongoInboxRepository::applyFilters`).
void main() {
  Conversation conv({
    String status = 'open',
    String? assignee,
    int unread = 0,
    String? priority,
    List<String> tags = const [],
    String? blockedAt,
  }) => Conversation.fromJson({
    'id': 'c1',
    'channel': 'zalo',
    'status': status,
    'assignee': ?assignee,
    'unread_count': unread,
    'priority': ?priority,
    'tags': tags,
    'blocked_at': ?blockedAt,
  });

  group('Đã chặn (Hộp thư mobile)', () {
    const at = '2026-10-10T03:00:00.000Z';

    test('toQuery chỉ gửi blocked=1, không kèm status', () {
      final query = const InboxFilter(
        quick: InboxQuickFilter.blocked,
      ).toQuery(currentUserId: 'u1');
      expect(query, {'blocked': '1'});
    });

    test('nhãn "Đã chặn", facet không có số', () {
      expect(InboxQuickFilter.blocked.label, 'Đã chặn');
      expect(const InboxFacets(total: 9).countFor(InboxQuickFilter.blocked), 0);
    });

    test('hội thoại đã chặn không thuộc tab nào trừ "Đã chặn"', () {
      final blocked = conv(blockedAt: at);
      final blockedClosed = conv(status: 'closed', blockedAt: at);
      for (final q in InboxQuickFilter.values) {
        if (q == InboxQuickFilter.blocked) continue;
        for (final c in [blocked, blockedClosed]) {
          expect(
            InboxFilter(quick: q).matches(c, currentUserId: 'u1'),
            isFalse,
            reason: '$q ${c.status}',
          );
        }
      }
      for (final c in [blocked, blockedClosed]) {
        expect(
          const InboxFilter(
            quick: InboxQuickFilter.blocked,
          ).matches(c, currentUserId: 'u1'),
          isTrue,
        );
      }
    });

    test('tab "Đã chặn" loại hội thoại chưa chặn; kênh vẫn áp', () {
      expect(
        const InboxFilter(
          quick: InboxQuickFilter.blocked,
        ).matches(conv(), currentUserId: 'u1'),
        isFalse,
      );
      expect(
        const InboxFilter(
          quick: InboxQuickFilter.blocked,
          channel: Channel.facebook,
        ).matches(conv(blockedAt: at), currentUserId: 'u1'),
        isFalse,
      );
    });
  });

  test(
    '"Chưa gán" gửi sentinel server hiểu (`unassigned`, không phải `none`)',
    () {
      final query = const InboxFilter(
        quick: InboxQuickFilter.unassigned,
      ).toQuery(currentUserId: 'u1');

      expect(query['assignee'], 'unassigned');
      expect(query['status'], 'open');
    },
  );

  test('matches theo từng tab nhanh', () {
    bool? m(InboxQuickFilter q, Conversation c) =>
        InboxFilter(quick: q).matches(c, currentUserId: 'u1');

    expect(m(InboxQuickFilter.all, conv()), isTrue);
    expect(m(InboxQuickFilter.all, conv(status: 'closed')), isFalse);
    expect(m(InboxQuickFilter.all, conv(status: 'pending')), isFalse);
    expect(m(InboxQuickFilter.unassigned, conv()), isTrue);
    expect(m(InboxQuickFilter.unassigned, conv(assignee: 'u9')), isFalse);
    expect(m(InboxQuickFilter.mine, conv(assignee: 'u1')), isTrue);
    expect(m(InboxQuickFilter.mine, conv(assignee: 'u9')), isFalse);
    expect(m(InboxQuickFilter.unread, conv(unread: 2)), isTrue);
    expect(m(InboxQuickFilter.unread, conv()), isFalse);
    expect(m(InboxQuickFilter.urgent, conv(priority: 'urgent')), isTrue);
    expect(m(InboxQuickFilter.closed, conv(status: 'closed')), isTrue);
  });

  test('kênh, nhãn; tìm kiếm thì không tự xét (null)', () {
    expect(
      const InboxFilter(
        channel: Channel.facebook,
      ).matches(conv(), currentUserId: 'u1'),
      isFalse,
    );
    expect(
      const InboxFilter(
        label: 'VIP',
      ).matches(conv(tags: ['VIP']), currentUserId: 'u1'),
      isTrue,
    );
    expect(
      const InboxFilter(label: 'VIP').matches(conv(), currentUserId: 'u1'),
      isFalse,
    );
    expect(
      const InboxFilter(search: 'an').matches(conv(), currentUserId: 'u1'),
      isNull,
    );
    expect(
      const InboxFilter(
        quick: InboxQuickFilter.mine,
      ).matches(conv(assignee: 'u1'), currentUserId: null),
      isNull,
    );
  });
}
