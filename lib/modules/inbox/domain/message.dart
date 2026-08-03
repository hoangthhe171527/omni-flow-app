import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

enum MessageAuthor { customer, agent, note }

/// Outbound delivery state. Reps chase these — a silently failed send is worse
/// than no send, so `failed` always carries a reason.
enum DeliveryStatus { queued, sent, delivered, read, received, failed, none }

class MessageAttachment {
  const MessageAttachment({required this.url, required this.type, this.name});

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        url: json.strOr('url', ''),
        type: json.strOr('type', 'file'),
        name: json.str('name'),
      );

  final String url;
  final String type;
  final String? name;

  bool get isImage => type.startsWith('image');
  bool get isVideo => type.startsWith('video');
  bool get isAudio => type.startsWith('audio');
}

class Message {
  const Message({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.status = DeliveryStatus.none,
    this.error,
    this.recalled = false,
    this.reaction,
    this.agentName,
    this.senderName,
    this.senderAvatar,
    this.attachments = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final direction = json.str('direction');
    final from = json.str('from');
    return Message(
      id: json.strOr('id', ''),
      author: _author(from, direction),
      text: json.strOr('text', ''),
      sentAt: DateUtilsX.parse(json['sent_at']) ??
          DateUtilsX.parse(json['created_at']),
      status: _status(json.str('status')),
      error: json.str('error'),
      recalled: json.flag('recalled'),
      reaction: json.str('reaction'),
      agentName: json.str('agent_name'),
      senderName: json.str('sender_name'),
      senderAvatar: json.str('sender_avatar'),
      attachments:
          json.mapList('attachments').map(MessageAttachment.fromJson).toList(),
    );
  }

  final String id;
  final MessageAuthor author;
  final String text;
  final DateTime? sentAt;
  final DeliveryStatus status;
  final String? error;
  final bool recalled;
  final String? reaction;
  final String? agentName;

  /// Group threads only: which member sent this message.
  final String? senderName;
  final String? senderAvatar;

  final List<MessageAttachment> attachments;

  bool get isOutbound => author == MessageAuthor.agent;
  bool get isNote => author == MessageAuthor.note;
  bool get hasAttachments => attachments.isNotEmpty;

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
  static Message optimistic({
    required String localId,
    required String text,
    List<MessageAttachment> attachments = const [],
    bool asNote = false,
  }) {
    return Message(
      id: localId,
      author: asNote ? MessageAuthor.note : MessageAuthor.agent,
      text: text,
      sentAt: DateTime.now(),
      status: asNote ? DeliveryStatus.none : DeliveryStatus.queued,
      attachments: attachments,
    );
  }

  Message copyWith({DeliveryStatus? status, String? error, String? id}) {
    return Message(
      id: id ?? this.id,
      author: author,
      text: text,
      sentAt: sentAt,
      status: status ?? this.status,
      error: error ?? this.error,
      recalled: recalled,
      reaction: reaction,
      agentName: agentName,
      senderName: senderName,
      senderAvatar: senderAvatar,
      attachments: attachments,
    );
  }
}
