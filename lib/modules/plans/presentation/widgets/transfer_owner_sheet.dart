import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/text_search.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';

/// Chọn chủ mới cho kế hoạch (Nhóm 2). Trả người đã chọn, hoặc null khi đóng.
///
/// Danh sách là thành viên ĐANG LÀM của workspace (`teamMembersProvider`) —
/// đúng điều kiện server kiểm (`activeUserIdsIn`, sai thì 422). Chủ hiện tại
/// không có trong danh sách. Chạm một người là chọn; hỏi lại ở chỗ gọi.
Future<TeamMember?> showTransferOwnerSheet(
  BuildContext context, {
  required String? currentOwnerId,
}) => showOmniViecSheet<TeamMember>(
  context: context,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final scheme = Theme.of(context).colorScheme;
    final members = ref.watch(teamMembersProvider);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Chuyển chủ kế hoạch',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmniSheetHandle(gap: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4),
              child: Text(
                'Chuyển chủ kế hoạch',
                style: OmniType.section.copyWith(color: scheme.onSurface),
              ),
            ),
            OmniSearchField(
              hint: 'Tìm người...',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
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
                data: (rows) => Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      for (final m in _visible(rows))
                        InkWell(
                          key: ValueKey('owner-${m.userId}'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop(m);
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 50),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  OmniAvatar(
                                    name: m.name,
                                    imageUrl: m.avatarUrl,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OmniType.body.copyWith(
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
