import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';
import '../../domain/conversation.dart';
import '../../domain/inbox_permissions.dart';
import 'assign_sheet.dart';

/// Hộp thoại nhập một nhãn — dùng chung cho thanh chọn nhiều và menu xem
/// trước. Trả về nhãn đã cắt khoảng trắng, hoặc `null` khi huỷ.
Future<String?> showLabelDialog(BuildContext context) {
  // Không dùng showOmniConfirm: đây không phải câu hỏi có/không mà là một ô
  // nhập liệu. CupertinoAlertDialog có nhận TextField, nhưng một hộp thoại
  // nhập liệu là màn hình chứ không phải lời nhắc — nó xứng đáng có thiết kế
  // riêng chứ không phải nhét vào cái API dành cho câu hỏi.
  return showDialog<String>(
    context: context,
    builder: (_) => const LabelDialog(),
  );
}

/// Hộp thoại của [showLabelDialog]. Là State để controller sống đúng bằng hộp
/// thoại và được dispose khi hộp thoại đóng hẳn (hết hiệu ứng thoát) — dispose
/// ngay sau `await showDialog` thì TextField còn đang vẽ sẽ dùng controller đã
/// huỷ.
class LabelDialog extends StatefulWidget {
  const LabelDialog({super.key});

  @override
  State<LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<LabelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Gắn nhãn'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'VD: gia đình, VIP'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Áp dụng'),
      ),
    ],
  );
}

/// Thao tác trên MỘT hội thoại từ menu xem trước. Mỗi hàm: gọi API → xét lại
/// dòng trong danh sách ([InboxListController.reconcile]) → làm mới hội thoại
/// đang mở → báo kết quả. Lỗi thì chỉ báo, không vá — không có thành công giả.
class ConversationActions {
  /// Mọi thứ cần SAU `await` được lấy ngay ở đây, khi trang còn sống: `ref`
  /// của widget đã huỷ không dùng được, còn container / messenger thì sống
  /// lâu hơn trang (thao tác xong sau khi người dùng đã rời hộp thư vẫn phải
  /// cập nhật danh sách và báo kết quả, không ném lỗi).
  ConversationActions(this.ref, this.context)
    : _container = ProviderScope.containerOf(context, listen: false),
      _messenger = ScaffoldMessenger.of(context);

  final WidgetRef ref;
  final BuildContext context;
  final ProviderContainer _container;
  final ScaffoldMessengerState _messenger;

  InboxApi get _api => _container.read(inboxApiProvider);

  Future<bool> markRead(Conversation c) => _run(() async {
    await _api.markRead(c.id);
    return _latest(c).copyWith(unread: 0);
  }, 'Đã đánh dấu đã đọc.');

  /// "Lưu trữ" = đóng hội thoại; máy chủ không có trạng thái lưu trữ riêng.
  Future<void> setArchived(Conversation c, bool archived) => _run(
    () => _api.setStatus(
      c.id,
      archived ? ConversationStatus.closed : ConversationStatus.open,
    ),
    archived ? 'Đã lưu trữ hội thoại.' : 'Đã mở lại hội thoại.',
  );

  /// Đánh dấu chưa đọc (dùng chung cả đội). Trả `true` khi server đã nhận.
  Future<bool> markUnread(Conversation c) => _run(() async {
    final count = await _api.markUnread(c.id);
    return _latest(c).copyWith(unread: count < 1 ? 1 : count);
  }, 'Đã đánh dấu chưa đọc.');

  /// Ghim / bỏ ghim cho riêng mình. Vượt trần → 422 `pin_limit_reached`, báo
  /// đúng câu của server (qua [AppException.message]).
  Future<bool> setPinned(Conversation c, bool on) => _run(() async {
    final pinned = await _api.setPinned(c.id, on);
    return _latest(c).copyWith(isPinned: pinned);
  }, on ? 'Đã ghim hội thoại.' : 'Đã bỏ ghim.');

  /// Tắt (`on`) / bật thông báo cho riêng mình.
  Future<bool> setMuted(Conversation c, bool on) => _run(() async {
    final muted = await _api.setMuted(c.id, on);
    return _latest(c).copyWith(isMuted: muted);
  }, on ? 'Đã tắt thông báo.' : 'Đã bật thông báo.');

