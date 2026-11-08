import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/text_search.dart';
import '../../../../design/components/components.dart';
import '../../../team/team.dart';

/// Chọn chủ mới cho kế hoạch (Nhóm 2). Trả người đã chọn, hoặc null khi đóng.
///
/// Danh sách là thành viên ĐANG LÀM của workspace (`teamMembersProvider`) —
/// đúng điều kiện server kiểm (`activeUserIdsIn`, sai thì 422). Chủ hiện tại
/// không có trong danh sách. Chạm một người là chọn; hỏi lại ở chỗ gọi.
Future<TeamMember?> showTransferOwnerSheet(
  BuildContext context, {
  required String? currentOwnerId,
}) => showOmniSheet<TeamMember>(
  context: context,
  builder: (_) => _TransferOwnerSheet(currentOwnerId: currentOwnerId),
);

class _TransferOwnerSheet extends ConsumerStatefulWidget {
  const _TransferOwnerSheet({required this.currentOwnerId});

  final String? currentOwnerId;

  @override
  ConsumerState<_TransferOwnerSheet> createState() =>
      _TransferOwnerSheetState();
}

class _TransferOwnerSheetState extends ConsumerState<_TransferOwnerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Chuyển chủ kế hoạch',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const OmniSheetHeader(title: 'Chuyển chủ kế hoạch'),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: OmniSearchField(
              hint: 'Tìm người...',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Flexible(
            child: OmniAsyncView(
              value: members,
              onRetry: () => ref.invalidate(teamDirectoryProvider),
              isEmpty: (rows) => _visible(rows).isEmpty,
              empty: const OmniEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Không có ai để chọn',
                message: 'Chủ mới phải là thành viên đang làm của workspace.',
              ),
              data: (rows) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  OmniGroupSection(
                    dividerIndent: 56,
                    children: [
                      for (final m in _visible(rows))
                        OmniGroupRow(
                          key: ValueKey('owner-${m.userId}'),
                          leading: OmniAvatar(
                            name: m.name,
                            imageUrl: m.avatarUrl,
                            size: 30,
                          ),
                          title: m.name,
                          maxTitleLines: 1,
                          chevron: false,
                          onTap: () => Navigator.of(context).pop(m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TeamMember> _visible(List<TeamMember> rows) {
    final needle = foldDiacritics(_query.trim());

    return [
      for (final m in rows)
        if (m.userId != widget.currentOwnerId &&
            (needle.isEmpty || foldDiacritics(m.name).contains(needle)))
          m,
    ];
  }
}
