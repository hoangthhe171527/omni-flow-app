import '../../../core/utils/client_id.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/media_url.dart';

enum MessageAuthor { customer, agent, note }

/// Outbound delivery state. Reps chase these — a silently failed send is worse
/// than no send, so `failed` always carries a reason.
enum DeliveryStatus { queued, sent, delivered, read, received, failed, none }

class MessageAttachment {
  const MessageAttachment({required this.url, required this.type, this.name});

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        url: resolveMediaUrl(json.strOr('url', '')),
        type: json.strOr('type', 'file'),
        name: json.str('name'),
      );

  /// Kết quả `POST /inbox/media`: giữ `url` NGUYÊN VĂN server trả về.
  ///
  /// URL này đi tiếp vào POST /messages và nền tảng (Zalo/FB) tải ảnh từ chính
  /// nó. Dựng lại qua [resolveMediaUrl] là gửi cho khách một URL khác URL server
  /// đã cấp (APP-I1). Chỗ vẽ ảnh tự resolve khi cần đổi host.
  factory MessageAttachment.fromUpload(Map<String, dynamic> json) =>
      MessageAttachment(
        url: json.strOr('url', ''),
        type: json.strOr('type', 'file'),
        name: json.str('name'),
      );

  final String url;
  final String type;
  final String? name;

  bool get isImage => type.toLowerCase().startsWith('image');
  bool get isVideo => type.toLowerCase().startsWith('video');
  bool get isAudio => type.startsWith('audio');
}

