import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import 'outbound_capabilities.dart';

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
    this.isPinned = false,
    this.isMuted = false,
    this.blockedAt,
    this.outboundCapabilities,
  });

  /// Bản sao với các trường đổi (trường không truyền giữ nguyên). Mọi trường
  /// của constructor PHẢI có mặt ở đây — `conversation_test.dart` giữ điều đó.
  /// Trường nullable không xoá được về null bằng copyWith — kể cả
  /// [blockedAt]: `copyWith(blockedAt: null)` GIỮ thời điểm chặn. Bỏ chặn
  /// không cần cờ: `InboxApi.setBlocked(id, false)` trả hội thoại đầy đủ từ
  /// server (`blocked_at` null hoặc vắng), dùng nguyên bản đó.
  Conversation copyWith({
    String? id,
    Channel? channel,
    ConversationStatus? status,
    String? customerId,
    String? customerName,
    String? customerAvatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unread,
    bool? urgent,
    String? assigneeId,
    String? assigneeName,
    List<String>? tags,
    String? connectionId,
    String? sourceName,
    bool? isGroup,
    String? groupName,
    List<GroupMember>? groupMembers,
    bool? isPinned,
    bool? isMuted,
    DateTime? blockedAt,
    OutboundCapabilities? outboundCapabilities,
  }) => Conversation(
    id: id ?? this.id,
    channel: channel ?? this.channel,
    status: status ?? this.status,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    customerAvatar: customerAvatar ?? this.customerAvatar,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unread: unread ?? this.unread,
    urgent: urgent ?? this.urgent,
    assigneeId: assigneeId ?? this.assigneeId,
    assigneeName: assigneeName ?? this.assigneeName,
    tags: tags ?? this.tags,
    connectionId: connectionId ?? this.connectionId,
    sourceName: sourceName ?? this.sourceName,
    isGroup: isGroup ?? this.isGroup,
    groupName: groupName ?? this.groupName,
    groupMembers: groupMembers ?? this.groupMembers,
    isPinned: isPinned ?? this.isPinned,
    isMuted: isMuted ?? this.isMuted,
    blockedAt: blockedAt ?? this.blockedAt,
    outboundCapabilities: outboundCapabilities ?? this.outboundCapabilities,
  );

  /// Bỏ người phụ trách. `copyWith(assigneeId: null)` GIỮ giá trị cũ (null =
  /// "không đổi") — muốn xoá thì gọi hàm này, đừng thêm cờ vào copyWith.
  Conversation unassigned() => Conversation(
    id: id,
    channel: channel,
    status: status,
    customerId: customerId,
    customerName: customerName,
    customerAvatar: customerAvatar,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unread: unread,
    urgent: urgent,
    assigneeId: null,
    assigneeName: null,
    tags: tags,
    connectionId: connectionId,
    sourceName: sourceName,
    isGroup: isGroup,
    groupName: groupName,
    groupMembers: groupMembers,
    isPinned: isPinned,
    isMuted: isMuted,
    blockedAt: blockedAt,
    outboundCapabilities: outboundCapabilities,
  );

  /// The same thread with its unread counter cleared.
  ///
  /// Opening a thread marks it read on the server, but the list held the old
  /// count until the next full refetch — so a rep came back from a conversation
  /// they had just read and it was still bold with a red badge. Nothing on the
  /// screen could tell them what they had and had not read.
  Conversation asRead() => copyWith(unread: 0);

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json.strOr('id', ''),
      channel: Channel.parse(json.str('channel') ?? json.str('platform')),
      status: ConversationStatus.parse(json.str('status')),
      customerId: json.str('customer_id'),
      customerName: json.str('customer_name'),
      customerAvatar: json.str('customer_avatar'),
      lastMessage: json.strOr('last_message', ''),
      // `last_message_at` is the canonical name the API writes and the web
      // reads; `last_time` is a legacy alias written alongside it. Falling all
      // the way through to `updated_at` would sort the list by when a row was
      // last WRITTEN, not when the customer last spoke.
      lastMessageAt:
          DateUtilsX.parse(json['last_message_at']) ??
          DateUtilsX.parse(json['last_time']) ??
          DateUtilsX.parse(json['updated_at']),
      // The API writes `unread_count`; only some payloads carry `unread`. This
      // read only the latter, so EVERY conversation parsed as read — no badge,
      // no bold, no highlight, on a screen whose whole job is showing which
      // threads are waiting. The web mapper already handled both.
      unread: json.intOfAny(const ['unread_count', 'unread']),
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
      // Hộp thư mobile: cờ THEO NGƯỜI XEM do server tính (`InboxDTO::forViewer`).
      // Mảng thô `pinned_by`/`muted_by` không bao giờ ra ngoài — đừng đọc chúng.
      isPinned: json.flag('is_pinned'),
      isMuted: json.flag('is_muted'),
      blockedAt: DateUtilsX.parse(json['blocked_at']),
      outboundCapabilities: OutboundCapabilities.fromJson(
        json['outbound_capabilities'],
      ),
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

  /// Người xem đang ghim hội thoại này (mục "Đã ghim").
  final bool isPinned;

  /// Người xem đã tắt thông báo hội thoại này.
  final bool isMuted;

  /// Đã chặn khách (cờ CHUNG của cả đội, chỉ trong CRM — không chặn trên nền
  /// tảng). Hội thoại đã chặn bị ẩn khỏi danh sách/facet mặc định.
  final DateTime? blockedAt;

  /// Kênh gửi đi được gì; null = API cũ chưa có khoá.
  final OutboundCapabilities? outboundCapabilities;

  bool get isBlocked => blockedAt != null;
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

  /// Tên tài khoản kênh trên dòng nguồn ("Trung Nguyên"). `sourceName` có
  /// dạng "Zalo OA · Trung Nguyên" hoặc chỉ "Trung Nguyên".
  String? get sourceAccount {
    final source = sourceName?.trim();
    if (source == null || source.isEmpty) return null;
    final account = source.contains('·')
        ? source.split('·').last.trim()
        : source;
    return account.isEmpty ? null : account;
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
