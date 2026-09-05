import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/app_notification.dart';

class NotificationsApi {
  NotificationsApi(this._client);

  static const _base = '/notifications';

  final ApiClient _client;

  /// The signed-in user's notifications.
  ///
  /// The recipient is resolved server-side from the token; there is no user id
  /// to send, and sending one would let a caller read somebody else's bell.
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
    bool unreadOnly = false,
  }) async {
    final response = await _client.get(
      _base,
      query: {
        'page': page,
        'per_page': perPage,
        if (unreadOnly) 'unread': true,
      },
    );

    return Paged(
      items: response.list.map(AppNotification.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  Future<void> markRead(String id) => _client.post('$_base/$id/mark-read');

  Future<void> markAllRead() => _client.post('$_base/mark-all-read');
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(apiClientProvider)),
);
