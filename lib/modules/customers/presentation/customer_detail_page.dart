import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
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
                        ),
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: OmniStatTile(
                          label: 'Tương tác',
                          value: data.lastInteractionAt == null
                              ? '—'
                              : Formatters.relative(data.lastInteractionAt),
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

    // `SMCustomerDetail.dc.html`: avatar trung tính 56, tên 20/600, VIP là
    // chip hổ phách bo 4 có icon sao.
    return Row(
      children: [
        OmniAvatar(name: customer.name, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: OmniType.title.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (badge != null) ...[badge, const SizedBox(width: 8)],
                  if (customer.code.isNotEmpty)
                    Text(
                      customer.code,
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: OmniType.tabular,
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

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Workspace tắt module Cơ hội thì không mời tạo (API trả 403
    // FEATURE_DISABLED) — MS-I33.
    final opportunitiesOn = ref
        .watch(sessionProvider)
        .featureEnabled('opportunities');
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
            // Zalo giữ màu thương hiệu của nó — chỉ ở icon, không ở nền.
            iconColor: Channel.zalo.meta.color,
            enabled: customer.hasPhone,
            onTap: () => launchUrl(
              Uri.parse('https://zalo.me/${customer.phone}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        if (opportunitiesOn) ...[
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: _ActionTile(
              icon: Icons.trending_up_rounded,
              label: 'Tạo cơ hội',
              onTap: () => context.pushNamed(
                OpportunityRoutes.create,
                queryParameters: {'customer': customer.id},
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ba nút nhanh CÙNG một kiểu: nền trắng, viền #C9D2DE, icon màu chính, chữ
/// mực. Bản cũ tô ba nền khác nhau (teal nhạt, xanh nhạt, xám) — ba giọng
/// màu cho ba nút ngang hàng. Ô tắt (khách chưa có số) mờ đi chứ không biến
/// mất.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: OmniRadius.mdAll,
          side: BorderSide(color: OmniColors.controlBorderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: OmniIconSize.lg,
                  color: iconColor ?? scheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.chip.copyWith(color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn khách: ô trắng viền #C9D2DE bo 6, cao 30.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.chipAll,
        border: Border.all(color: OmniColors.controlBorderOf(context)),
      ),
      child: Text(
        text,
        style: OmniType.chip.copyWith(
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// Ghi chú về khách: thẻ trắng như mọi nhóm khác trên màn. Nền vàng giấy nhớ
/// là trang trí — và vàng trong app chỉ được nói "có cái mới".
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return OmniCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: OmniType.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
