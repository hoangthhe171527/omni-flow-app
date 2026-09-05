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
      status: _status(json.str('status')),
      error: json.str('error'),
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
      status: isNote ? DeliveryStatus.none : DeliveryStatus.queued,
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

  static DeliveryStatus _status(String? value) => switch (value) {
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
    bool asNote = false,
    Message? replyTo,
  }) {
    final key = clientId ?? newClientId();
    return Message(
      id: key,
      clientId: key,
      author: asNote ? MessageAuthor.note : MessageAuthor.agent,
      text: text,
      sentAt: DateTime.now(),
      status: asNote ? DeliveryStatus.none : DeliveryStatus.queued,
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
      attachments: attachments,
    );
  }
}
