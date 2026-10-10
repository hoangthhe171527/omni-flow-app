import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../core/module/customer_opportunities_section.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/session/session_controller.dart';
import '../../opportunities/routes.dart';
import '../../tasks/domain/task_permissions.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
import '../application/customer_editor.dart';
import '../application/customers_providers.dart';
import '../domain/customer.dart';
import '../domain/customer_field.dart';
import '../routes.dart';
import 'widgets/customer_activity_list.dart';
import 'widgets/customer_row.dart';
import 'widgets/inline_edit_row.dart';
import 'widgets/owner_picker_sheet.dart';
import 'widgets/tag_picker_sheet.dart';

enum _Tab { overview, activity, opportunities }

/// Hồ sơ khách theo `CustomerDetail.dc.html`: khối đầu (avatar, tên, bốn nút),
/// dải số, thanh đoạn Tổng quan / Hoạt động / Cơ hội. Mọi trường sửa tại chỗ
/// (không có nút Sửa); chỉ một dòng ở chế độ sửa tại một thời điểm.
class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  _Tab _tab = _Tab.overview;

  /// Trường đang ở chế độ sửa (null = không có).
  CustomerField? _editing;

  /// Bản máy chủ vừa trả sau khi lưu, hiện ngay trong lúc tải lại hồ sơ.
  Customer? _saved;

  String get _id => widget.customerId;

  void _beginEdit(CustomerField field) {
    if (_editing != field) setState(() => _editing = field);
  }

  /// Chỉ đóng khi dòng gọi đúng là dòng đang mở: dòng cũ báo đóng muộn không
  /// được đóng dòng mới.
  void _endEdit(CustomerField field) {
    if (_editing == field) setState(() => _editing = null);
  }

  void _invalidateDetail({required bool activity, required bool opps}) {
    ref.invalidate(customerProvider(_id));
    ref.invalidate(customerSummaryProvider(_id));
    if (activity) ref.invalidate(customerActivityProvider(_id));
    if (opps) {
      ref
          .read(customerOpportunitiesSectionProvider)
          ?.invalidate(ProviderScope.containerOf(context), _id);
    }
  }

  Future<void> _refresh({required bool activity, required bool opps}) async {
    _invalidateDetail(activity: activity, opps: opps);
    try {
      await ref.read(customerProvider(_id).future);
    } catch (_) {
      // Lỗi hiện qua chính provider; kéo-để-làm-mới chỉ cần kết thúc.
    }
  }

  /// Ghi MỘT trường. Bắt `messenger`/`router`/`container` TRƯỚC `await`: sau đó
  /// trang có thể đã đóng.
  Future<void> _save(
    Customer c,
    CustomerField f,
    Object? v, {
    required bool activity,
    required bool opps,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);
    final saved = await container.read(customerEditorProvider).save(c, f, v);
    final me = container.read(sessionProvider).user?.id;
    final ownScope =
        container.read(customerAccessProvider).readScope == AccessScope.own;
    if (f == CustomerField.owner && ownScope && saved.ownerId != me) {
      // Không còn quyền đọc hồ sơ này.
      if (router.canPop()) {
        router.pop();
      } else {
        router.goNamed(CustomerRoutes.list);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã giao khách cho ${saved.ownerName ?? 'người khác'}.',
          ),
        ),
      );
      return;
    }
    container.invalidate(customerProvider(c.id));
    container.invalidate(customerSummaryProvider(c.id));
    if (activity) container.invalidate(customerActivityProvider(c.id));
    if (opps) {
      container
          .read(customerOpportunitiesSectionProvider)
          ?.invalidate(container, c.id);
    }
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _savePicked(
    Customer c,
    CustomerField f,
    Object? v, {
    required bool activity,
    required bool opps,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _save(c, f, v, activity: activity, opps: opps);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không lưu được.')));
    }
  }

  Future<void> _pickOwner(
    Customer c, {
    required bool activity,
    required bool opps,
  }) async {
    setState(() => _editing = null);
    final picked = await showOwnerPicker(
      context,
      currentId: c.ownerId,
      currentName: c.ownerName,
    );
    if (picked == null || !mounted) return;
    await _savePicked(
      c,
      CustomerField.owner,
      picked,
      activity: activity,
      opps: opps,
    );
  }

  Future<void> _pickTags(
    Customer c, {
    required bool activity,
    required bool opps,
  }) async {
    setState(() => _editing = null);
    final picked = await showTagPicker(context, current: c.tags);
    if (picked == null || !mounted) return;
    await _savePicked(
      c,
      CustomerField.tags,
      picked,
      activity: activity,
      opps: opps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerProvider(_id));
    ref.listen(customerProvider(_id), (_, next) {
      if (next is AsyncData<Customer> && !next.isLoading) _saved = null;
    });
    final access = ref.watch(customerAccessProvider);
    final activityOn = ref.watch(customerActivityAccessProvider);
    final taskWrite = ref.watch(accessProvider).can(TaskPermissions.write);
    final summary = ref.watch(customerSummaryProvider(_id)).valueOrNull;
    // Cơ hội do module opportunities cắm vào (tránh vòng phụ thuộc). Chỉ gọi
    // API cơ hội khi được đọc VÀ workspace bật tính năng.
    final section = ref.watch(customerOpportunitiesSectionProvider);
    final oppsOn = section != null && section.visible(ref);
    final canCreateOpp = section != null && section.canCreate(ref);
    final oppStats = oppsOn ? section.stats(ref, _id) : null;

    final tabs = [
      _Tab.overview,
      if (activityOn) _Tab.activity,
      if (oppsOn) _Tab.opportunities,
    ];
    final tab = tabs.contains(_tab) ? _tab : _Tab.overview;
    final oppCount = oppStats?.count ?? summary?.opportunitiesCount;

    return Scaffold(
      appBar: const OmniTopBar(bottom: _BackBar()),
      body: OmniAsyncView(
        value: customer,
        onRetry: () => ref.invalidate(customerProvider(_id)),
        data: (loaded) {
          final data = _saved ?? loaded;
          final canUpdate = access.canUpdate;
          Future<void> save(CustomerField f, String draft) =>
              _save(data, f, draft, activity: activityOn, opps: oppsOn);

          return RefreshIndicator(
            onRefresh: () => _refresh(activity: activityOn, opps: oppsOn),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
              children: [
                _Header(customer: data),
                _Actions(
                  customer: data,
                  canCreateTask: taskWrite,
                  canCreateOpportunity: canCreateOpp,
                ),
                if (summary != null)
                  _Stats(
                    bought: Formatters.vndCompact(summary.ordersTotal),
                    orders: '${summary.ordersCount}',
                    open: oppsOn
                        ? (oppStats == null
                              ? '—'
                              : Formatters.vndCompact(oppStats.openValue))
                        : null,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: OmniSegmented(
                    labels: [
                      'Tổng quan',
                      if (activityOn) 'Hoạt động',
                      if (oppsOn)
                        oppCount == null ? 'Cơ hội' : 'Cơ hội · $oppCount',
                    ],
                    index: tabs.indexOf(tab),
                    onChanged: (i) => setState(() {
                      _tab = tabs[i];
                      _editing = null;
                    }),
                  ),
                ),
                switch (tab) {
                  _Tab.overview => _Overview(
                    customer: data,
                    canUpdate: canUpdate,
                    editing: _editing,
                    onBeginEdit: _beginEdit,
                    onEndEdit: _endEdit,
                    onSave: save,
                    onPickOwner: () =>
                        _pickOwner(data, activity: activityOn, opps: oppsOn),
                    onPickTags: () =>
                        _pickTags(data, activity: activityOn, opps: oppsOn),
                  ),
                  _Tab.activity => _ActivityTab(customerId: _id),
                  _Tab.opportunities => section!.body(_id),
                },
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Nút ‹ "Khách hàng" dưới thanh kính (bản mẫu: không nút Sửa).
class _BackBar extends StatelessWidget implements PreferredSizeWidget {
  const _BackBar();

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TextButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(CustomerRoutes.list);
              }
            },
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            label: const Text('Khách hàng'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final created = customer.createdAt;
    String? since;
    if (created != null) {
      final vn = VnTime.of(created);
      since = 'Khách từ ${vn.month.toString().padLeft(2, '0')}/${vn.year}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          OmniAvatar(name: customer.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
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
                            theme.brightness,
                          ),
                        ),
                      ),
                      if (since != null) TextSpan(text: ' · $since'),
                    ],
                  ),
                  key: const ValueKey('customer-source-line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.customer,
    required this.canCreateTask,
    required this.canCreateOpportunity,
  });

  final Customer customer;
  final bool canCreateTask;
  final bool canCreateOpportunity;

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone.trim();
    final buttons = <Widget>[
      _ActButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Nhắn',
        primary: true,
        onTap: customer.hasPhone
            ? () => launchWithToast(
                context,
                Uri.parse('https://zalo.me/${zaloNumber(phone)}'),
                'Không mở được Zalo.',
                mode: LaunchMode.externalApplication,
              )
            : null,
      ),
      _ActButton(
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
      if (canCreateTask)
        _ActButton(
          icon: Icons.task_alt_rounded,
          label: 'Việc',
          onTap: () => context.pushNamed(
            TaskRoutes.create,
            extra: CreateTaskArgs(initialTitle: 'Liên hệ ${customer.name}'),
          ),
        ),
      if (canCreateOpportunity)
        _ActButton(
          icon: Icons.trending_up_rounded,
          label: 'Cơ hội',
          onTap: () => context.pushNamed(
            OpportunityRoutes.create,
            queryParameters: {'customer': customer.id},
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

/// `.act`: nút cao 36 bo 6 trong vùng chạm 44. Nút chính tô nền primary.
class _ActButton extends StatelessWidget {
  const _ActButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final background = primary ? scheme.primary : scheme.surface;
    final foreground = primary ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(6),
                  border: primary
                      ? null
                      : Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.chip.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.bought, required this.orders, this.open});

  final String bought;
  final String orders;

  /// null = người dùng không đọc được cơ hội: không có ô này.
  final String? open;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = [
      ('Đã mua', bought),
      ('Đơn hàng', orders),
      if (open != null) ('Đang mở', open!),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cells[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cells[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.bodyStrong.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.customer,
    required this.canUpdate,
    required this.editing,
    required this.onBeginEdit,
    required this.onEndEdit,
    required this.onSave,
    required this.onPickOwner,
    required this.onPickTags,
  });

  final Customer customer;
  final bool canUpdate;
  final CustomerField? editing;
  final void Function(CustomerField) onBeginEdit;
  final void Function(CustomerField) onEndEdit;
  final Future<void> Function(CustomerField, String) onSave;
  final VoidCallback onPickOwner;
  final VoidCallback onPickTags;

  InlineEditRow _row(
    CustomerField field,
    String value, {
    TextInputType? keyboardType,
    int? maxLength,
    bool multiline = false,
    Color? valueColor,
    VoidCallback? onTapValue,
  }) => InlineEditRow(
    key: ValueKey('edit-${field.name}'),
    label: field.label,
    value: value,
    editable: canUpdate,
    multiline: multiline,
    keyboardType: keyboardType,
    maxLength: maxLength,
    valueColor: valueColor,
    onTapValue: onTapValue,
    isEditing: editing == field,
    onStartEdit: () => onBeginEdit(field),
    onEndEdit: () => onEndEdit(field),
    onSave: (draft) => onSave(field, draft),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = customer;
    final phone = c.phone.trim();
    final email = c.email.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          OmniCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _row(
                  CustomerField.phone,
                  c.phone,
                  keyboardType: TextInputType.phone,
                  valueColor: scheme.primary,
                  onTapValue: phone.isEmpty
                      ? null
                      : () => launchWithToast(
                          context,
                          Uri(scheme: 'tel', path: dialNumber(phone)),
                          'Không mở được ứng dụng gọi điện.',
                        ),
                ),
                _row(
                  CustomerField.email,
                  c.email,
                  keyboardType: TextInputType.emailAddress,
                  onTapValue: email.isEmpty
                      ? null
                      : () => launchWithToast(
                          context,
                          Uri(scheme: 'mailto', path: email),
                          'Không mở được ứng dụng email.',
                        ),
                ),
                _row(CustomerField.address, c.address, maxLength: 500),
                _row(CustomerField.note, c.note ?? '', multiline: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OmniCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _PickerRow(
                  label: CustomerField.owner.label,
                  editable: canUpdate,
                  onTap: onPickOwner,
                  child: _OwnerValue(name: c.ownerName),
                ),
                _PickerRow(
                  label: CustomerField.tags.label,
                  editable: canUpdate,
                  onTap: onPickTags,
                  child: _TagsValue(tags: c.tags),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng chạm-để-chọn (Phụ trách, Nhãn): cùng khung với [InlineEditRow].
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.editable,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool editable;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: editable ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: child),
              ),
              if (editable) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: scheme.outline,
                  semanticLabel: 'Sửa $label',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerValue extends StatelessWidget {
  const _OwnerValue({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final has = name != null && name!.trim().isNotEmpty;
    if (!has) {
      return Text(
        'Chưa gán',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OmniAvatar(name: name!, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagsValue extends StatelessWidget {
  const _TagsValue({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (tags.isEmpty) {
      return Text(
        '—',
        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: OmniLabelColors.of(tag),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tag,
                  style: OmniType.chip.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Đoạn Hoạt động: chỉ dựng (và chỉ gọi API) khi có quyền đọc nhật ký.
class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activities = ref.watch(customerActivityProvider(customerId));

    return activities.when(
      data: (items) => CustomerActivityList(items: items),
      loading: () => const Padding(
        padding: EdgeInsets.all(OmniSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(OmniSpacing.section),
        child: Column(
          children: [
            Text(
              'Không tải được hoạt động.',
              textAlign: TextAlign.center,
              style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(customerActivityProvider(customerId)),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
