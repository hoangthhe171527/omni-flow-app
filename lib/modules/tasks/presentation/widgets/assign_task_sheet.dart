import 'package:flutter/material.dart';
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
}) => showOmniSheet<List<String>>(
  context: context,
  builder: (context) => _AssignTaskSheet(currentIds: currentIds),
);

class _AssignTaskSheet extends ConsumerStatefulWidget {
  const _AssignTaskSheet({required this.currentIds});

  final List<String> currentIds;

  @override
  ConsumerState<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<_AssignTaskSheet> {
  late final Set<String> _picked = {...widget.currentIds};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final members = ref.watch(teamMembersProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: Text(
            'Ai làm việc này',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
          child: OmniSearchField(
            hint: 'Tìm người...',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Flexible(
          child: OmniAsyncView(
            value: members,
            onRetry: () => ref.invalidate(teamMembersProvider),
            isEmpty: (rows) => _visible(rows).isEmpty,
            empty: const OmniEmptyState(
              icon: Icons.person_search_outlined,
              title: 'Không tìm thấy ai',
              message: 'Thử tên khác, hoặc xoá ô tìm kiếm.',
            ),
            data: (rows) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
              children: [
                for (final member in _visible(rows))
                  CheckboxListTile(
                    value: _picked.contains(member.userId),
                    onChanged: (on) => setState(() {
                      if (on ?? false) {
                        _picked.add(member.userId);
                      } else {
                        _picked.remove(member.userId);
                      }
                    }),
                    title: Text(member.name),
                    subtitle: Text(member.roleLabel),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_picked.toList()),
              // Nói ra số người đã chọn: bỏ chọn hết là một lựa chọn hợp lệ
              // (trả việc về hàng đợi chung), nên nút phải phân biệt được nó
              // với việc bấm nhầm.
              child: Text(
                _picked.isEmpty
                    ? 'Bỏ gán tất cả'
                    : 'Giao cho ${_picked.length} người',
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lọc theo ô tìm kiếm, và chỉ những người còn hoạt động.
  ///
  /// Giao việc cho một tài khoản đã ngừng hoạt động là giao vào chỗ không ai
  /// nhận — nhưng người ĐANG được gán vẫn hiện, để còn gỡ họ ra.
  List<TeamMember> _visible(List<TeamMember> members) {
    final needle = _search.trim().toLowerCase();

    return members
        .where((m) => m.isActive || _picked.contains(m.userId))
        .where((m) => needle.isEmpty || m.name.toLowerCase().contains(needle))
        .toList();
  }
}