  /// "Chặn hội thoại" — CHỈ trong CRM: hội thoại ẩn khỏi Hộp thư của cả đội,
  /// tin mới vẫn lưu nhưng không báo. Không chặn khách trên nền tảng. Chặn
  /// luôn hỏi lại; bỏ chặn thì không. Trả `true` khi server đã nhận.
  Future<bool> setBlocked(Conversation c, bool on) async {
    if (on) {
      final ok = await showOmniConfirm(
        context: context,
        title: 'Chặn hội thoại này?',
        message:
            'Hội thoại sẽ ẩn khỏi Hộp thư của cả đội. Tin mới vẫn được lưu '
            'nhưng không báo, không tính chưa đọc. Thao tác này chỉ trong CRM '
            '— không chặn khách trên Zalo hay Facebook.',
        confirmLabel: 'Chặn',
        destructive: true,
      );
      if (!ok) return false;
    }
    return _run(
      () => _api.setBlocked(c.id, on),
      on ? 'Đã chặn hội thoại.' : 'Đã bỏ chặn hội thoại.',
    );
  }

  /// Bản MỚI NHẤT của [c] trên màn (danh sách chính hoặc mục ghim) — tin có
  /// thể đã đổi trong lúc chờ — không phải bản chụp lúc bấm giữ.
  Conversation _latest(Conversation c) {
    try {
      bool same(Conversation x) => x.id == c.id;
      // `exists`: không dựng hộ danh sách (một lượt tải) khi gọi từ trang
      // Thông tin mở thẳng bằng liên kết.
      final main = _container.exists(inboxListProvider)
          ? _container.read(inboxListProvider).valueOrNull?.items
          : null;
      final pinned = _container.exists(pinnedConversationsProvider)
          ? _container.read(pinnedConversationsProvider).valueOrNull
          : null;
      return main?.where(same).firstOrNull ??
          pinned?.where(same).firstOrNull ??
          c;
    } catch (_) {
      // Container đã huỷ: dùng bản chụp, phần cập nhật phía sau cũng bỏ qua.
      return c;
    }
  }

  Future<void> assign(Conversation c) async {
    final result = await showOmniSheet<AssignResult>(
      context: context,
      expand: true,
      builder: (_) => AssignSheet(currentAssigneeId: c.assigneeId),
    );
    if (result == null) return;
    await _run(
      () => _api.assign(c.id, result.assigneeId, note: result.note),
      result.assigneeId == null ? 'Đã bỏ gán.' : 'Đã gán hội thoại.',
    );
  }

  Future<void> addLabel(Conversation c) async {
    final label = await showLabelDialog(context);
    if (label == null || label.trim().isEmpty) return;
    await _run(() async {
      await _api.setLabels([c.id], [label.trim()]);
      return _api.get(c.id);
    }, 'Đã gắn nhãn.');
  }

  /// Gọi API → vá cả hai mục (danh sách chính + "Đã ghim") → làm mới hội
  /// thoại đang mở → báo. `true` khi server đã nhận; lỗi thì chỉ báo lỗi.
  Future<bool> _run(Future<Conversation> Function() call, String done) async {
    final Conversation updated;
    try {
      updated = await call();
    } on AppException catch (error) {
      _say(error.message);
      return false;
    } catch (_) {
      _say('Không thực hiện được. Vui lòng thử lại.');
      return false;
    }
    // Máy chủ đã nhận: phần cập nhật giao diện dưới đây có thể gặp container
    // đã bị huỷ (đóng cả ứng dụng) — không được biến nó thành lỗi thao tác.
    try {
      // Danh sách chính XÉT LẠI: ghim → rời, bỏ ghim → chèn, chặn → rời.
      if (_container.exists(inboxListProvider)) {
        _container.read(inboxListProvider.notifier).reconcile(updated);
      }
      if (_container.exists(pinnedConversationsProvider)) {
        _container.read(pinnedConversationsProvider.notifier).upsert(updated);
      }
      _container.invalidate(conversationProvider(updated.id));
    } catch (_) {}
    _say(done);
    return true;
  }

