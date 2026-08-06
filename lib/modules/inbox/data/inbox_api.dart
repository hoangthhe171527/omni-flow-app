import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../domain/conversation.dart';
import '../domain/inbox_filter.dart';
import '../domain/message.dart';

/// Related records shown beside a thread — the reason a rep can answer "how much
/// did they quote you?" without leaving the chat.
class ConversationContext {
  const ConversationContext({
    this.opportunities = const [],
    this.timeline = const [],
  });

  final List<ContextOpportunity> opportunities;
  final List<TimelineEntry> timeline;
}

class ContextOpportunity {
  const ContextOpportunity({
    required this.id,
    required this.title,
    this.budget,
    this.stage,
    this.status,
  });

  factory ContextOpportunity.fromJson(Map<String, dynamic> json) =>
      ContextOpportunity(
        id: json.strOr('id', ''),
        title: json.strOr('title', 'Cơ hội'),
        budget: json.dbl('budget'),
        stage: json.str('stage'),
        status: json.str('status'),
      );

  final String id;
  final String title;
  final double? budget;
  final String? stage;
  final String? status;
}

class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.type,
    required this.text,
    this.at,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    kind: json.strOr('kind', 'note'),
    type: json.strOr('type', ''),
    text: json.strOr('text', ''),
    at: DateUtilsX.parse(json['at']),
  );

  final String kind;
  final String type;
  final String text;
  final DateTime? at;
}

class MessagePage {
  const MessagePage({required this.messages, required this.cursor});

  final List<Message> messages;
  final CursorPage cursor;
}

/// A compact server-side catch-up response. It contains no message body because
/// the visible providers remain the source of rendering; its only job is to tell
/// a sleeping/offline client exactly when it must refresh.
class InboxChanges {
  const InboxChanges({required this.cursor, required this.count});

  final String cursor;
  final int count;

  factory InboxChanges.fromJson(
    Map<String, dynamic> json,
    List<dynamic> data,
  ) => InboxChanges(cursor: json.strOr('cursor', ''), count: data.length);
}

class InboxApi {
  InboxApi(this._client);

  static const _base = '/inbox/conversations';

  final ApiClient _client;

  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {...query, 'page': page, 'per_page': perPage},
    );
    return Paged(
      items: response.list.map(Conversation.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  Future<InboxFacets> facets(Map<String, dynamic> query) async {
    final response = await _client.get('$_base/facets', query: query);
    return InboxFacets.fromJson(response.object);
  }

  /// Fetches only changes since the last cursor. On first use the API returns a
  /// cursor and no historical payload, because the normal list fetch is already
  /// the authoritative initial snapshot.
  Future<InboxChanges> changes(String? after) async {
    final response = await _client.get(
      '/inbox/changes',
      query: {'after': after},
    );
    return InboxChanges.fromJson(response.object, response.list);
  }

  Future<List<String>> labels() async {
    final response = await _client.get('/inbox/labels');
    final data = response.data;
    return data is List ? data.map((e) => '$e').toList() : const [];
  }

  Future<Conversation> get(String id) async {
    final response = await _client.get('$_base/$id');
    return Conversation.fromJson(response.object);
  }

  /// Newest-first, cursor-paginated. The thread renders reversed, so "older"
  /// means fetching with the oldest loaded message as `before`.
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    final response = await _client.get(
      '$_base/$id/messages',
      query: {'per_page': perPage, 'before': before},
    );
    return MessagePage(
      messages: response.list.map(Message.fromJson).toList(),
      cursor: response.cursor ?? const CursorPage.empty(),
    );
  }

  Future<Message> send(
    String id, {
    String? text,
    List<MessageAttachment> attachments = const [],
  }) async {
    final response = await _client.post(
      '$_base/$id/messages',
      body: {
        if (text != null && text.isNotEmpty) 'text': text,
        if (attachments.isNotEmpty)
          'attachments': [
            for (final attachment in attachments)
              {
                'url': attachment.url,
                'type': attachment.type,
                'name': ?attachment.name,
              },
          ],
      },
    );
    return Message.fromJson(response.object);
  }

  /// Internal note — stored on the thread, never delivered to the platform.
  Future<Message> addNote(String id, String text) async {
    final response = await _client.post(
      '$_base/$id/notes',
      body: {'text': text},
    );
    return Message.fromJson(response.object);
  }

  Future<void> markRead(String id) => _client.post('$_base/$id/read');

  Future<Conversation> assign(
    String id,
    String? assigneeId, {
    String? note,
  }) async {
    final response = await _client.post(
      '$_base/$id/assign',
      body: {'assignee_id': assigneeId, 'note': ?note},
    );
    return Conversation.fromJson(response.object);
  }

  Future<Conversation> update(String id, Map<String, dynamic> body) async {
    final response = await _client.put('$_base/$id', body: body);
    return Conversation.fromJson(response.object);
  }

  /// Materialises the contact into a CRM customer server-side (lead-first, with
  /// phone/email dedup). Idempotent — returns the existing customer if linked.
  Future<({String customerId, bool created, bool linkedExisting})> convert(
    String id,
  ) async {
    final response = await _client.post('$_base/$id/convert');
    final json = response.object;
    return (
      customerId: json.strOr('customer_id', ''),
      created: json.flag('created'),
      linkedExisting: json.flag('linked_existing'),
    );
  }

  Future<int> setLabels(
    List<String> conversationIds,
    List<String> labels, {
    String mode = 'add',
  }) async {
    final response = await _client.post(
      '$_base/labels',
      body: {
        'conversation_ids': conversationIds,
        'labels': labels,
        'mode': mode,
      },
    );
    return response.object.intOr('updated');
  }

  Future<ConversationContext> context(String id) async {
    final response = await _client.get('$_base/$id/context');
    final json = response.object;
    return ConversationContext(
      opportunities: json
          .mapList('opportunities')
          .map(ContextOpportunity.fromJson)
          .toList(),
      timeline: json.mapList('timeline').map(TimelineEntry.fromJson).toList(),
    );
  }

  /// Uploads an attachment and returns a URL the platform can fetch.
  /// Note the path: `/inbox/media`, not under `/inbox/conversations` — the
  /// latter would be captured by the `{id}` route.
  Future<MessageAttachment> uploadMedia(
    String filePath, {
    String? filename,
  }) async {
    final response = await _client.upload(
      '/inbox/media',
      field: 'file',
      filePath: filePath,
      filename: filename,
    );
    return MessageAttachment.fromJson(response.object);
  }
}

final inboxApiProvider = Provider<InboxApi>((ref) {
  return InboxApi(ref.watch(apiClientProvider));
});
