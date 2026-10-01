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
  });

  final ChannelConnection connection;
  final bool canWrite;
  final VoidCallback onReconnect;
  final VoidCallback onDisconnect;

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

    return OmniCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: meta.tint,
              borderRadius: OmniRadius.mdAll,
            ),
            child: Icon(meta.icon, size: OmniIconSize.lg, color: meta.color),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.label,
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
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
                  TextButton.icon(
                    onPressed: canWrite ? onReconnect : null,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Kết nối lại'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: canWrite ? onDisconnect : null,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Ngắt kết nối',
          ),
        ],
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
