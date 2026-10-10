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
}) {
  return showModalBottomSheet<({String? id, String? name})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OwnerPickerSheet(currentId: currentId),
  );
}

class _OwnerPickerSheet extends ConsumerStatefulWidget {
  const _OwnerPickerSheet({required this.currentId});

  final String? currentId;

  @override
  ConsumerState<_OwnerPickerSheet> createState() => _OwnerPickerSheetState();
}

class _OwnerPickerSheetState extends ConsumerState<_OwnerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                0,
                OmniSpacing.lg,
                OmniSpacing.sm,
              ),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tìm người',
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            if (widget.currentId != null)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Bỏ gán'),
                onTap: () => Navigator.of(context).pop((id: null, name: null)),
              ),
            Flexible(
              child: members.when(
                data: (all) {
                  final shown = [
                    for (final m in all)
                      if (_query.isEmpty ||
                          m.name.toLowerCase().contains(_query))
                        m,
                  ];
                  if (shown.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(OmniSpacing.xxl),
                      child: Text(
                        _query.isEmpty
                            ? 'Chưa có ai trong workspace'
                            : 'Không tìm thấy ai',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final member = shown[i];
                      final current = member.userId == widget.currentId;
                      return ListTile(
                        minTileHeight: 48,
                        leading: OmniAvatar(
                          name: member.name,
                          imageUrl: member.avatarUrl,
                          size: 36,
                        ),
                        title: Text(member.name),
                        trailing: current
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.of(
                          context,
                        ).pop((id: member.userId, name: member.name)),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(OmniSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Thiếu `membership.members.read` cũng rơi vào đây: báo một
                // câu, không có mục nào để chọn nhầm.
                error: (e, _) => const Padding(
                  padding: EdgeInsets.all(OmniSpacing.xxl),
                  child: Text(
                    'Không tải được danh sách thành viên',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
