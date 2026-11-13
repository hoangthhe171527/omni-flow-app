import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/channel_connection.dart';

/// Một kênh trong danh sách.
///
/// Trạng thái hiện bằng chữ kèm màu, không bằng màu suông — một chấm đỏ không
/// nói được "đang chờ ghép nối" khác "đăng nhập hỏng" ở chỗ nào, mà hai cái đó
/// cần hai hành động khác nhau.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.connection,
    required this.canWrite,
    required this.onReconnect,
    required this.onDisconnect,
    this.canReconnect,
  });

  final ChannelConnection connection;
  final bool canWrite;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

  /// Nút "Kết nối lại" riêng: kênh công ty nối lại qua OAuth chỉ cho admin.
  /// Null thì theo [canWrite].
  final bool? canReconnect;

  /// (nhãn, icon, sắc thái) cho mỗi trạng thái kênh.
  ///
  /// Icon không phải trang trí: bốn trạng thái này chỉ chênh nhau 1.04–1.20
  /// lần về độ sáng, nên chỉ nhìn màu thì không tách được.
  static const _statusLabels = {
    ChannelStatus.connected: (
      'Đang hoạt động',
      Icons.check_circle_rounded,
      OmniTone.success,
    ),
    ChannelStatus.error: (
      'Lỗi kết nối',
      Icons.error_outline_rounded,
      OmniTone.danger,
    ),
    ChannelStatus.pending: (
      'Đang chờ ghép nối',
      Icons.hourglass_top_rounded,
      OmniTone.warning,
    ),
    ChannelStatus.disconnected: (
      'Chưa kết nối',
      Icons.link_off_rounded,
      OmniTone.neutral,
    ),
  };

  bool get _needsReconnect =>
      connection.status == ChannelStatus.error ||
      connection.status == ChannelStatus.disconnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = connection.channel.meta;
    final (statusLabel, _, tone) =
        _statusLabels[connection.status] ??
        ('Chưa kết nối', Icons.link_off_rounded, OmniTone.neutral);

    // Một dòng của nhóm lồng (vạch thụt 54 do nhóm vẽ): icon kênh MỘT TÔNG,
    // tên, viên trạng thái + số tin, nút "Kết nối lại" kính nhỏ khi lỗi, và
    // menu ⋯ chứa "Ngắt kết nối" (không còn icon lặp ở từng dòng).
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: OmniIconTile(meta.icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                // Wrap chứ không Row: trên màn 360–390dp viên trạng thái dài
                // ("Đang chờ ghép nối") cộng số tin hôm nay không đủ một dòng.
                Wrap(
                  spacing: OmniSpacing.sm,
                  runSpacing: OmniSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(label: statusLabel, tone: tone),
                    Text(
                      '${connection.today} tin hôm nay',
                      style: OmniType.micro.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (_needsReconnect) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: (canReconnect ?? canWrite) ? onReconnect : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Kết nối lại'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canWrite) _MoreButton(onDisconnect: onDisconnect),
        ],
      ),
    );
  }
}

/// Nút ⋯ của dòng: mở menu neo, trong đó "Ngắt kết nối" (đỏ). Vẫn hỏi xác
/// nhận như cũ ở nơi gọi.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onDisconnect});

  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: 'Tuỳ chọn kênh',
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () async {
          final box = buttonContext.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final disconnect = await showOmniAnchoredMenu<bool>(
            context: buttonContext,
            anchor: box.localToGlobal(Offset.zero) & box.size,
            width: 220,
            menuKey: const Key('channel-row-menu'),
            semanticsLabel: 'Tuỳ chọn kênh',
            scrollable: false,
            builder: (menuContext) => OmniAnchoredMenuItem(
              icon: Icons.link_off_rounded,
              label: 'Ngắt kết nối',
              destructive: true,
              onTap: () => Navigator.of(menuContext).pop(true),
            ),
          );
          if (disconnect == true) onDisconnect();
        },
      ),
    );
  }
}

/// Trạng thái kênh: viên bo tròn cao 22 có chấm màu đứng trước chữ
/// (`MChannels.dc.html`). Chấm + chữ, không chỉ màu.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final OmniTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = tone.of(context);
    final dot = switch (tone) {
      OmniTone.success => Theme.of(context).colorScheme.primary,
      OmniTone.danger => OmniColors.destructive,
      OmniTone.warning => OmniColors.sla,
      _ => foreground,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
