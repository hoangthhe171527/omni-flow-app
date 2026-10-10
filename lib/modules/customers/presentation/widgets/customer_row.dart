import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../../tasks/domain/task_permissions.dart';
import '../../../tasks/routes.dart';
import '../../../tasks/tasks.dart';
import '../../customers_module.dart';
import '../../domain/customer.dart';

/// Dòng khách gọn (`Customers.dc.html` `.row`): chấm nhãn ở mép trái, avatar
/// tròn 36, tên một dòng, "nguồn · lần liên hệ gần nhất". Chạm dòng mở hàng
/// thao tác nhanh ngay bên dưới; không có tiền ở bất kỳ đâu trên dòng.
class CustomerRow extends ConsumerWidget {
  const CustomerRow({
    super.key,
    required this.customer,
    required this.expanded,
    required this.onTap,
  });

  final Customer customer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final tag = customer.tags.isEmpty ? null : customer.tags.first;
    final inactive = customer.status == CustomerStatus.inactive;
    final last = Formatters.relative(customer.lastInteractionAt);
    final canCreateTask = ref.watch(accessProvider).can(TaskPermissions.write);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 9, 12, 9),
                  child: Row(
                    children: [
                      OmniAvatar(name: customer.name, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: inactive
                                        ? scheme.onSurfaceVariant
                                        : scheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: customer.source.sourceKind,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: customer.source.meta.textColorOf(
                                        brightness,
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' · ${last.isEmpty ? '—' : last}',
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OmniType.micro.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (tag != null)
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        label: 'Nhãn: $tag',
                        container: true,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: OmniLabelColors.of(tag),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Reveal(
            open: expanded,
            child: _QuickActions(
              customer: customer,
              canCreateTask: canCreateTask,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở/đóng hàng thao tác: trượt 380ms + hiện dần 300ms; giảm chuyển động thì
/// dựng thẳng (AnimatedSize thời lượng 0 vẫn chạy một lượt controller).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) {
      return open ? child : const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: open
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: child,
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.customer, required this.canCreateTask});

  final Customer customer;
  final bool canCreateTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phone = customer.phone.trim();

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _Action(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Nhắn',
              onTap: customer.hasPhone
                  ? () => launchWithToast(
                      context,
                      Uri.parse('https://zalo.me/${zaloNumber(phone)}'),
                      'Không mở được Zalo.',
                      mode: LaunchMode.externalApplication,
                    )
                  : null,
            ),
          ),
          Expanded(
            child: _Action(
              icon: Icons.call_outlined,
              label: 'Gọi',
              onTap: customer.hasPhone
                  ? () => launchWithToast(
                      context,
                      Uri(scheme: 'tel', path: dialNumber(phone)),
                      'Không mở được ứng dụng gọi điện.',
                    )
                  : null,
            ),
          ),
          if (canCreateTask)
            Expanded(
              child: _Action(
                icon: Icons.task_alt_rounded,
                label: 'Tạo việc',
                onTap: () => context.pushNamed(
                  TaskRoutes.create,
                  extra: CreateTaskArgs(
                    initialTitle: 'Liên hệ ${customer.name}',
                  ),
                ),
              ),
            ),
          Expanded(
            child: _Action(
              icon: Icons.person_outline_rounded,
              label: 'Hồ sơ',
              onTap: () => context.pushNamed(
                CustomersModule.detail,
                pathParameters: {'id': customer.id},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Số để quay: bỏ mọi ký tự không phải chữ số, giữ dấu `+` đứng đầu; tiền tố
/// quốc tế `00` đổi thành `+`.
String dialNumber(String raw) {
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (trimmed.startsWith('+')) return '+$digits';
  if (digits.startsWith('00')) return '+${digits.substring(2)}';
  return digits;
}

/// Số cho zalo.me: chỉ chữ số kèm mã nước, không `+`. Tiền tố quốc tế `00`
/// bỏ đi, đầu `0` trong nước → `84`, và `84 0…` (gõ thừa số 0 sau mã nước)
/// → `84…`.
String zaloNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = '84${digits.substring(1)}';
  }
  if (digits.startsWith('840')) digits = '84${digits.substring(3)}';
  return digits;
}

Future<void> launchWithToast(
  BuildContext context,
  Uri url,
  String failure, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(url, mode: mode);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(failure)));
}

/// Vòng 34 viền + nhãn 12 w600; `onTap` null = tắt (không số điện thoại).
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.onSurfaceVariant.withValues(alpha: .45)
        : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(icon, size: OmniIconSize.md, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