class Message {
  const Message({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.clientId,
    this.status = DeliveryStatus.none,
    this.error,
    this.recalled = false,
    this.pinned = false,
    this.reaction,
    this.agentName,
    this.senderName,
    this.senderAvatar,
    this.replyToMessageId,
    this.replyToText,
    this.replyToAuthorName,
    this.attachments = const [],
    this.teamReactions = const [],
    this.errorCode,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final direction = json.str('direction');
    final from = json.str('from');
    return Message(
      id: json.strOr('id', ''),
      clientId: json.str('client_message_id'),
      author: _author(from, direction),
      text: json.strOr('text', ''),
      sentAt:
          DateUtilsX.parse(json['sent_at']) ??
          DateUtilsX.parse(json['created_at']),
      status: parseStatus(json.str('status')),
      error: json.str('error'),
      errorCode: json.str('error_code'),
      recalled: json.flag('recalled'),
      pinned: json.flag('pinned'),
      reaction: json.str('reaction'),
      agentName: json.str('agent_name'),
      senderName: json.str('sender_name'),
      senderAvatar: json.str('sender_avatar'),
      replyToMessageId:
          json.str('reply_to_message_id') ?? json.str('reply_to_id'),
      replyToText: json.str('reply_to_text') ?? json.str('quoted_text'),
      replyToAuthorName:
          json.str('reply_to_author_name') ?? json.str('quoted_author'),
      attachments: json
          .mapList('attachments')
          .map(MessageAttachment.fromJson)
          .toList(),
      teamReactions: json
          .mapList('team_reactions')
          .map(TeamReaction.fromJson)
          .toList(),
    );
  }

  final String id;

  /// Idempotency key this message was sent under, echoed back by the API.
  ///
  /// Set on every message the app itself sent — including while it is still an
  /// optimistic bubble, where it equals [id]. Null on inbound messages and on
  /// anything sent before this field existed.
  final String? clientId;

  final MessageAuthor author;
  final String text;
  final DateTime? sentAt;
  final DeliveryStatus status;
  final String? error;
  final bool recalled;
  final bool pinned;
  final String? reaction;
  final String? agentName;

  /// Group threads only: which member sent this message.
  final String? senderName;
  final String? senderAvatar;

  /// The message this message is replying to, when the channel/API supports
  /// native quoted replies.
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToAuthorName;

  final List<MessageAttachment> attachments;

  /// Cảm xúc NỘI BỘ của đội (không gửi ra nền tảng). Tách khỏi [reaction] —
  /// cảm xúc của KHÁCH.
  final List<TeamReaction> teamReactions;

  /// Mã máy của lỗi gửi (`channel_send_unsupported`…); null khi không lỗi.
  final String? errorCode;

  /// Tin lỗi vì kênh không có đường gửi đi: gửi lại không bao giờ thành công.
  bool get isChannelUnsupported => errorCode == 'channel_send_unsupported';

  bool get isOutbound => author == MessageAuthor.agent;
  bool get isNote => author == MessageAuthor.note;
  bool get hasAttachments => attachments.isNotEmpty;

  /// Still an optimistic bubble: the server has never answered for it, so [id]
  /// is the locally generated key rather than a server id.
  bool get isPending => clientId != null && clientId == id;

  /// The same message, queued for another attempt.
  ///
  /// Whether the original key is reused is the whole point of this method:
  ///
  ///  * A bubble that never got a server id ([isPending]) has an *unknown*
  ///    outcome — the request may well have been accepted and only its response
  ///    lost. Reusing the key lets the API recognise the retry and hand back the
  ///    message it already queued, instead of delivering a second copy.
  ///  * A bubble the server did answer for is a message the server definitely
  ///    stored and the platform then rejected. Reusing the key there would
  ///    resolve to that same failure forever, leaving a retry button that can
  ///    never succeed — so this starts a genuinely new attempt.
  Message requeued() {
    final key = isPending ? (clientId ?? id) : newClientId();
    return Message(
      id: key,
      clientId: key,
      author: author,
      text: text,
      sentAt: DateTime.now(),
      // Ghi chú không bao giờ hiện trong luồng tin nên không có nút gửi lại.
      status: DeliveryStatus.queued,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToAuthorName: replyToAuthorName,
      attachments: attachments,
    );
  }

  static MessageAuthor _author(String? from, String? direction) {
    if (from == 'note') return MessageAuthor.note;
    if (from == 'agent') return MessageAuthor.agent;
    if (from == 'customer') return MessageAuthor.customer;
    return direction == 'out' ? MessageAuthor.agent : MessageAuthor.customer;
  }

  /// Wire name → [DeliveryStatus]; unknown or null is [DeliveryStatus.none].
  /// Public because realtime receipts (`message.status`) carry the same names.
  static DeliveryStatus parseStatus(String? value) => switch (value) {
    'queued' => DeliveryStatus.queued,
    'sent' => DeliveryStatus.sent,
    'delivered' => DeliveryStatus.delivered,
    'read' => DeliveryStatus.read,
    'received' => DeliveryStatus.received,
    'failed' => DeliveryStatus.failed,
    _ => DeliveryStatus.none,
  };

  /// Optimistic local echo, shown the instant the rep hits send.
  ///
  /// The bubble's [id] *is* its [clientId] until the server answers, so the two
  /// identifiers never have to be kept in sync. Pass [clientId] to reuse the key
  /// of an earlier attempt — that is what makes "Gửi lại" a retry of the same
  /// send rather than a second one the customer would also receive.
  static Message optimistic({
    required String text,
    String? clientId,
    List<MessageAttachment> attachments = const [],
    Message? replyTo,
  }) {
    final key = clientId ?? newClientId();
    return Message(
      id: key,
      clientId: key,
      author: MessageAuthor.agent,
      text: text,
      sentAt: DateTime.now(),
      status: DeliveryStatus.queued,
      replyToMessageId: replyTo?.id,
      replyToText: replyTo?.text,
      replyToAuthorName: replyTo?.senderName,
      attachments: attachments,
    );
  }

  Message copyWith({
    DeliveryStatus? status,
    String? error,
    String? id,
    String? clientId,
    String? replyToMessageId,
    String? replyToText,
    String? replyToAuthorName,
    bool? pinned,
    List<MessageAttachment>? attachments,
    List<TeamReaction>? teamReactions,
    String? errorCode,
  }) {
    return Message(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      author: author,
      text: text,
      sentAt: sentAt,
      status: status ?? this.status,
      error: error ?? this.error,
      recalled: recalled,
      pinned: pinned ?? this.pinned,
      reaction: reaction,
      agentName: agentName,
      senderName: senderName,
      senderAvatar: senderAvatar,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToAuthorName: replyToAuthorName ?? this.replyToAuthorName,
      attachments: attachments ?? this.attachments,
      teamReactions: teamReactions ?? this.teamReactions,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

/// Một cảm xúc nội bộ (`team_reactions[]`): mỗi người tối đa một emoji.
class TeamReaction {
  const TeamReaction({
    required this.userId,
    required this.emoji,
    this.userName,
    this.at,
  });

  factory TeamReaction.fromJson(Map<String, dynamic> json) => TeamReaction(
    userId: json.strOr('user_id', ''),
    userName: json.str('user_name'),
    emoji: json.strOr('emoji', ''),
    at: DateUtilsX.parse(json['at']),
  );

  final String userId;
  final String? userName;
  final String emoji;
  final DateTime? at;
}