  void _say(String text) {
    if (!_messenger.mounted) return;
    _messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

enum PeekAction {
  markRead,
  markUnread,
  assign,
  label,
  pin,
  unpin,
  mute,
  unmute,
  archive,
  reopen,
  block,
  unblock,
}

class PeekMenuItem {
  const PeekMenuItem({
    required this.label,
    required this.icon,
    required this.action,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final bool destructive;
  final PeekAction action;
}

/// Các mục menu xem trước, theo thứ tự README, mỗi mục tự xét quyền (đối
/// chiếu `routes.php` của API):
/// - Đã đọc / Chưa đọc: `inbox.write`;
/// - Gán, Nhãn: `inbox.write`;
/// - Ghim, Tắt thông báo: sở thích riêng, quyền ĐỌC là đủ — luôn hiện;
/// - Lưu trữ / Mở lại: `inbox.write`;
/// - Chặn / Bỏ chặn hội thoại: `inbox.write` + đọc toàn tenant
///   ([InboxAccess.canBlock]); sale `.own` bị 403 nên ẩn.
List<PeekMenuItem> peekMenuFor(Conversation c, InboxAccess access) {
  final closed = c.status == ConversationStatus.closed;
  return [
    if (c.isUnread && access.canUpdate)
      const PeekMenuItem(
        label: 'Đánh dấu đã đọc',
        icon: Icons.mark_email_read_outlined,
        action: PeekAction.markRead,
      ),
    // Đã chặn: API trả 422 `conversation_blocked` cho /unread.
    if (!c.isUnread && !c.isBlocked && access.canUpdate)
      const PeekMenuItem(
        label: 'Đánh dấu chưa đọc',
        icon: Icons.mark_email_unread_outlined,
        action: PeekAction.markUnread,
      ),
    if (access.canAssign)
      const PeekMenuItem(
        label: 'Gán cho…',
        icon: Icons.person_add_alt_outlined,
        action: PeekAction.assign,
      ),
    if (access.canLabel)
      const PeekMenuItem(
        label: 'Thêm nhãn',
        icon: Icons.sell_outlined,
        action: PeekAction.label,
      ),
    if (c.isPinned)
      const PeekMenuItem(
        label: 'Bỏ ghim',
        icon: Icons.push_pin_outlined,
        action: PeekAction.unpin,
      )
    else
      const PeekMenuItem(
        label: 'Ghim',
        icon: Icons.push_pin_outlined,
        action: PeekAction.pin,
      ),
    if (c.isMuted)
      const PeekMenuItem(
        label: 'Bật thông báo',
        icon: Icons.notifications_active_outlined,
        action: PeekAction.unmute,
      )
    else
      const PeekMenuItem(
        label: 'Tắt thông báo',
        icon: Icons.notifications_off_outlined,
        action: PeekAction.mute,
      ),
    if (access.canUpdate && !closed)
      const PeekMenuItem(
        label: 'Lưu trữ',
        icon: Icons.archive_outlined,
        action: PeekAction.archive,
        destructive: true,
      ),
    if (access.canUpdate && closed)
      const PeekMenuItem(
        label: 'Mở lại',
        icon: Icons.unarchive_outlined,
        action: PeekAction.reopen,
      ),
    if (access.canBlock && !c.isBlocked)
      const PeekMenuItem(
        label: 'Chặn hội thoại',
        icon: Icons.block_rounded,
        action: PeekAction.block,
        destructive: true,
      ),
    if (access.canBlock && c.isBlocked)
      const PeekMenuItem(
        label: 'Bỏ chặn hội thoại',
        icon: Icons.block_rounded,
        action: PeekAction.unblock,
      ),
  ];
}

/// Chuyển hội thoại thành khách hàng (hoặc liên kết với khách có sẵn). Dùng ở
/// khối giới thiệu đầu hội thoại và trang Thông tin. Mọi thứ cần SAU `await`
/// được lấy trước nó: màn gọi có thể đã bị gỡ khi lượt gọi về.
Future<void> convertConversation(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await container
        .read(inboxApiProvider)
        .convert(conversationId);
    try {
      container.invalidate(conversationProvider(conversationId));
    } catch (_) {}
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.linkedExisting
              ? 'Đã liên kết với khách hàng có sẵn.'
              : 'Đã tạo khách hàng mới.',
        ),
      ),
    );
  } on AppException catch (error) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}
