import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../router/shell_routes.dart';
import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../security/session/session_controller.dart';

/// Danh bạ "Tất cả": hồ sơ người dùng, rồi MỌI tính năng họ có quyền dùng,
/// gom theo nhóm và tìm được bằng từ khoá.
///
/// Không có gì viết cứng theo module — module khai báo mục, registry lọc theo
/// quyền, màn này dựng bất cứ thứ gì nhận được. Một module ra mắt ngày mai xuất
/// hiện ở đây mà file này không đổi một dòng.
///
/// Đổi tên từ "Thêm": "Thêm" gợi ý phần thừa, trong khi đây là đường vào chính
/// của phần lớn tính năng.
class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final groups = _filtered(ref.watch(directoryGroupsProvider), _query);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              0,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            children: [
              OmniCard(
                child: Row(
                  children: [
                    OmniAvatar(
                      name: session.displayName,
                      imageUrl: session.user?.avatarUrl,
                      size: OmniIconSize.hero,
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.displayName,
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.roleLabel,
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              OmniCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.lg,
                  vertical: OmniSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.workspaces_outline,
                      size: OmniIconSize.lg,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Không gian làm việc',
                            style: OmniType.micro.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            session.tenant?.name ?? '—',
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const OmniSectionHeader(
                title: 'Hiển thị',
                padding: _headerPadding,
              ),
              OmniCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const _ThemeTile(),
                    const Divider(height: 1, indent: OmniSpacing.section),
                    _MenuTile(
                      icon: Icons.tab_rounded,
                      label: 'Chọn tab',
                      subtitle: 'Chọn 4 mục hiện ở thanh dưới',
                      onTap: () => context.pushNamed(ShellRoutes.pinTabs),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: OmniSpacing.lg),
                child: OmniSearchField(
                  hint: 'Tìm tính năng…',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),

              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: OmniSpacing.section),
                  child: OmniEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy',
                    message: 'Thử một từ khác, hoặc xoá ô tìm kiếm.',
                  ),
                ),

              for (final entry in groups.entries) ...[
                OmniSectionHeader(
                  title: entry.key.label,
                  padding: _headerPadding,
                ),
                OmniCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: OmniSpacing.section),
                        _MenuTile(
                          icon: entry.value[i].icon,
                          label: entry.value[i].label,
                          subtitle: entry.value[i].subtitle,
                          onTap: () =>
                              context.pushNamed(entry.value[i].routeName),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const OmniSectionHeader(
                title: 'Pháp lý & hỗ trợ',
                padding: _headerPadding,
              ),
              OmniCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Chính sách quyền riêng tư',
                      onTap: () =>
                          _openLink(context, AppConfig.privacyPolicyUrl),
                    ),
                    const Divider(height: 1, indent: OmniSpacing.section),
                    _MenuTile(
                      icon: Icons.support_agent_rounded,
                      label: 'Hỗ trợ',
                      subtitle: 'Liên hệ hỗ trợ và yêu cầu về dữ liệu',
                      onTap: () => _openLink(context, AppConfig.supportUrl),
                    ),
                  ],
                ),
              ),

              const OmniSectionHeader(
                title: 'Tài khoản',
                padding: _headerPadding,
              ),
              OmniCard(
                padding: EdgeInsets.zero,
                child: _MenuTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Xóa tài khoản',
                  subtitle: 'Vô hiệu hóa ngay và xóa dữ liệu trong vòng 7 ngày',
                  destructive: true,
                  onTap: () => _requestAccountDeletion(context, ref),
                ),
              ),

              const SizedBox(height: OmniSpacing.xxl),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Đăng xuất'),
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.xxl,
    bottom: OmniSpacing.md,
    left: OmniSpacing.xs,
  );

  Future<void> _openLink(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  Future<void> _requestAccountDeletion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .requestAccountDeletion(password: password);
    } on ValidationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập lại để tiếp tục làm việc.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final iconColor = destructive ? scheme.error : scheme.primary;
    final iconBackground = destructive
        ? scheme.errorContainer
        : scheme.primaryContainer;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: OmniRadius.smAll,
        ),
        child: Icon(icon, size: OmniIconSize.md, color: iconColor),
      ),
      title: Text(
        label,
        style: OmniType.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _confirmed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Không dùng showOmniConfirm: hộp thoại này có ô mật khẩu và một ô tick
    // xác nhận, tức là một biểu mẫu chứ không phải câu hỏi có/không. Đây cũng
    // đúng là chỗ nên bắt người dùng chậm lại — xoá tài khoản không được dễ
    // như bấm "Đồng ý".
    return AlertDialog(
      title: const Text('Xóa tài khoản?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tài khoản sẽ bị vô hiệu hóa ngay. Yêu cầu xóa tài khoản và dữ liệu cá nhân sẽ được hoàn tất trong vòng 7 ngày.',
            ),
            const SizedBox(height: OmniSpacing.lg),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                suffixIcon: IconButton(
                  // Nhãn nói cả trạng thái — xem login_page.dart.
                  tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: OmniSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi hiểu đây là yêu cầu xóa toàn bộ tài khoản, không phải tạm khóa.',
              ),
              onChanged: (value) => setState(() {
                _confirmed = value ?? false;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _confirmed && _password.text.isNotEmpty
              ? () => Navigator.pop(context, _password.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Xác nhận xóa'),
        ),
      ],
    );
  }
}

