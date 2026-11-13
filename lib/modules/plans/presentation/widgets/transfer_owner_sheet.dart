import 'package:flutter/material.dart';
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

    return OmniSheetBody(
      semanticsLabel: 'Chuyển chủ kế hoạch',
      header: OmniSheetHeader(
        title: 'Chuyển chủ kế hoạch',
        subtitle: 'Chọn thành viên đang làm việc để nhận quyền chủ',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      children: [
        OmniSearchField(
          hint: 'Tìm người...',
          onChanged: (value) => setState(() => _query = value),
        ),
        OmniAsyncView(
          value: members,
          loading: const Padding(
            padding: EdgeInsets.all(OmniSpacing.xxl),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          onRetry: () => ref.invalidate(teamDirectoryProvider),
          isEmpty: (rows) => _visible(rows).isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Không có ai để chọn',
            message: 'Chủ mới phải là thành viên đang làm của workspace.',
          ),
          data: (rows) => OmniGroupSection(
            dividerIndent: 62,
            children: [
              for (final m in _visible(rows))
                OmniGroupRow(
                  key: ValueKey('owner-${m.userId}'),
                  leading: OmniAvatar(
                    name: m.name,
                    imageUrl: m.avatarUrl,
                    size: 36,
                  ),
                  title: m.name,
                  subtitle: m.jobTitle,
                  maxTitleLines: 2,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(m),
                ),
            ],
          ),
        ),
      ],
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
