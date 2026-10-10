import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

/// Cảm xúc NỘI BỘ của đội dưới một bong bóng (`team_reactions`): viên bo 9,
/// gom theo emoji theo thứ tự xuất hiện ("❤️", "❤️ 2"). Viên có cảm xúc của
/// tôi viền màu chính.
///
/// Cố ý khác hẳn cảm xúc của KHÁCH (vòng tròn ở góc bong bóng): viên nằm DƯỚI
/// bong bóng, có số đếm, và trình đọc màn hình đọc "Cảm xúc nội bộ: …". Không
/// bao giờ gửi ra nền tảng.
///
/// Chạm cả hàng mở sheet chỉ đọc liệt kê ai đã thả gì. Tên lấy theo `user_id`
/// trong [memberNames] (danh bạ đội, khi đã nạp) trước, rồi mới tới tên server
/// chụp lại lúc thả (có thể đã cũ), cuối cùng là "Thành viên".
class TeamReactionChips extends StatelessWidget {
  const TeamReactionChips({
    super.key,
    required this.reactions,
    this.myUserId,
    this.memberNames = const {},
    this.alignEnd = false,
    this.lift = true,
  });

  final List<TeamReaction> reactions;
  final String? myUserId;
  final Map<String, String> memberNames;

  /// Tin đi: viên nằm sát mép phải như bong bóng.
  final bool alignEnd;

  /// Kéo viên lên đè mép dưới bong bóng 6px như bản mẫu. Tắt khi tin có cảm
  /// xúc của khách ở góc — hai thứ không được chồng lên nhau.
  final bool lift;

  /// Tách ra để tái dùng trong sheet và Semantics.
  static String nameOf(TeamReaction r, Map<String, String> memberNames) {
    final fromDirectory = memberNames[r.userId];
    if (fromDirectory != null && fromDirectory.trim().isNotEmpty) {
      return fromDirectory;
    }
    final snapshot = r.userName;
    if (snapshot != null && snapshot.trim().isNotEmpty) return snapshot;
    return 'Thành viên';
  }

  Map<String, List<TeamReaction>> get _groups {
    final groups = <String, List<TeamReaction>>{};
    for (final r in reactions) {
      if (r.emoji.isEmpty) continue;
      groups.putIfAbsent(r.emoji, () => []).add(r);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final label =
        'Cảm xúc nội bộ: '
        '${[for (final e in groups.entries) '${e.key} ${e.value.map((r) => nameOf(r, memberNames)).join(', ')}'].join('; ')}';

    final chips = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final entry in groups.entries)
          Container(
            key: ValueKey('team-reaction-${entry.key}'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: entry.value.any((r) => r.userId == myUserId)
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
            child: Text(
              entry.value.length == 1
                  ? entry.key
                  : '${entry.key} ${entry.value.length}',
              style: OmniChatType.reactionChip.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('team-reactions-tap'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showTeamReactorsSheet(
          context,
          reactions: reactions,
          memberNames: memberNames,
        ),
        // Viên chỉ cao ~20 nhưng vùng chạm phải đủ 44.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Align(
            alignment: alignEnd ? Alignment.topRight : Alignment.topLeft,
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: lift
                  ? Transform.translate(
                      offset: const Offset(0, -6),
                      child: chips,
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: chips,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet chỉ đọc: "emoji · tên" của từng người đã thả.
Future<void> showTeamReactorsSheet(
  BuildContext context, {
  required List<TeamReaction> reactions,
  Map<String, String> memberNames = const {},
}) {
  return showOmniSheet<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cảm xúc nội bộ',
                style: OmniType.section.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                'Chỉ đội thấy, không gửi cho khách.',
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in reactions)
                      if (r.emoji.isNotEmpty)
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  r.emoji,
                                  style: OmniChatType.reaction,
                                ),
                              ),
                              const SizedBox(width: OmniSpacing.sm),
                              Expanded(
                                child: Text(
                                  TeamReactionChips.nameOf(r, memberNames),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
