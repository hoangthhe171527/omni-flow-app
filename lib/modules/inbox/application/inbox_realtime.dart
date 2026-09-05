import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../security/session/session_controller.dart';
import 'inbox_providers.dart';

/// How often a screen polls `/inbox/changes` as a safety net.
///
/// Polling is deliberately not deleted along with the arrival of realtime. A
/// WebSocket can die quietly — a proxy idle-timeout, a captive portal, a carrier
/// dropping long-lived connections — and the failure mode is a rep staring at an
/// inbox that stopped updating without saying so. So the poll stays; it just
/// stops being the mechanism.
///
/// The old intervals (5s inbox, 8s thread) were the *only* way a new message
/// arrived, which is why they were so tight. With a live socket they are a
/// heartbeat instead, and the request rate per rep drops by roughly 95%.
class RealtimePolling {
  const RealtimePolling._();

  static const inboxLive = Duration(minutes: 2);
  static const inboxFallback = Duration(seconds: 5);
  static const threadLive = Duration(minutes: 2);
  static const threadFallback = Duration(seconds: 8);

  static Duration inbox({required bool live}) =>
      live ? inboxLive : inboxFallback;

  static Duration thread({required bool live}) =>
      live ? threadLive : threadFallback;
}

/// The tenant-wide inbox stream for the signed-in session, or null when there is
/// no tenant yet.
final _inboxChannelProvider = Provider<String?>((ref) {
  final tenantId = ref.watch(sessionProvider).tenant?.id;
  return (tenantId == null || tenantId.isEmpty)
      ? null
      : 'tenant.$tenantId.inbox';
});

/// Keeps the app subscribed to the tenant inbox stream for as long as something
/// is watching, and turns every event into a refresh signal.
///
/// Deliberately a *signal*, never data: the broadcast payload has not been
/// through the caller's permission scope, so acting on it means refetching
/// through the REST API, which has. That is also what the web client does.
final inboxRealtimeSubscriptionProvider = Provider<void>((ref) {
  final channel = ref.watch(_inboxChannelProvider);
  if (channel == null) return;

  final client = ref.watch(realtimeClientProvider);
  final unsubscribe = client.subscribePrivate(channel, (event) {
    if (event.event == 'message.created') {
      final signal = ref.read(inboxRealtimeSignalProvider.notifier);
      signal.state = signal.state + 1;
    }
  });

  ref.onDispose(unsubscribe);
});

/// Subscribes to one conversation's stream while its thread is open.
///
/// Every event the server publishes for a thread — a new message, a delivery
/// status advancing, the customer reading it, a reaction — is the same request
/// to the client: go and refetch. Listing them individually rather than taking
/// everything keeps a future server-side event from silently triggering
/// refetch storms.
final conversationRealtimeSubscriptionProvider = Provider.autoDispose
    .family<void, String>((ref, conversationId) {
      if (conversationId.isEmpty) return;

      final client = ref.watch(realtimeClientProvider);
      const relevant = {
        'message.created',
        'message.sent',
        'message.status',
        'message.updated',
        'message.reaction',
        'conversation.read',
      };

      final unsubscribe = client.subscribePrivate(
        'conversation.$conversationId',
        (event) {
          if (!relevant.contains(event.event)) return;
          final signal = ref.read(inboxRealtimeSignalProvider.notifier);
          signal.state = signal.state + 1;
        },
      );

      ref.onDispose(unsubscribe);
    });
