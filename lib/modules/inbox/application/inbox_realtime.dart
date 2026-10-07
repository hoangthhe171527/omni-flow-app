import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../security/session/session_controller.dart';
import 'thread_controller.dart';

/// Nhịp gốc của lượt poll `/inbox/changes` khi KHÔNG có kênh realtime sống.
///
/// Poll không bị xoá cùng lúc realtime tới. Một WebSocket có thể chết lặng —
/// proxy hết hạn chờ, cổng wifi khách sạn, nhà mạng cắt kết nối dài — và kiểu
/// hỏng đó (nhân viên ngồi nhìn hộp thư đã ngừng cập nhật mà không ai nói) tệ
/// hơn số lượt gọi. Nên poll còn lại; nó chỉ không còn là cơ chế.
///
/// Hai con số 5s/8s là nhịp CỦA LÚC MẤT KÊNH. Khi kênh sống thì
/// [InboxRealtime.pollInterval] trả `null`: không poll chút nào.
class RealtimePolling {
  const RealtimePolling._();

  static const inboxFallback = Duration(seconds: 5);
  static const threadFallback = Duration(seconds: 8);
}

/// Nhịp poll dự phòng, tính từ trạng thái THẬT của kênh realtime (MS-I38).
///
/// Trước đợt này nhịp chỉ có hai giá trị cố định và cả hai luôn chạy: kênh
/// sống vẫn gõ cửa mỗi 2 phút, kênh rớt thì mọi máy trong tenant quay lại 5
/// giây một lượt — cùng một giây, vì tất cả rớt cùng lúc khi server khởi động
/// lại. Hai thay đổi ở đây:
///
/// - **Kênh sống thì không poll** ([pollInterval] trả `null`). Sự kiện đã tới
///   qua socket; lượt poll chỉ để xác nhận là không có gì mới.
/// - **Kênh rớt thì giãn dần** 1 → 2 → 4 (trần 4, khớp web) kèm nhiễu ±20%, nên
///   mất kết nối hàng loạt dàn ra chứ không dồn vào một nhịp.
///
/// Đây là một giá trị có trạng thái, không phải hàm thuần: nó nhớ đã giãn tới
/// nhịp nào. Màn hình giữ MỘT cái cho cả vòng đời của mình.
class InboxRealtime {
  InboxRealtime({
    required Duration fallback,
    RealtimeStatus status = RealtimeStatus.disconnected,
    Random? random,
  }) : _fallback = fallback,
       _status = status,
       _random = random ?? Random();

  /// Nhịp của danh sách hộp thư (gốc 5 giây).
  InboxRealtime.inbox({
    RealtimeStatus status = RealtimeStatus.disconnected,
    Random? random,
  }) : this(
         fallback: RealtimePolling.inboxFallback,
         status: status,
         random: random,
       );

  /// Nhịp của một hội thoại đang mở (gốc 8 giây).
  InboxRealtime.thread({
    RealtimeStatus status = RealtimeStatus.disconnected,
    Random? random,
  }) : this(
         fallback: RealtimePolling.threadFallback,
         status: status,
         random: random,
       );

  @visibleForTesting
  InboxRealtime.forTest({required RealtimeStatus state, Random? random})
    : this.inbox(status: state, random: random);

  /// Trần của nhịp giãn: 2^2 = 4 lần nhịp gốc (20 giây ở hộp thư, 32 giây ở
  /// màn chat).
  ///
  /// Có trần vì không có trần thì một máy để quên trong ngăn kéo sẽ thôi không
  /// bao giờ phát hiện ra là mạng đã về. Con số là 4 chứ không phải 8 để khớp
  /// plan ("backoff 1 → 2 → 4") và khớp web (`use-inbox.ts` `MAX_BACKOFF = 4`):
  /// ở 8× thì tin khách tới trong lúc socket chết có thể chậm thêm tới 64 giây
  /// ở màn chat.
  static const maxBackoffSteps = 2;

  /// Nhiễu ±20% quanh nhịp đã tính.
  static const jitterRatio = 0.2;

  final Duration _fallback;
  final Random _random;
  RealtimeStatus _status;
  int _step = 0;

  RealtimeStatus get status => _status;

  @visibleForTesting
  int get backoffStep => _step;

  /// Bao lâu nữa thì gọi `/inbox/changes`, hay `null` khi không cần gọi.
  ///
  /// Mỗi lần ĐỌC là một giá trị nhiễu khác — người gọi phải đọc đúng một lần
  /// cho mỗi lượt hẹn giờ, đừng so hai lượt đọc với nhau.
  Duration? get pollInterval {
    if (_status == RealtimeStatus.connected) return null;
    // Bản dựng không cấu hình realtime: không có kênh nào để chờ, cũng không
    // có đợt nối lại đồng loạt nào để dàn ra. Nhịp gốc, cố định, như trước.
    if (_status == RealtimeStatus.disabled) return _fallback;
    return _withJitter(_fallback * (1 << _step));
  }

