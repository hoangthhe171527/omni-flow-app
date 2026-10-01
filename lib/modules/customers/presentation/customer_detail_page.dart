import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../opportunities/routes.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../domain/customer.dart';
import 'customers_page.dart';

/// Hồ sơ khách theo `MCustomerDetail.dc.html`: khối trắng phía trên (ảnh,
/// tên, huy hiệu, ba nút hành động), rồi trên nền xám là ba ô số liệu, thông
/// tin liên hệ, nhãn và ghi chú.
class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(customerId));
    final access = ref.watch(customerAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Chi tiết khách hàng'),
        actions: [
          if (access.canUpdate)
            TextButton(
              onPressed: () => context.pushNamed(
                CustomersModule.edit,
                pathParameters: {'id': customerId},
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Sửa'),
            ),
        ],
      ),
      body: OmniAsyncView(
        value: customer,
        onRetry: () => ref.invalidate(customerProvider(customerId)),
        data: (data) => ListView(
          padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  _Header(customer: data),
                  const SizedBox(height: OmniSpacing.lg),
                  _QuickActions(customer: data),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OmniStatTile(
                          label: 'Tổng giá trị',
                          value: Formatters.vndCompact(data.lifetimeValue),
                        ),
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: OmniStatTile(
                          label: 'Nguồn',
                          value: data.source.meta.short,
                          tone: data.source.meta.color,
                        ),
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: OmniStatTile(
                          label: 'Tương tác',
                          value: Formatters.relative(data.lastInteractionAt),
                        ),
                      ),
                    ],
                  ),
                  const OmniSectionHeader(
                    title: 'Thông tin liên hệ',
                    padding: _headerPadding,
                  ),
                  OmniDetailCard(
                    rows: [
                      OmniDetailRow(
                        label: 'Người liên hệ',
                        value: data.contactName.isEmpty
                            ? '—'
                            : data.contactName,
                      ),
                      OmniDetailRow(
                        label: 'Điện thoại',
                        value: data.phone.isEmpty ? '—' : data.phone,
                        onTap: data.hasPhone
                            ? () => launchUrl(Uri.parse('tel:${data.phone}'))
                            : null,
                      ),
                      OmniDetailRow(
                        label: 'Email',
                        value: data.email.isEmpty ? '—' : data.email,
                        onTap: data.hasEmail
                            ? () => launchUrl(Uri.parse('mailto:${data.email}'))
                            : null,
                      ),
                      OmniDetailRow(
                        label: 'Địa chỉ',
                        value: data.address.isEmpty ? '—' : data.address,
                      ),
                      if (data.taxCode.isNotEmpty)
                        OmniDetailRow(label: 'Mã số thuế', value: data.taxCode),
                      OmniDetailRow(
                        label: 'Phụ trách',
                        value: data.ownerName ?? 'Chưa gán',
                        strong: data.ownerName != null,
                      ),
                    ],
                  ),
                  if (data.tags.isNotEmpty) ...[
                    const OmniSectionHeader(
                      title: 'Nhãn',
                      padding: _headerPadding,
                    ),
                    Wrap(
                      spacing: OmniSpacing.sm,
                      runSpacing: OmniSpacing.sm,
                      children: [for (final tag in data.tags) _Label(tag)],
                    ),
                  ],
                  if (data.note != null && data.note!.isNotEmpty) ...[
                    const OmniSectionHeader(
                      title: 'Ghi chú',
                      padding: _headerPadding,
                    ),
                    _Note(text: data.note!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.lg,
    bottom: OmniSpacing.sm,
    left: OmniSpacing.xs,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = customerStatusBadge(customer.status, large: true);

    return Row(
      children: [
        OmniAvatar(name: customer.name, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: OmniType.title.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.22,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (badge != null) ...[badge, const SizedBox(width: 8)],
                  if (customer.code.isNotEmpty)
                    Text(
                      customer.code,
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.call_outlined,
            label: 'Gọi',
            tone: OmniTone.success,
            enabled: customer.hasPhone,
            onTap: () => launchUrl(Uri.parse('tel:${customer.phone}')),
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Nhắn Zalo',
            tone: OmniTone.info,
            enabled: customer.hasPhone,
            onTap: () => launchUrl(
              Uri.parse('https://zalo.me/${customer.phone}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.trending_up_rounded,
            label: 'Tạo cơ hội',
            tone: OmniTone.neutral,
            onTap: () => context.pushNamed(
              OpportunityRoutes.create,
              queryParameters: {'customer': customer.id},
            ),
          ),
        ),
      ],
    );
  }
}

/// Ô hành động tô màu theo giọng: gọi mòng két, nhắn xanh dương, tạo cơ hội
/// xám. Ô tắt (khách chưa có số) mờ đi chứ không biến mất.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final OmniTone tone;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    var (foreground, background) = tone.of(context);
    if (tone == OmniTone.neutral) {
      foreground = Theme.of(context).colorScheme.onSurface;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: OmniRadius.lgAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: OmniRadius.lgAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, size: OmniIconSize.lg, color: foreground),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn khách: viên trắng viền mảnh bo 8.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.chipAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: OmniType.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// Ghi chú về khách: nền vàng giấy như ghi chú nội bộ ở hộp thư.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? OmniColors.darkWarningSoft : OmniColors.noteSurface,
        borderRadius: OmniRadius.xlAll,
        border: Border.all(
          color: dark
              ? OmniColors.warningTextDark.withValues(alpha: 0.4)
              : OmniColors.noteBorder,
        ),
      ),
      child: Text(
        text,
        style: OmniType.bodyStrong.copyWith(
          fontWeight: FontWeight.w400,
          height: 22 / 15,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
