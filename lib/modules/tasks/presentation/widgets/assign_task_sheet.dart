import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';

/// Chọn ai làm một công việc, ngay trên điện thoại.
///
/// Trước đây danh sách người làm chỉ ĐỌC được: muốn giao việc phải mở máy
/// tính. Nhưng người giao việc ở xưởng đứng giữa nhà xưởng, không ngồi bàn —
/// và một thao tác chỉ làm được ở chỗ họ không đứng thì thực tế là không có.
///
/// Chọn NHIỀU người, vì một đầu việc thường hai người cùng làm (§B2). Bỏ chọn
/// hết cũng là một lựa chọn có nghĩa: trả việc về "chưa gán ai" để ai rảnh tự
/// nhận — đúng mô hình pull-based ở §3.
///
/// Trả về `null` khi người dùng đóng sheet mà không lưu, và danh sách id khi
/// họ bấm lưu. Chỗ gọi tự so với danh sách cũ để khỏi ghi rỗng.
Future<List<String>?> showAssignTaskSheet({
  required BuildContext context,
  required List<String> currentIds,
  String title = 'Ai làm việc này',
  String Function(int picked)? confirmLabel,
  Set<String>? allowedIds,
}) => showOmniSheet<List<String>>(
  context: context,
  builder: (context) => _AssignTaskSheet(
    currentIds: currentIds,
    allowedIds: allowedIds,
    title: title,
    confirmLabel: confirmLabel,
  ),
);

/// Bộ chọn người làm chuẩn sheet kính 30px (đồng nhất với [showAssignTaskSheet]).
Future<List<String>?> showAssignTaskMenu({
  required BuildContext context,
  required Rect anchor,
  required List<String> currentIds,
  String title = 'Ai làm việc này',
}) => showOmniSheet<List<String>>(
  context: context,
  builder: (context) => _AssignTaskSheet(
    sheetKey: const Key('assign-task-menu'),
    currentIds: currentIds,
    title: title,
  ),
);

class _AssignTaskSheet extends ConsumerStatefulWidget {
  const _AssignTaskSheet({
    this.sheetKey,
    required this.currentIds,
    required this.title,
    this.confirmLabel,
    this.allowedIds,
  });

  final Key? sheetKey;
  final List<String> currentIds;

  /// Chỉ cho chọn trong tập này (thành viên kế hoạch đích khi sao chép);
  /// null = không lọc. Người đang được chọn lúc mở vẫn hiện để còn gỡ.
  final Set<String>? allowedIds;
  final String title;

  /// Chữ nút lưu theo số người đã chọn; null = chữ của "giao việc".
  final String Function(int picked)? confirmLabel;

  @override
  ConsumerState<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<_AssignTaskSheet> {
  late final Set<String> _picked = {...widget.currentIds};

  /// Người được chọn lúc mở: luôn hiện, kể cả ngoài `allowedIds`, để gỡ được
  /// — và không biến mất khỏi danh sách ngay khi vừa bỏ chọn.
  late final Set<String> _initial = {...widget.currentIds};
  String _search = '';

  void _toggle(String userId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_picked.add(userId)) {
        _picked.remove(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: widget.title,
      child: OmniSheetBody(
        key: widget.sheetKey,
        header: OmniSheetHeader(
          title: widget.title,
          subtitle: _picked.isEmpty ? null : '${_picked.length} đã chọn',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng chọn người làm',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        footer: FilledButton(
          onPressed: () => Navigator.of(context).pop(_picked.toList()),
          // Nói ra số người đã chọn: bỏ chọn hết là một lựa chọn hợp lệ
          // (trả việc về hàng đợi chung), nên nút phải phân biệt được nó
          // với việc bấm nhầm.
          child: Text(
            widget.confirmLabel?.call(_picked.length) ??
                (_picked.isEmpty
                    ? 'Bỏ gán tất cả'
                    : 'Giao cho ${_picked.length} người'),
          ),
        ),
        children: [
          OmniSearchField(
            hint: 'Tìm người...',
            debounce: Duration.zero,
            onChanged: (value) => setState(() => _search = value),
          ),
          // Không dùng OmniAsyncView: trạng thái tải / trống của nó là một
          // ListView, mà thân sheet đã cuộn.
          switch (members) {
            AsyncError(:final error) => OmniErrorView(
              error: error,
              onRetry: () => ref.invalidate(teamDirectoryProvider),
            ),
            AsyncData(:final value) when _visible(value).isEmpty =>
              const OmniEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Không tìm thấy ai',
                message: 'Thử tên khác, hoặc xoá ô tìm kiếm.',
              ),
            AsyncData(:final value) => OmniGroupSection(
              key: const Key('assign-task-members'),
              dividerIndent: 58,
              children: [
                for (final member in _visible(value))
                  OmniGroupRow(
                    leading: OmniAvatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      size: 32,
                    ),
                    title: member.name,
                    subtitle: _assigneeRoleLabel(member),
                    selected: _picked.contains(member.userId),
                    chevron: false,
                    onTap: () => _toggle(member.userId),
                  ),
              ],
            ),
            _ => const Padding(
              padding: EdgeInsets.all(OmniSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          },
        ],
      ),
    );
  }

  /// Lọc theo ô tìm kiếm, và chỉ những người còn hoạt động VÀ đã nhận lời mời
  /// (APP-I10).
  ///
  /// Giao việc cho một tài khoản đã ngừng hoạt động là giao vào chỗ không ai
  /// nhận — nhưng người ĐANG được gán vẫn hiện, để còn gỡ họ ra.
  List<TeamMember> _visible(List<TeamMember> members) {
    final needle = _search.trim().toLowerCase();
    final allowed = widget.allowedIds;

    // `members` chỉ có người chọn được (`teamMembersProvider`).
    return withPickedMembers(
          members,
          _picked,
          ref.watch(teamMemberByIdProvider),
        )
        .where(
          (m) =>
              allowed == null ||
              allowed.contains(m.userId) ||
              _initial.contains(m.userId),
        )
        .where((m) => needle.isEmpty || m.name.toLowerCase().contains(needle))
        .toList();
  }
}

String _assigneeRoleLabel(TeamMember member) {
  final raw = member.roleLabel.trim();
  return switch (raw.toLowerCase()) {
    'admin' => 'Quản trị viên',
    'manager' => 'Quản lý',
    'employee' || 'member' || 'worker' => 'Nhân viên',
    'sale' || 'sales' => 'Kinh doanh',
    _ => raw,
  };
}