  /// Chế độ hẹn giờ của một trạng thái: không poll (`connected`), poll nhịp
  /// gốc cố định (`disabled`), hay poll nhịp giãn kèm nhiễu (còn lại).
  ///
  /// `connecting` và `disconnected` là CÙNG một chế độ — đó là cả điểm của
  /// hàm này.
  static int _timerMode(RealtimeStatus status) => switch (status) {
    RealtimeStatus.connected => 0,
    RealtimeStatus.disabled => 1,
    RealtimeStatus.connecting || RealtimeStatus.disconnected => 2,
  };

  /// Ghi nhận trạng thái kênh mới; trả `true` khi người gọi cần dựng lại hẹn
  /// giờ của mình (chu kỳ của một `Timer` là cố định lúc tạo).
  ///
  /// Chỉ trả `true` khi CHẾ ĐỘ đổi (`connected` ↔ không-`connected`). Vòng nối
  /// lại sinh hai lần đổi trạng thái mỗi lượt thử (`disconnected` →
  /// `connecting` → `disconnected`) ở t ≈ 0, 2, 6, 14, 30 s; người gọi
  /// `cancel()` rồi dựng lại hẹn giờ từ 0 cho mỗi lần đổi, nên nếu
  /// `connecting` cũng tính thì nhịp 4–6 giây không bao giờ chạy tới và lượt
  /// poll ĐẦU TIÊN chỉ rơi vào khoảng t ≈ 19 s — đúng 19 giây đầu của một đợt
  /// mất kết nối thì lưới an toàn không tồn tại. Càng chập chờn càng dài.
  bool setState(RealtimeStatus next) {
    if (next == _status) return false;
    final wasConnected = _status == RealtimeStatus.connected;
    final modeChanged = _timerMode(_status) != _timerMode(next);
    _status = next;
    // Nối được, hay vừa rớt khỏi một kênh đang sống, thì đếm lại từ đầu. Một
    // lượt thử nối lại KHÔNG thành (`connecting` → `disconnected`) thì giữ
    // nguyên: đó đúng là lúc không nên gõ cửa dày hơn.
    if (next == RealtimeStatus.connected || wasConnected) _step = 0;
    return modeChanged;
  }

  /// Một lượt poll đã chạy mà kênh vẫn chưa về: lượt sau giãn ra.
  void tickBackoff() {
    if (_status == RealtimeStatus.connected ||
        _status == RealtimeStatus.disabled) {
      return;
    }
    if (_step < maxBackoffSteps) _step++;
  }

  Duration _withJitter(Duration value) {
    final spread = 1 + (_random.nextDouble() * 2 - 1) * jitterRatio;
    return Duration(milliseconds: (value.inMilliseconds * spread).round());
  }
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

/// Chờ lâu nhất kể từ sự kiện ĐẦU của một loạt. Debounce thuần không có trần:
/// sự kiện cách nhau dưới 400ms liên tục (giờ cao điểm, gán hàng loạt) thì
/// màn hình không bao giờ tải lại cho tới khi có một khoảng lặng.
const _coalesceMaxWait = Duration(seconds: 2);

class _Coalescer {
  _Coalescer(this._fire);

  final void Function() _fire;
  Timer? _timer;
  Timer? _maxTimer;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(_coalesceWindow, _flush);
    _maxTimer ??= Timer(_coalesceMaxWait, _flush);
  }

  void _flush() {
    cancel();
    _fire();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _maxTimer?.cancel();
    _maxTimer = null;
  }
}

/// The tenant-wide inbox stream for the signed-in session, or null when there is
/// no tenant yet.
final _inboxChannelProvider = Provider<String?>((ref) {
  final tenantId = ref.watch(sessionProvider).tenant?.id;
  return (tenantId == null || tenantId.isEmpty)
      ? null
      : 'tenant.$tenantId.inbox';
});

/// "Danh sách hộp thư cần tải lại", gộp nhịp 400ms (trần 2 giây).
///
/// Provider này TỰ MỞ KÊNH tenant. Trước đây việc đó nằm ở một provider thứ
/// hai (`inboxRealtimeSubscriptionProvider`) mà màn danh sách phải nhớ theo
/// dõi KÈM tín hiệu — đúng kiểu hai mảnh mà module tasks đã bị quên bốn lần.
/// Một mảnh thay vì hai: `ref.watch(...)` tín hiệu này tự nó là đủ.
///
/// Vẫn là *tín hiệu*, không phải dữ liệu: payload broadcast chưa qua bộ lọc
/// quyền của người xem, nên hành động duy nhất là hỏi lại REST API — nơi có.
///
/// Chỉ `message.created` (và FCM). `conversation.updated` đi đường riêng
/// [inboxConversationUpdatesProvider]: nó mang id, nên chỉ vá đúng dòng đó.
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

