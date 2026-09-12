import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../security/session/session_controller.dart';
import 'thread_controller.dart';

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

/// Bumped by a foreground FCM notification.
///
/// Module notifications bấm cái này (và import nó từ `inbox_providers.dart`,
/// nơi nó vẫn được export). Nó không còn là thứ màn hình nghe trực tiếp: cả
/// hai tín hiệu bên dưới đều gộp nó vào nhịp của mình, nên một banner đẩy và
/// một khung socket cho cùng một tin nhắn là MỘT lượt tải lại, không phải hai.
final inboxRealtimeSignalProvider = StateProvider<int>((ref) => 0);

/// Gộp các sự kiện dồn dập thành một lượt tải lại. Cùng nhịp với
/// `TaskRealtimeSignal`.
///
/// Năm webhook trong 100ms — khách gửi liền ba tin, Zalo báo "đã nhận" hai
/// tin trước — từng là năm lượt gọi API để vẽ ra cùng một màn hình.
const _coalesceWindow = Duration(milliseconds: 400);

class _Coalescer {
  _Coalescer(this._fire);

  final void Function() _fire;
  Timer? _timer;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(_coalesceWindow, _fire);
  }

  void cancel() => _timer?.cancel();
}

/// The tenant-wide inbox stream for the signed-in session, or null when there is
/// no tenant yet.
final _inboxChannelProvider = Provider<String?>((ref) {
  final tenantId = ref.watch(sessionProvider).tenant?.id;
  return (tenantId == null || tenantId.isEmpty)
      ? null
      : 'tenant.$tenantId.inbox';
});

/// "Danh sách hộp thư cần tải lại", gộp nhịp 400ms.
///
/// Provider này TỰ MỞ KÊNH tenant. Trước đây việc đó nằm ở một provider thứ
/// hai (`inboxRealtimeSubscriptionProvider`) mà màn danh sách phải nhớ theo
/// dõi KÈM tín hiệu — đúng kiểu hai mảnh mà module tasks đã bị quên bốn lần.
/// Một mảnh thay vì hai: `ref.watch(...)` tín hiệu này tự nó là đủ.
///
/// Vẫn là *tín hiệu*, không phải dữ liệu: payload broadcast chưa qua bộ lọc
/// quyền của người xem, nên hành động duy nhất là hỏi lại REST API — nơi có.
final inboxListSignalProvider = NotifierProvider<InboxListSignal, int>(
  InboxListSignal.new,
);

class InboxListSignal extends Notifier<int> {
  @override
  int build() {
    final coalescer = _Coalescer(() => state = state + 1);
    ref.onDispose(coalescer.cancel);

    final channel = ref.watch(_inboxChannelProvider);
    if (channel != null) {
      final unsubscribe = ref.watch(realtimeClientProvider).subscribePrivate(
        channel,
        (event) {
          if (event.event == 'message.created') coalescer.schedule();
        },
      );
      ref.onDispose(unsubscribe);
    }

    ref.listen(inboxRealtimeSignalProvider, (_, _) => coalescer.schedule());

    return 0;
  }
}

/// Tín hiệu của MỘT hội thoại đang mở — `family` theo id.
///
/// Trước đây mọi hội thoại đổ chung vào một tín hiệu: khách ở hội thoại A đọc
/// tin là màn chat B đang mở tải lại toàn bộ lịch sử. Giờ mỗi màn chỉ nghe kênh
/// của mình, và nghe tín hiệu này cũng chính là mở kênh đó.
///
/// `message.status` (đã nhận / đã xem) không tải lại gì cả: nó đổi đúng một
/// trường của một tin đã có trên màn, nên được vá tại chỗ trong
/// [ThreadController]. Chỉ khi không vá được — tin chưa tải, hay trạng thái
/// không phải trạng thái giao nhận (vd `recalled`) — mới rơi về tải lại.
final threadSignalProvider = NotifierProvider.autoDispose
    .family<ThreadRealtimeSignal, int, String>(ThreadRealtimeSignal.new);

class ThreadRealtimeSignal extends AutoDisposeFamilyNotifier<int, String> {
  /// Listing them individually rather than taking everything keeps a future
  /// server-side event from silently triggering refetch storms.
  static const _refetchEvents = {
    'message.created',
    'message.sent',
    'message.updated',
    'message.reaction',
    'conversation.read',
  };

  @override
  int build(String conversationId) {
    final coalescer = _Coalescer(() => state = state + 1);
    ref.onDispose(coalescer.cancel);

    if (conversationId.isNotEmpty) {
      final unsubscribe = ref.watch(realtimeClientProvider).subscribePrivate(
        'conversation.$conversationId',
        (event) {
          if (event.event == 'message.status') {
            if (!_patchStatus(event.data)) coalescer.schedule();
            return;
          }
          if (_refetchEvents.contains(event.event)) coalescer.schedule();
        },
      );
      ref.onDispose(unsubscribe);
    }

    ref.listen(inboxRealtimeSignalProvider, (_, _) => coalescer.schedule());

    return 0;
  }

  /// True when the receipt landed on a message already on screen.
  bool _patchStatus(Map<String, dynamic> data) {
    final messageId = data['message_id'];
    final status = data['status'];
    if (messageId is! String || status is! String) return false;
    // Không dựng thread provider chỉ để vá: nếu màn chưa tải lịch sử thì lượt
    // tải sắp tới đã mang sẵn trạng thái mới rồi.
    if (!ref.exists(threadProvider(arg))) return false;
    return ref
        .read(threadProvider(arg).notifier)
        .applyStatus(messageId, status);
  }
}
