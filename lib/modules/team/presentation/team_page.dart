import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../core/error/app_exception.dart';
import '../../../security/session/session_controller.dart';
// CHỈ tên route, không phải cả module công việc: `tasks` đã import `team`
// (sheet giao việc), nên một import ngược lại đóng vòng. `routes.dart` không
// import gì nên nó không nằm trong đồ thị — xem `module_cycle_test.dart`.
import '../../tasks/routes.dart';
import '../application/team_providers.dart';
import '../data/team_api.dart';
import '../domain/team_member.dart';
import '../domain/team_permissions.dart';
import 'add_member_sheet.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamDirectoryProvider);
    // Liên kết Zalo là thao tác của người có thẩm quyền — xem doc của
    // `TeamMember.zaloUserId`. Ai không có quyền thì thẻ chỉ đọc như cũ.
    final canLink = ref.watch(accessProvider).can('membership.members.update');
    // Xem tải việc của người khác nằm sau quyền giao việc (§7: xưởng không
    // công khai số liệu cá nhân). Cùng quyền mà route `tasks.workload` đòi —
    // kiểm ở đây để không bày ra một hàng người bấm vào là bị chặn.
    final canSeeLoad = ref
        .watch(accessProvider)
        .can('tasks.projects.manage.all');
    // Thêm người là việc của quản lý / admin; thợ không thấy nút.
    final canAdd = ref.watch(accessProvider).can(TeamPermissions.membersCreate);

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Nhân viên',
        actions: [
          if (canAdd)
            TextButton.icon(
              onPressed: () => showAddMemberSheet(context),
              icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              label: const Text('Thêm'),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () {
          ref.invalidate(teamMembersProvider);
          return ref.refresh(teamDirectoryProvider.future);
        },
        child: OmniAsyncView(
          // Danh bạ nạp cả người đã nghỉ (để tra tên trong lịch sử); màn này giữ
          // như trước: người đang làm, kể cả lời mời chưa nhận ("Đang chờ").
          value: members.whenData(
            (all) => all.where((m) => m.isActive).toList(),
          ),
          onRetry: () => ref.invalidate(teamDirectoryProvider),
          isEmpty: (list) => list.isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.group_outlined,
            title: 'Chưa có nhân viên',
            message: 'Mời đồng nghiệp vào workspace để bắt đầu phân công.',
          ),
          // Nền xám; cả danh sách là MỘT nhóm lồng, vạch chia thụt sau avatar.
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              OmniGroupSection.gap,
              16,
              OmniSpacing.bottomSafe,
            ),
            children: [
              OmniGroupSection(
                dividerIndent: 70,
                children: [
                  for (final member in list)
                    _MemberTile(
                      member: member,
                      canLink: canLink,
                      // Chạm vào một người là mở TẢI VIỆC của họ — câu hỏi
                      // quản đốc hỏi nhiều nhất khi đứng giữa xưởng. Liên kết
                      // Zalo lùi về một nút riêng bên phải.
                      onTap: canSeeLoad
                          ? () {
                              HapticFeedback.selectionClick();
                              context.pushNamed(
                                TaskRoutes.workload,
                                pathParameters: {'userId': member.userId},
                              );
                            }
                          : null,
                      onLinkZalo: () => _linkZalo(context, ref, member),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một người trong danh sách: avatar, tên, email, trạng thái Zalo, pill vai.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canLink,
    required this.onTap,
    required this.onLinkZalo,
  });

  final TeamMember member;
  final bool canLink;
  final VoidCallback? onTap;
  final VoidCallback onLinkZalo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Opacity(
          // Người đã nghỉ vẫn nằm trong danh sách nhưng lùi lại một bậc.
          opacity: member.isActive ? 1 : 0.7,
          child: Row(
            children: [
              OmniAvatar(
                name: member.name,
                imageUrl: member.avatarUrl,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: OmniType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (member.email != null)
                      Text(
                        member.email!,
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    // Nói ra ai đã liên kết Zalo: không có dòng này thì quản
                    // đốc phải mở từng người ra mới biết còn thiếu ai, và bot
                    // thì im lặng từ chối những người chưa liên kết.
                    if (canLink)
                      Text(
                        member.zaloUserId == null
                            ? 'Chưa liên kết Zalo'
                            : 'Zalo: ${member.zaloUserId}',
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                          fontStyle: member.zaloUserId == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Pill vai giữ viên thuốc nhạt, không tô đặc.
                    OmniBadge(
                      label: member.isPending
                          ? 'Đang chờ'
                          : member.isActive
                          ? member.roleLabel
                          : 'Ngừng hoạt động',
                      tone: member.isPending
                          ? OmniTone.warning
                          : member.isActive
                          ? OmniTone.info
                          : OmniTone.neutral,
                    ),
                  ],
                ),
              ),
              // Liên kết Zalo: nút kính tròn riêng, có nhãn, thay vì một cú
              // chạm vô hình lên cả dòng.
              if (canLink)
                OmniGlassCircle(
                  child: IconButton(
                    onPressed: onLinkZalo,
                    tooltip: member.zaloUserId == null
                        ? 'Liên kết Zalo — ${member.name}'
                        : 'Sửa liên kết Zalo — ${member.name}',
                    icon: Icon(
                      member.zaloUserId == null
                          ? Icons.link_off_rounded
                          : Icons.link_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liên kết (hoặc gỡ) tài khoản Zalo của một thành viên.
///
/// Đây là thao tác làm cho bot xưởng biết ai vừa nhắn trong nhóm (§G4). Bot cố
/// ý KHÔNG tự đoán: máy chạy nó nằm ở xưởng không ai trông và đang cầm sẵn
/// cookie của một tài khoản Zalo, nên nó phải dựa vào một liên kết mà người có
/// thẩm quyền tự tay tạo.
Future<void> _linkZalo(
  BuildContext context,
  WidgetRef ref,
  TeamMember member,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showOmniSheet<String>(
    context: context,
    builder: (context) => _LinkZaloSheet(member: member),
  );

  if (saved == null || saved == (member.zaloUserId ?? '')) return;

  try {
    await ref.read(teamApiProvider).setZaloUserId(member.membershipId, saved);
    ref.invalidate(teamDirectoryProvider);
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Sheet TỰ giữ controller của mình.
///
/// Bản đầu dựng controller ở chỗ gọi rồi `dispose()` ngay khi sheet trả về —
/// nhưng sheet còn đang chạy hoạt ảnh thoát và vẫn dựng lại TextField, nên nó
/// ném "A TextEditingController was used after being disposed". Vòng đời của
/// controller phải trùng vòng đời của widget dùng nó.
class _LinkZaloSheet extends StatefulWidget {
  const _LinkZaloSheet({required this.member});

  final TeamMember member;

  @override
  State<_LinkZaloSheet> createState() => _LinkZaloSheetState();
}

class _LinkZaloSheetState extends State<_LinkZaloSheet> {
  late final _controller = TextEditingController(
    text: widget.member.zaloUserId ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return OmniSheetBody(
      header: OmniSheetHeader(title: 'Liên kết Zalo — ${widget.member.name}'),
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: const Text('Lưu'),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Id Zalo của người này. Sau khi liên kết, tin họ nhắn trong nhóm '
            'xưởng sẽ được ghi nhận đúng tên. Để trống là gỡ liên kết.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ví dụ: 79000012345'),
        ),
      ],
    );
  }
}