/// Một loạt `conversation.updated` đã gộp nhịp.
class ConversationUpdateBatch {
  const ConversationUpdateBatch({
    required this.reasonsById,
    required this.unscoped,
  });

  /// id hội thoại → các `reason` API gửi (`assigned`, `labels`, `updated`,
  /// `sent`, `read`, `deleted`, `converted`).
  final Map<String, Set<String>> reasonsById;

  /// Có sự kiện không mang id nào — chỉ biết "có gì đó đổi".
  final bool unscoped;
}

/// `conversation.updated` (Đợt 6, INB-I7): API phát khi hội thoại được giao,
/// đổi trạng thái, nhãn, gửi tin, đã đọc… — payload CHỈ có id và lý do.
///
/// Mỗi lần ai đó trong tenant mở một hội thoại (`read`) hay gửi một tin
/// (`sent`) là một sự kiện tới MỌI máy. Tải lại trang 1 cho mỗi sự kiện vừa
/// tốn vừa làm danh sách đang cuộn ở trang 3 co về 20 dòng. Nên ở đây chỉ gom
/// id; [InboxListController] vá đúng những dòng đó.
final inboxConversationUpdatesProvider =
    NotifierProvider<InboxConversationUpdates, ConversationUpdateBatch?>(
      InboxConversationUpdates.new,
    );

class InboxConversationUpdates extends Notifier<ConversationUpdateBatch?> {
  final Map<String, Set<String>> _pending = {};
  bool _pendingUnscoped = false;

  @override
  ConversationUpdateBatch? build() {
    final coalescer = _Coalescer(_flush);
    ref.onDispose(coalescer.cancel);

    final channel = ref.watch(_inboxChannelProvider);
    if (channel != null) {
      final unsubscribe = ref.watch(realtimeClientProvider).subscribePrivate(
        channel,
        (event) {
          if (event.event != 'conversation.updated') return;
          _collect(event.data);
          coalescer.schedule();
        },
      );
      ref.onDispose(unsubscribe);
    }

    return null;
  }

  void _collect(Map<String, dynamic> data) {
    final reason = data['reason'] is String
        ? data['reason'] as String
        : 'updated';
    final ids = <String>{
      if (data['conversation_ids'] case final List<dynamic> list)
        for (final id in list)
          if (id is String && id.isNotEmpty) id,
      if (data['conversation_id'] case final String id when id.isNotEmpty) id,
    };
    if (ids.isEmpty) {
      _pendingUnscoped = true;
      return;
    }
    for (final id in ids) {
      _pending.putIfAbsent(id, () => <String>{}).add(reason);
    }
  }

  void _flush() {
    if (_pending.isEmpty && !_pendingUnscoped) return;
    state = ConversationUpdateBatch(
      reasonsById: Map.of(_pending),
      unscoped: _pendingUnscoped,
    );
    _pending.clear();
    _pendingUnscoped = false;
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
          if (event.event == 'message.sent' && _absorbSent(event.data)) return;
          if (_refetchEvents.contains(event.event)) coalescer.schedule();
        },
      );
      ref.onDispose(unsubscribe);
    }

    ref.listen(inboxRealtimeSignalProvider, (_, _) => coalescer.schedule());

    return 0;
  }

  /// Một tin gửi phát HAI `message.sent` (Đợt 7, review M7): API phát lúc
  /// nhận tin (`{message_id, direction:'out'}`), worker phát lúc giao xong
  /// (`{message_id, status}`), thường cách nhau quá cửa sổ gộp nhịp. True khi
  /// sự kiện đã được xử lý mà không cần tải lại cả luồng:
  /// - bản của worker: vá trạng thái như `message.status` — trừ `failed`, vì
  ///   lý do lỗi chỉ có khi tải lại;
  /// - bản của API cho một tin đã có trên màn (người gửi đã nhận nó từ phản
  ///   hồi POST): không có gì mới.
  bool _absorbSent(Map<String, dynamic> data) {
    final status = data['status'];
    if (status is String) {
      return status != 'failed' && _patchStatus(data);
    }
    final messageId = data['message_id'];
    if (messageId is! String || !ref.exists(threadProvider(arg))) return false;
    final thread = ref.read(threadProvider(arg)).valueOrNull;
    return thread?.messages.any((m) => m.id == messageId) ?? false;
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
