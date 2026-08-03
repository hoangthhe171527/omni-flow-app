import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

enum ConversationStatus {
  open,
  pending,
  closed;

  static ConversationStatus parse(String? value) => switch (value) {
    'pending' => ConversationStatus.pending,
    'closed' => ConversationStatus.closed,
    _ => ConversationStatus.open,
  };

  String get slug => name;

  String get label => switch (this) {
    ConversationStatus.open => 'Đang mở',
    ConversationStatus.pending => 'Chờ xử lý',
    ConversationStatus.closed => 'Đã đóng',
  };
}

class GroupMember {
  const GroupMember({required this.id, this.name, this.avatar});

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json.strOr('id', ''),
    name: json.str('name'),
    avatar: json.str('avatar'),
  );

  final String id;
  final String? name;
  final String? avatar;
}

/// A thread in the omnichannel inbox.
///
/// The API stores conversations as schema-less Mongo documents, so every field
/// is read defensively — a Zalo group thread and a website-chat thread genuinely
/// carry different keys.
class Conversation {
  const Conversation({
    required this.id,
    required this.channel,
    required this.status,
    this.customerId,
    this.customerName,
    this.customerAvatar,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unread = 0,
    this.urgent = false,
    this.assigneeId,
    this.assigneeName,
    this.tags = const [],
    this.connectionId,
    this.sourceName,
    this.isGroup = false,
    this.groupName,
    this.groupMembers = const [],
  });

  /// The same thread with its unread counter cleared.
  ///
  /// Opening a thread marks it read on the server, but the list held the old
  /// count until the next full refetch — so a rep came back from a conversation
  /// they had just read and it was still bold with a red badge. Nothing on the
  /// screen could tell them what they had and had not read.
  Conversation asRead() => Conversation(
    id: id,
    channel: channel,
    status: status,
    customerId: customerId,
    customerName: customerName,
    customerAvatar: customerAvatar,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unread: 0,
    urgent: urgent,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    tags: tags,
    connectionId: connectionId,
    sourceName: sourceName,
    isGroup: isGroup,
    groupName: groupName,
    groupMembers: groupMembers,
  );

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json.strOr('id', ''),
      channel: Channel.parse(json.str('channel') ?? json.str('platform')),
      status: ConversationStatus.parse(json.str('status')),
      customerId: json.str('customer_id'),
      customerName: json.str('customer_name'),
      customerAvatar: json.str('customer_avatar'),
      lastMessage: json.strOr('last_message', ''),
      lastMessageAt:
          DateUtilsX.parse(json['last_time']) ??
          DateUtilsX.parse(json['updated_at']),
      unread: json.intOr('unread'),
      urgent: json.str('priority') == 'urgent',
      assigneeId: json.str('assignee'),
      assigneeName: json.str('assignee_name'),
      tags: json.strList('tags'),
      connectionId: json.str('connection_id'),
      sourceName: json.str('source_name'),
      isGroup: json.flag('is_group'),
      groupName: json.str('group_name'),
      groupMembers: json
          .mapList('group_members')
          .map(GroupMember.fromJson)
          .toList(),
    );
  }

  final String id;
  final Channel channel;
  final ConversationStatus status;
  final String? customerId;
  final String? customerName;
  final String? customerAvatar;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final bool urgent;
  final String? assigneeId;
  final String? assigneeName;
  final List<String> tags;

  /// Which OA / Page / personal account this thread arrived on.
  final String? connectionId;

  /// Server-rendered source label: "Zalo cá nhân · Kiệt", "OA TNP".
  final String? sourceName;

  final bool isGroup;
  final String? groupName;
  final List<GroupMember> groupMembers;

  bool get isUnassigned => assigneeId == null || assigneeId!.isEmpty;
  bool get isUnread => unread > 0;
  bool get isLinkedToCustomer => customerId != null && customerId!.isNotEmpty;

  String get title {
    if (isGroup) return groupName ?? 'Nhóm chat';
    final name = customerName?.trim();
    return (name == null || name.isEmpty) ? 'Khách chưa có tên' : name;
  }

  /// Account name inside the source label — "Zalo cá nhân · Kiệt" → "Kiệt".
  String? get accountName {
    final source = sourceName;
    if (source == null || !source.contains('·')) return null;
    return source.split('·').last.trim();
  }

  /// How long the customer has been waiting on an unanswered thread. Drives the
  /// SLA warning; null when nothing is pending.
  Duration? get waiting {
    if (unread == 0 || lastMessageAt == null) return null;
    return DateTime.now().difference(lastMessageAt!);
  }

  bool get breachesSla {
    final elapsed = waiting;
    return elapsed != null && elapsed.inMinutes >= slaWarningMinutes;
  }

  /// Vietnamese social commerce runs fast — a customer left 15 minutes on Zalo
  /// has usually already messaged a competitor.
  static const slaWarningMinutes = 15;
}
