import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/application/team_providers.dart';

/// Chọn ai vào team. Trả về null khi đóng mà không đổi gì.
///
/// Danh bạ cần `membership.members.read`; tạo team đã đòi
/// `organization.org_units.create`. Vai `manager` trong `SystemRolePresets` có
/// CẢ HAI (kiểm 2026-09-10), nên ai bấm được "Tạo team" thì cũng mở được sheet
/// này.
///
/// Nhưng vai là thứ từng workspace tự cấu hình được, nên sheet vẫn phải chịu
/// được một danh sách rỗng hoặc một lỗi quyền mà không vỡ — xem nhánh `error`.
Future<Set<String>?> showMemberPicker(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showOmniSheet<Set<String>>(
    context: context,
    builder: (_) => _MemberPickerSheet(initial: selected),
  );
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  const _MemberPickerSheet({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Chọn thành viên',
        subtitle: _selected.isEmpty
            ? 'Chạm để chọn người tham gia'
            : 'Đã chọn ${_selected.length} người',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: Text(
          'Xong (${_selected.length})',
          style: const TextStyle(fontFeatures: OmniType.tabular),
        ),
      ),
      children: [
        OmniSearchField(
          hint: 'Tìm người',
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        members.when(
          data: (all) {
            // `all` chỉ có người chọn được (APP-I10); người đã chọn
            // sẵn mà nay không chọn được vẫn hiện để còn bỏ chọn.
            final shown =
                withPickedMembers(
                      all,
                      _selected,
                      ref.watch(teamMemberByIdProvider),
                    )
                    .where(
                      (m) =>
                          _query.isEmpty ||
                          m.name.toLowerCase().contains(_query),
                    )
                    .toList();

            if (shown.isEmpty) {
              return OmniEmptyState(
                icon: Icons.person_search_rounded,
                title: _query.isEmpty
                    ? 'Chưa có ai trong workspace'
                    : 'Không tìm thấy ai',
                message: _query.isEmpty
                    ? 'Mời người vào workspace trước, rồi quay lại đây.'
                    : 'Thử một cái tên khác.',
              );
            }

            return OmniGroupSection(
              dividerIndent: 62,
              children: [
                for (final member in shown)
                  OmniGroupRow(
                    leading: OmniAvatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      size: 36,
                    ),
                    title: member.name,
                    subtitle: member.jobTitle,
                    selected: _selected.contains(member.userId),
                    chevron: false,
                    onTap: () => setState(() {
                      if (!_selected.remove(member.userId)) {
                        _selected.add(member.userId);
                      }
                    }),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(OmniSpacing.xxl),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (e, _) => OmniErrorView(
            error: e,
            onRetry: () => ref.invalidate(teamDirectoryProvider),
          ),
        ),
      ],
    );
  }
}
