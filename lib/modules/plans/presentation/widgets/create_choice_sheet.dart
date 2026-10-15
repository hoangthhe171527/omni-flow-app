import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';

/// Hai thứ tạo được từ gốc tab Việc.
enum CreateChoice { team, plan }

/// Menu của nút + (`TeamsAdd.dc.html`): lớp phủ mờ, hộp 220 bo 8 bật xuống
/// ngay dưới nút, neo theo mép phải của nút ([anchor], toạ độ màn).
///
/// "Tạo team" chỉ có khi [canCreateTeam]: tạo team LÀ tạo một đơn vị trong cơ
/// cấu tổ chức, API đòi quyền org tương ứng, và bày ra một dòng bấm vào là 403
/// tệ hơn không bày.
///
/// Lớp phủ `fade` 200ms, hộp `pop` 280ms gốc trên-phải. Giảm chuyển động: hiện
/// và tắt ngay.
Future<CreateChoice?> showCreateMenu(
  BuildContext context, {
  required Rect anchor,
  required bool canCreateTeam,
}) {
  return showOmniAnchoredMenu<CreateChoice>(
    context: context,
    anchor: anchor,
    menuKey: const Key('create-menu'),
    semanticsLabel: 'Tạo mới',
    builder: (_) => _CreateMenu(canCreateTeam: canCreateTeam),
  );
}

class _CreateMenu extends StatelessWidget {
  const _CreateMenu({required this.canCreateTeam});

  final bool canCreateTeam;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canCreateTeam)
          OmniAnchoredMenuItem(
            icon: Icons.person_add_alt_outlined,
            label: 'Tạo team',
            onTap: () => Navigator.of(context).pop(CreateChoice.team),
          ),
        OmniAnchoredMenuItem(
          icon: Icons.view_kanban_outlined,
          label: 'Tạo kế hoạch',
          divider: canCreateTeam,
          onTap: () => Navigator.of(context).pop(CreateChoice.plan),
        ),
      ],
    );
  }
}
