import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';

/// Mọi trường của [Conversation], theo thứ tự khai báo.
List<Object?> _fields(Conversation c) => [
  c.id,
  c.channel,
  c.status,
  c.customerId,
  c.customerName,
  c.customerAvatar,
  c.lastMessage,
  c.lastMessageAt,
  c.unread,
  c.urgent,
  c.assigneeId,
  c.assigneeName,
  c.tags,
  c.connectionId,
  c.sourceName,
  c.isGroup,
  c.groupName,
  c.groupMembers,
];

void main() {
  final full = Conversation(
    id: 'c-9',
    channel: Channel.facebookPersonal,
    status: ConversationStatus.pending,
    customerId: 'cus-1',
    customerName: 'Lan Anh',
    customerAvatar: 'https://x.test/a.png',
    lastMessage: 'Còn hàng không ạ?',
    lastMessageAt: DateTime.utc(2026, 10, 9, 8, 30),
    unread: 7,
    urgent: true,
    assigneeId: 'u-2',
    assigneeName: 'Hoàng',
    tags: const ['vip', 'đặt lịch'],
    connectionId: 'conn-3',
    sourceName: 'Facebook cá nhân · Kiệt',
    isGroup: true,
    groupName: 'Nhóm khách',
    groupMembers: const [GroupMember(id: 'm1', name: 'A', avatar: 'av')],
  );

  test(
    'danh sách trường trong test khớp số trường khai báo của Conversation',
    () {
      final src = File(
        'lib/modules/inbox/domain/conversation.dart',
      ).readAsStringSync();
      final body = src.substring(src.indexOf('class Conversation {'));
      final declared = RegExp(
        r'^  final [^\n]*;',
        multiLine: true,
      ).allMatches(body).length;
      expect(
        _fields(full).length,
        declared,
        reason:
            'Thêm trường vào Conversation thì phải thêm vào copyWith và _fields.',
      );
    },
  );

  // Lưới thứ hai, không phụ thuộc _fields: constructor, copyWith và
  // unassigned() chép tay từng trường, nên đếm thẳng trong mã nguồn — thêm
  // trường mà quên một chỗ thì đỏ ở đây.
  test('constructor, copyWith, unassigned đều mang đủ mọi trường', () {
    final src = File(
      'lib/modules/inbox/domain/conversation.dart',
    ).readAsStringSync();
    final body = src.substring(src.indexOf('class Conversation {'));
    final declared = RegExp(
      r'^  final [^\n]*;',
      multiLine: true,
    ).allMatches(body).length;

    String section(String start, String end) {
      final from = body.indexOf(start);
      expect(from, isNot(-1), reason: 'không thấy "$start"');
      return body.substring(from, body.indexOf(end, from));
    }

    final ctor = section('const Conversation({', '});');
    expect(
      RegExp(r'this\.\w+').allMatches(ctor).length,
      declared,
      reason: 'constructor',
    );
    final copyParams = section('Conversation copyWith({', '})');
    expect(
      RegExp(r'\?\s+\w+,').allMatches(copyParams).length,
      declared,
      reason: 'tham số copyWith',
    );
    final copyBody = section('}) => Conversation(', ');');
    expect(
      RegExp(r'^\s+\w+:', multiLine: true).allMatches(copyBody).length,
      declared,
      reason: 'thân copyWith',
    );
    final unassigned = section('Conversation unassigned() =>', ');');
    expect(
      RegExp(r'^\s+\w+:', multiLine: true).allMatches(unassigned).length,
      declared,
      reason: 'unassigned()',
    );
  });

  test('mọi trường đều khác giá trị mặc định (để phát hiện rơi trường)', () {
    const bare = Conversation(
      id: '',
      channel: Channel.unknown,
      status: ConversationStatus.open,
    );
    final a = _fields(full);
    final b = _fields(bare);
    for (var i = 0; i < a.length; i++) {
      expect(a[i], isNot(equals(b[i])), reason: 'trường #$i trùng mặc định');
    }
  });

  test('copyWith() không đối số giữ nguyên mọi trường', () {
    expect(_fields(full.copyWith()), _fields(full));
  });

  test('asRead() chỉ xoá unread, giữ mọi trường khác', () {
    final read = full.asRead();
    expect(read.unread, 0);
    final expected = _fields(full)..[8] = 0;
    expect(_fields(read), expected);
  });

  test('copyWith đổi đúng trường được truyền', () {
    final c = full.copyWith(status: ConversationStatus.closed, unread: 1);
    expect(c.status, ConversationStatus.closed);
    expect(c.unread, 1);
    expect(c.customerName, full.customerName);
  });

  test('unassigned() xoá người phụ trách — copyWith không xoá được null', () {
    expect(full.copyWith(assigneeId: null).assigneeId, 'u-2'); // đúng thiết kế
    final u = full.unassigned();
    expect(u.assigneeId, isNull);
    expect(u.assigneeName, isNull);
    // Mọi trường khác giữ nguyên (#10 assigneeId, #11 assigneeName bị xoá).
    final expected = _fields(full)
      ..[10] = null
      ..[11] = null;
    expect(_fields(u), expected);
  });
}
