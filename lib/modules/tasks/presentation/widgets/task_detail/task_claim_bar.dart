import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// "Nhận việc này" — người thợ tự thêm mình vào một việc chưa nhận.
///
/// Cố ý KHÔNG mở bộ chọn người: nó chỉ gửi đúng một id, id của chính người
/// đang bấm. Bộ chọn người lấy danh sách từ `GET /memberships`, đường cần
/// `membership.members.read` — quyền mà vai `worker` cố ý không có, nên với
/// đúng người cần tự nhận thì bộ chọn đó luôn rỗng. Gán NGƯỜI KHÁC vẫn là
/// việc của quản đốc, và vẫn nằm trong bảng điều phối.
class TaskClaimBar extends StatefulWidget {
  const TaskClaimBar({super.key, required this.onClaim});

  final Future<void> Function() onClaim;

  @override
  State<TaskClaimBar> createState() => _TaskClaimBarState();
}

class _TaskClaimBarState extends State<TaskClaimBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _claim,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Nhận việc này'),
        ),
      ),
    );
  }

  /// Khoá nút trong lúc gửi: hai lần chạm liên tiếp là hai lượt ghi, và lượt
  /// sau mang theo bản chụp cũ nên nó nhân đôi id của mình trong danh sách.
  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await widget.onClaim();
    } finally {
      // Nhận xong thì widget này biến mất cùng lần dựng lại, nên chỉ đường
      // THẤT BẠI mới thật sự cần mở khoá.
      if (mounted) setState(() => _busy = false);
    }
  }
}
