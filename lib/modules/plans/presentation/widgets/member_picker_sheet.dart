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
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tìm người',
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Flexible(
              child: members.when(
                data: (all) {
                  final shown = _query.isEmpty
                      ? all
                      : all
                            .where((m) => m.name.toLowerCase().contains(_query))
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

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final member = shown[i];
                      final on = _selected.contains(member.userId);

                      return CheckboxListTile(
                        value: on,
                        secondary: OmniAvatar(
                          name: member.name,
                          imageUrl: member.avatarUrl,
                          size: 36,
                        ),
                        title: Text(member.name),
                        subtitle: member.jobTitle == null
                            ? null
                            : Text(member.jobTitle!),
                        onChanged: (_) => setState(() {
                          if (on) {
                            _selected.remove(member.userId);
                          } else {
                            _selected.add(member.userId);
                          }
                        }),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(OmniSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => OmniErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(teamMembersProvider),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text('Xong (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
