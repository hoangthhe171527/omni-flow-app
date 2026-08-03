import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';

/// Coming back from a thread you just read.
///
/// Opening a thread marks it read on the SERVER, but the list kept its old
/// unread count until the next full refetch — so a rep returned to the inbox and
/// the conversation they had just finished was still bold with a red badge.
/// Nothing on the screen could tell them what they had and had not read, which
/// is the one question the list exists to answer.
void main() {
  Conversation subject({int unread = 3}) => Conversation(
    id: 'c1',
    channel: Channel.zalo,
    status: ConversationStatus.open,
    customerName: 'Thuy Pham',
    lastMessage: 'Shop còn Kurtzman p215 không ạ',
    unread: unread,
    urgent: true,
    assigneeId: 'u1',
    assigneeName: 'Kiệt',
    tags: const ['vip'],
    isGroup: false,
  );

  test('asRead clears the unread counter', () {
    expect(subject().isUnread, isTrue);
    expect(subject().asRead().unread, 0);
    expect(subject().asRead().isUnread, isFalse);
  });

  test('asRead changes NOTHING else about the thread', () {
    final before = subject();
    final after = before.asRead();

    // A read thread is the same thread: losing its assignee, urgency or tags on
    // the way back from a conversation would be a far worse bug than the badge.
    expect(after.id, before.id);
    expect(after.channel, before.channel);
    expect(after.status, before.status);
    expect(after.customerName, before.customerName);
    expect(after.lastMessage, before.lastMessage);
    expect(after.urgent, before.urgent);
    expect(after.assigneeId, before.assigneeId);
    expect(after.assigneeName, before.assigneeName);
    expect(after.tags, before.tags);
    expect(after.isGroup, before.isGroup);
  });

  test('an already-read thread survives being marked read again', () {
    expect(subject(unread: 0).asRead().unread, 0);
  });
}
