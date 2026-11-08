import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/application/team_providers.dart';

/// Chọn người phụ trách khách. Trả về `null` khi đóng mà không đổi gì;
/// `(id: null, name: null)` là "Bỏ gán".
///
/// `id` LUÔN là `TeamMember.userId` — máy chủ (`ActiveTenantSalesRep`) kiểm
/// `User.id`; `membershipId` sẽ bị 422 hoặc, tệ hơn, ghi sai người.
Future<({String? id, String? name})?> showOwnerPicker(
  BuildContext context, {
  String? currentId,
  String? currentName,
}) {
  return showOmniSheet<({String? id, String? name})>(
    context: context,
    builder: (_) =>
        _OwnerPickerSheet(currentId: currentId, currentName: currentName),
  );
}

class _OwnerPickerSheet extends ConsumerStatefulWidget {
  const _OwnerPickerSheet({required this.currentId, this.currentName});

  final String? currentId;
  final String? currentName;

  @override
  ConsumerState<_OwnerPickerSheet> createState() => _OwnerPickerSheetState();
}

class _OwnerPickerSheetState extends ConsumerState<_OwnerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);
    final scheme = Theme.of(context).colorScheme;
    final hasCurrent =
        widget.currentId != null ||
        (widget.currentName?.trim().isNotEmpty ?? false);

    Widget message(String text) => Padding(
      padding: const EdgeInsets.all(OmniSpacing.xxl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
      ),
    );

    return OmniSheetBody(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: TextField(
          style: OmniType.search.copyWith(
            color: scheme.onSurface,
            fontStyle: FontStyle.normal,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Tìm người',
            hintStyle: OmniType.searchHint.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
      ),
      children: [
        members.when(
          data: (all) {
            final shown = [
              for (final m in all)
                if (_query.isEmpty || m.name.toLowerCase().contains(_query)) m,
            ];
            return OmniGroupSection(
              dividerIndent: 62,
              children: [
                if (hasCurrent)
                  OmniGroupRow(
                    icon: Icons.person_off_outlined,
                    title: 'Bỏ gán',
                    onTap: () =>
                        Navigator.of(context).pop((id: null, name: null)),
                  ),
                for (final member in shown)
                  OmniGroupRow(
                    leading: OmniAvatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      size: 36,
                    ),
                    title: member.name,
                    selected: member.userId == widget.currentId,
                    onTap: () => Navigator.of(
                      context,
                    ).pop((id: member.userId, name: member.name)),
                  ),
                if (shown.isEmpty)
                  message(
                    _query.isEmpty
                        ? 'Chưa có ai trong workspace'
                        : 'Không tìm thấy ai',
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(OmniSpacing.xxl),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          // Thiếu `membership.members.read` cũng rơi vào đây: báo một
          // câu, không có mục nào để chọn nhầm.
          error: (e, _) => message('Không tải được danh sách thành viên'),
        ),
      ],
    );
  }
}
