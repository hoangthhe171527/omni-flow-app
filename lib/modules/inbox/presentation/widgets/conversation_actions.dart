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
  final controller = TextEditingController();
  // Không dùng showOmniConfirm: đây không phải câu hỏi có/không mà là một ô
  // nhập liệu. CupertinoAlertDialog có nhận TextField, nhưng một hộp thoại
  // nhập liệu là màn hình chứ không phải lời nhắc — nó xứng đáng có thiết kế
  // riêng chứ không phải nhét vào cái API dành cho câu hỏi.
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Gắn nhãn'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'VD: gia đình, VIP'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Áp dụng'),
        ),
      ],
    ),
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

  Future<void> markRead(Conversation c) => _run(() async {
    await _api.markRead(c.id);
    // Bản MỚI NHẤT trong danh sách (tin có thể đã đổi trong lúc chờ), không
    // phải bản `c` chụp lúc bấm giữ.
    Conversation? latest;
    try {
      latest = _container
          .read(inboxListProvider)
          .valueOrNull
          ?.items
          .where((item) => item.id == c.id)
          .firstOrNull;
    } catch (_) {
      // Container đã huỷ: dùng bản chụp, phần cập nhật phía dưới cũng bỏ qua.
    }
    return (latest ?? c).copyWith(unread: 0);
  }, 'Đã đánh dấu đã đọc.');

  /// "Lưu trữ" = đóng hội thoại; máy chủ không có trạng thái lưu trữ riêng.
  Future<void> setArchived(Conversation c, bool archived) => _run(
    () => _api.setStatus(
      c.id,
      archived ? ConversationStatus.closed : ConversationStatus.open,
    ),
    archived ? 'Đã lưu trữ hội thoại.' : 'Đã mở lại hội thoại.',
  );

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

  Future<void> _run(Future<Conversation> Function() call, String done) async {
    final Conversation updated;
    try {
      updated = await call();
    } on AppException catch (error) {
      _say(error.message);
      return;
    } catch (_) {
      _say('Không thực hiện được. Vui lòng thử lại.');
      return;
    }
    // Máy chủ đã nhận: phần cập nhật giao diện dưới đây có thể gặp container
    // đã bị huỷ (đóng cả ứng dụng) — không được biến nó thành lỗi thao tác.
    try {
      _container.read(inboxListProvider.notifier).reconcile(updated);
      _container.invalidate(conversationProvider(updated.id));
    } catch (_) {}
    _say(done);
  }

  void _say(String text) {
    if (!_messenger.mounted) return;
    _messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

enum PeekAction { markRead, assign, label, archive, reopen }

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

/// Các mục menu xem trước, theo quyền của người xem. Chỉ có mục mà máy chủ
/// làm được: chưa có API đánh dấu chưa đọc / tắt thông báo / ghim / chặn.
List<PeekMenuItem> peekMenuFor(Conversation c, InboxAccess access) {
  final closed = c.status == ConversationStatus.closed;
  return [
    if (c.isUnread && access.canUpdate)
      const PeekMenuItem(
        label: 'Đánh dấu đã đọc',
        icon: Icons.mark_email_read_outlined,
        action: PeekAction.markRead,
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
