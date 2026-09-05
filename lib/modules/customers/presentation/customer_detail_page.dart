import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../opportunities/opportunities.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../domain/customer.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(customerId));
    final access = ref.watch(customerAccessProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khách hàng'),
        actions: [
          if (access.canUpdate)
            IconButton(
              tooltip: 'Sửa',
              onPressed: () => context.pushNamed(
                CustomersModule.edit,
                pathParameters: {'id': customerId},
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
        ],
      ),
      body: OmniAsyncView(
        value: customer,
        onRetry: () => ref.invalidate(customerProvider(customerId)),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.md,
            OmniSpacing.lg,
            OmniSpacing.bottomSafe,
          ),
          children: [
            _Header(customer: data),
            const SizedBox(height: OmniSpacing.xl),
            _QuickActions(customer: data),
            const OmniSectionHeader(title: 'Chỉ số', padding: _headerPadding),
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
            OmniCard(
              child: Column(
                children: [
                  OmniDetailRow(
                    label: 'Người liên hệ',
                    value: data.contactName.isEmpty ? '—' : data.contactName,
                    icon: Icons.person_outline_rounded,
                  ),
                  OmniDetailRow(
                    label: 'Điện thoại',
                    value: data.phone.isEmpty ? '—' : data.phone,
                    icon: Icons.call_outlined,
                    onTap: data.hasPhone
                        ? () => launchUrl(Uri.parse('tel:${data.phone}'))
                        : null,
                  ),
                  OmniDetailRow(
                    label: 'Email',
                    value: data.email.isEmpty ? '—' : data.email,
                    icon: Icons.mail_outline_rounded,
                    onTap: data.hasEmail
                        ? () => launchUrl(Uri.parse('mailto:${data.email}'))
                        : null,
                  ),
                  OmniDetailRow(
                    label: 'Địa chỉ',
                    value: data.address.isEmpty ? '—' : data.address,
                    icon: Icons.location_on_outlined,
                  ),
                  if (data.taxCode.isNotEmpty)
                    OmniDetailRow(
                      label: 'Mã số thuế',
                      value: data.taxCode,
                      icon: Icons.receipt_long_outlined,
                    ),
                  OmniDetailRow(
                    label: 'Phụ trách',
                    value: data.ownerName ?? 'Chưa gán',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
            ),
            if (data.tags.isNotEmpty) ...[
              const OmniSectionHeader(title: 'Nhãn', padding: _headerPadding),
              Wrap(
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                children: [for (final tag in data.tags) OmniTag(label: tag)],
              ),
            ],
            if (data.note != null && data.note!.isNotEmpty) ...[
              const OmniSectionHeader(
                title: 'Ghi chú',
                padding: _headerPadding,
              ),
              OmniCard(child: Text(data.note!, style: OmniType.body)),
            ],
          ],
        ),
      ),
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.xxl,
    bottom: OmniSpacing.md,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        OmniAvatar(name: customer.name, size: 64),
        const SizedBox(width: OmniSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: OmniType.title.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: OmniSpacing.xs),
              Row(
                children: [
                  OmniStatusChip(
                    label: customer.status.label,
                    tone: switch (customer.status) {
                      CustomerStatus.vip => OmniTone.warning,
                      CustomerStatus.active => OmniTone.success,
                      CustomerStatus.inactive => OmniTone.neutral,
                      CustomerStatus.fresh => OmniTone.info,
                    },
                  ),
                  if (customer.code.isNotEmpty) ...[
                    const SizedBox(width: OmniSpacing.sm),
                    Text(
                      customer.code,
                      style: OmniType.micro.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
            enabled: customer.hasPhone,
            onTap: () => launchUrl(Uri.parse('tel:${customer.phone}')),
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Nhắn Zalo',
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
            onTap: () => context.pushNamed(
              OpportunitiesModule.create,
              queryParameters: {'customer': customer.id},
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled ? scheme.primary : scheme.onSurfaceVariant;

    return OmniCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 5),
          Text(label, style: OmniType.micro.copyWith(color: color)),
        ],
      ),
    );
  }
}