/// Light / dark / follow-the-system, matching what the web app offers.
///
/// A segmented control rather than a switch: "follow the system" is a real third
/// choice, and a two-state switch cannot express it — which is how apps end up
/// silently overriding the phone's own setting.
class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: OmniRadius.smAll,
            ),
            child: Icon(
              themeModeDisplay(mode).icon,
              size: OmniIconSize.md,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Text(
              'Giao diện',
              style: OmniType.caption.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: OmniType.micro,
            ),
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
                tooltip: 'Theo hệ thống',
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded, size: 16),
                tooltip: 'Sáng',
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 16),
                tooltip: 'Tối',
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}

/// Bỏ dấu để "kenh" tìm ra "Kết nối kênh".
///
/// Người dùng gõ trên bàn phím điện thoại, giữa lúc làm việc, và sẽ không bật
/// bộ gõ tiếng Việt lên chỉ để tìm một màn hình.
String foldDiacritics(String input) {
  // Hai chuỗi này phải khớp từng ký tự một. Lệch một là mọi chữ sau đó ánh xạ
  // sai — âm thầm, không lỗi, chỉ là tìm không ra. Nhóm theo nguyên âm để đếm
  // được bằng mắt: a×17, e×11, i×5, o×17, u×11, y×5, đ×1 = 67.
  const marks =
      'àáạảãâầấậẩẫăằắặẳẵ' // a
      'èéẹẻẽêềếệểễ' // e
      'ìíịỉĩ' // i
      'òóọỏõôồốộổỗơờớợởỡ' // o
      'ùúụủũưừứựửữ' // u
      'ỳýỵỷỹ' // y
      'đ';
  const plain =
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyy'
      'd';
  assert(
    marks.length == plain.length,
    'bảng bỏ dấu lệch: ${marks.length} vs ${plain.length}',
  );

  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = marks.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }

  return buffer.toString();
}

/// Một mục có khớp từ khoá không.
///
/// Khớp cả dòng phụ: người dùng nhớ "zalo" chứ không nhớ tính năng tên là
/// "Kết nối kênh".
bool matchesQuery({
  required String label,
  required String? subtitle,
  required String query,
}) {
  final needle = foldDiacritics(query.trim());
  if (needle.isEmpty) return true;

  return foldDiacritics(label).contains(needle) ||
      foldDiacritics(subtitle ?? '').contains(needle);
}

/// Lọc trước khi dựng, để nhóm không còn mục nào thì biến mất luôn cả tiêu đề —
/// một tiêu đề nhóm trống trông như lỗi tải dữ liệu.
Map<NavArea, List<ModuleNavEntry>> _filtered(
  Map<NavArea, List<ModuleNavEntry>> groups,
  String query,
) {
  final result = <NavArea, List<ModuleNavEntry>>{};
  for (final area in NavArea.values) {
    final kept = (groups[area] ?? const <ModuleNavEntry>[])
        .where(
          (entry) => matchesQuery(
            label: entry.label,
            subtitle: entry.subtitle,
            query: query,
          ),
        )
        .toList();
    if (kept.isNotEmpty) result[area] = kept;
  }

  return result;
}
