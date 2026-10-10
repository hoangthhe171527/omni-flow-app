import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../customers/customers.dart';
import '../../opportunities/opportunities.dart';
import '../application/inbox_providers.dart';
import '../domain/conversation.dart';
import '../inbox_routes.dart';
import 'widgets/conversation_actions.dart';
import 'widgets/conversation_assets_section.dart';

/// Kết quả trang Thông tin trả về cho hội thoại.
enum ThreadInfoResult { search }

/// Trang Thông tin hội thoại (`ThreadInfo.dc.html`), thay sheet ngữ cảnh cũ:
/// khách, phụ trách, nhãn, bán hàng, ảnh / tệp / liên kết; tắt thông báo,
/// ghim, chưa đọc, lưu trữ, chặn hội thoại (chỉ trong CRM) — API
/// `feat/hop-thu-mobile`.
class ThreadInfoPage extends ConsumerWidget {
  const ThreadInfoPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider(conversationId));

    return Scaffold(
      backgroundColor: OmniColors.byBrightness(
        context,
        OmniColors.background,
        OmniColors.darkBackground,
      ),
      appBar: const _InfoHeader(),
      body: OmniAsyncView(
        value: conversation,
        onRetry: () => ref.invalidate(conversationProvider(conversationId)),
        data: (c) => _InfoBody(conversation: c),
      ),
    );
  }
}

/// Header kính: ‹ và "Thông tin" giữa.
class _InfoHeader extends StatelessWidget implements PreferredSizeWidget {
  const _InfoHeader();

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = OmniColors.byBrightness(
      context,
      OmniColors.background.withValues(alpha: 0.82),
      OmniColors.darkBackground.withValues(alpha: 0.82),
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Thông tin',
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: IconButton(
                        tooltip: 'Quay lại',
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: scheme.onSurface,
                        ),
                        icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBody extends ConsumerWidget {
  const _InfoBody({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final access = ref.watch(inboxAccessProvider);
    final opportunitiesOn = ref
        .watch(sessionProvider)
        .featureEnabled('opportunities');
    final customer = c.isLinkedToCustomer
        ? ref.watch(customerProvider(c.customerId!)).valueOrNull
        : null;
    final policy = ref.watch(accessProvider);
    final canOpenCustomer = policy.canAny(CustomerPermissions.anyRead);
    final canCreateOpportunity =
        opportunitiesOn && policy.can(OpportunityPermissions.create);
    final phone = customer?.phone.trim() ?? '';
    final assets = ref.watch(conversationAssetsProvider(c.id));
    final closed = c.status == ConversationStatus.closed;

    Future<void> call() async {
      final messenger = ScaffoldMessenger.of(context);
      var opened = false;
      try {
        opened = await launchUrl(Uri(scheme: 'tel', path: phone));
      } catch (_) {}
      if (!opened && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không mở được ứng dụng gọi điện.')),
        );
      }
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            30 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _Rise(
              index: 0,
              child: _Hero(
                conversation: c,
                actions: [
                  if (phone.isNotEmpty)
                    _QuickAction(
                      icon: Icons.call_outlined,
                      label: 'Gọi',
                      onTap: call,
                    ),
                  if (c.isLinkedToCustomer && canOpenCustomer)
                    _QuickAction(
                      icon: Icons.person_outline_rounded,
                      label: 'Hồ sơ',
                      onTap: () => context.pushNamed(
                        CustomerRoutes.detail,
                        pathParameters: {'id': c.customerId!},
                      ),
                    )
                  else if (!c.isLinkedToCustomer && access.canConvert)
                    _QuickAction(
                      icon: Icons.person_add_alt_rounded,
                      label: 'Chuyển KH',
                      onTap: () => convertConversation(context, ref, c.id),
                    ),
                  // Sở thích riêng, quyền đọc là đủ. Đổi theo phản hồi
                  // server (trang dựng lại từ `conversationProvider`).
                  _QuickAction(
                    icon: Icons.notifications_off_outlined,
                    label: c.isMuted ? 'Đã tắt' : 'Tắt TB',
                    active: c.isMuted,
                    onTap: () => ConversationActions(
                      ref,
                      context,
                    ).setMuted(c, !c.isMuted),
                  ),
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: 'Tìm tin',
                    onTap: () =>
                        Navigator.of(context).pop(ThreadInfoResult.search),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Rise(
              index: 1,
              child: _Section(
                title: 'KHÁCH HÀNG',
                children: [
                  _InfoRow(
                    label: 'Phụ trách',
                    onTap: access.canAssign
                        ? () => ConversationActions(ref, context).assign(c)
                        : null,
                    value: _Assignee(conversation: c),
                  ),
                  if (phone.isNotEmpty)
                    _InfoRow(
                      label: 'Điện thoại',
                      onTap: call,
                      value: Text(
                        phone,
                        style: _valueStyle(context).copyWith(
                          color: OmniColors.byBrightness(
                            context,
                            OmniColors.primary,
                            OmniColors.darkPrimary,
                          ),
                        ),
                      ),
                    ),
                  _InfoRow(
                    label: 'Nhãn',
                    onTap: access.canLabel
                        ? () => ConversationActions(ref, context).addLabel(c)
                        : null,
                    value: _Labels(tags: c.tags),
                  ),
                ],
              ),
            ),
            if (opportunitiesOn)
              _SalesCard(
                conversation: c,
                customer: customer,
                canCreate: canCreateOpportunity,
              ),
            const SizedBox(height: 16),
            _Rise(
              index: 3,
              child: _Section(
                title: 'ẢNH, TỆP, LIÊN KẾT',
                padded: false,
                children: [ConversationAssetsSection(assets: assets)],
              ),
            ),
            // Mọi người đọc đều thấy (Ghim là sở thích riêng); từng dòng còn
            // lại tự xét quyền.
            const SizedBox(height: 16),
            _Rise(
              index: 4,
              child: _Section(
                children: [
                  // Một nút cho trình đọc màn hình: "Ghim hội thoại, công
                  // tắc, bật". Nhãn lấy từ chữ của dòng, công tắc không lặp.
                  MergeSemantics(
                    child: _InfoRow(
                      label: 'Ghim hội thoại',
                      plainLabel: true,
                      onTap: () => ConversationActions(
                        ref,
                        context,
                      ).setPinned(c, !c.isPinned),
                      value: _PinSwitch(
                        value: c.isPinned,
                        onChanged: (on) =>
                            ConversationActions(ref, context).setPinned(c, on),
                      ),
                    ),
                  ),
                  // Đã chặn: API trả 422 `conversation_blocked` cho /unread.
                  if (access.canUpdate && !c.isUnread && !c.isBlocked)
                    _InfoRow(
                      label: 'Đánh dấu chưa đọc',
                      plainLabel: true,
                      // Ở lại hội thoại là đang đọc: dấu "chưa đọc" mất
                      // nghĩa, nên xong thì về Hộp thư (như Messenger).
                      onTap: () => _thenInbox(
                        context,
                        ConversationActions(ref, context).markUnread(c),
                      ),
                    ),
                  if (access.canUpdate)
                    _InfoRow(
                      label: closed ? 'Mở lại hội thoại' : 'Lưu trữ hội thoại',
                      plainLabel: true,
                      onTap: () => ConversationActions(
                        ref,
                        context,
                      ).setArchived(c, !closed),
                    ),
                  if (access.canBlock && !c.isBlocked)
                    _InfoRow(
                      label: 'Chặn hội thoại',
                      plainLabel: true,
                      labelColor: _danger(context),
                      // Hội thoại đã chặn ẩn khỏi Hộp thư: về đó luôn.
                      onTap: () => _thenInbox(
                        context,
                        ConversationActions(ref, context).setBlocked(c, true),
                      ),
                    ),
                  if (access.canBlock && c.isBlocked)
                    _InfoRow(
                      label: 'Bỏ chặn hội thoại',
                      plainLabel: true,
                      onTap: () => ConversationActions(
                        ref,
                        context,
                      ).setBlocked(c, false),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _valueStyle(BuildContext context) => OmniType.body.copyWith(
  fontWeight: FontWeight.w600,
  color: Theme.of(context).colorScheme.onSurface,
);

Color _muted(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.mutedForeground,
  OmniColors.darkMutedForeground,
);

/// Chữ nguy hiểm (#B42318 sáng / dangerTextDark tối), như menu xem trước.
Color _danger(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniFeatureTones.light(OmniHue.red).foreground,
  OmniColors.dangerTextDark,
);

/// Chờ thao tác xong rồi về Hộp thư — chỉ khi server đã nhận. Router lấy
/// TRƯỚC `await`: trang có thể đã bị gỡ khi lượt gọi về.
Future<void> _thenInbox(BuildContext context, Future<bool> action) async {
  final router = GoRouter.of(context);
  if (await action) router.goNamed(InboxRoutes.list);
}

/// Công tắc "Ghim hội thoại" (`ThreadInfo.dc.html` `.sw`): bật màu chính,
/// tắt xám. Giá trị theo server — không đổi trước khi API trả lời.
class _PinSwitch extends StatelessWidget {
  const _PinSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Không gắn nhãn riêng: dòng chứa công tắc được gộp (MergeSemantics) với
    // chữ "Ghim hội thoại" — gắn thêm thì trình đọc màn hình đọc hai lần.
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: scheme.surface,
      activeTrackColor: OmniColors.byBrightness(
        context,
        OmniColors.primary,
        OmniColors.darkPrimary,
      ),
      inactiveThumbColor: scheme.surface,
      // #C9D2DE sáng / darkBorderInteractive tối.
      inactiveTrackColor: OmniColors.controlBorderOf(context),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// Avatar 72, tên (title) w600 + chấm nhãn đầu tiên, dòng nguồn, hàng nút tròn.
class _Hero extends StatelessWidget {
  const _Hero({required this.conversation, required this.actions});

  final Conversation conversation;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final scheme = Theme.of(context).colorScheme;
    final account = c.sourceAccount;

    return Column(
      children: [
        c.isGroup
            ? OmniGroupAvatar(
                names: c.groupMembers.map((m) => m.name ?? '?').toList(),
                size: 72,
              )
            : OmniAvatar(
                name: c.title,
                imageUrl: c.customerAvatar,
                size: 72,
                borderRadius: 36,
              ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                c.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: OmniType.title.copyWith(color: scheme.onSurface),
              ),
            ),
            if (c.tags.isNotEmpty) ...[
              const SizedBox(width: 6),
              _LabelDot(label: c.tags.first, size: 8),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: c.channel.sourceKind,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: c.channel.meta.textColorOf(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
              if (account != null) TextSpan(text: ' · $account'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.micro.copyWith(color: _muted(context)),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: actions,
        ),
      ],
    );
  }
}

/// Nút tròn 40 viền #E3E8EF, nhãn 11 w600 bên dưới; vùng chạm 64×≥44.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Nút đang bật (vd "Đã tắt" thông báo): nền mực, biểu tượng nền —
  /// `muteBg`/`muteFg` của bản mẫu, đảo đúng ở giao diện tối.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: active ? true : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? scheme.onSurface
                      : OmniColors.byBrightness(
                          context,
                          OmniColors.card,
                          OmniColors.darkCard,
                        ),
                  border: Border.all(
                    color: active
                        ? scheme.onSurface
                        : OmniColors.byBrightness(
                            context,
                            OmniColors.border,
                            OmniColors.darkBorder,
                          ),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? scheme.surface : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ trắng viền mảnh bo 8 với tiêu đề viết hoa 11 w600 phía trên.
class _Section extends StatelessWidget {
  const _Section({this.title, required this.children, this.padded = true});

  final String? title;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final divider = OmniColors.byBrightness(
      context,
      OmniColors.divider,
      OmniColors.darkBorder,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              title!,
              style: OmniType.overline.copyWith(
                letterSpacing: 0.5,
                color: _muted(context),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: OmniColors.byBrightness(
              context,
              OmniColors.card,
              OmniColors.darkCard,
            ),
            border: Border.all(
              color: OmniColors.byBrightness(
                context,
                OmniColors.border,
                OmniColors.darkBorder,
              ),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0 && padded) Divider(height: 1, color: divider),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dòng trong thẻ: nhãn mờ bên trái, giá trị đậm bên phải, mũi tên khi bấm
/// được. [onTap] null = chỉ xem.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.value,
    this.onTap,
    this.plainLabel = false,
    this.labelColor,
  });

  final String label;
  final Widget? value;
  final VoidCallback? onTap;

  /// Nhãn là chữ chính (màu mực) — dòng hành động không có giá trị.
  final bool plainLabel;

  /// Màu chữ nhãn riêng (vd chữ nguy hiểm của "Chặn hội thoại").
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelText = Text(
      label,
      style: OmniType.body.copyWith(
        color: labelColor ?? (plainLabel ? scheme.onSurface : _muted(context)),
      ),
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (value == null) Expanded(child: labelText) else labelText,
              if (value != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Align(alignment: Alignment.centerRight, child: value),
                ),
              ],
              if (onTap != null && !plainLabel) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: OmniColors.byBrightness(
                    context,
                    OmniColors.mutedForeground,
                    OmniColors.darkMutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Assignee extends StatelessWidget {
  const _Assignee({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final style = _valueStyle(context);
    if (c.isUnassigned) {
      return Text(
        'Chưa gán',
        style: style.copyWith(
          color: _muted(context),
          fontWeight: FontWeight.w400,
        ),
      );
    }
    final name = (c.assigneeName ?? '').trim();
    final shown = name.isEmpty ? 'Đã gán' : name;
    final initials = name.isEmpty
        ? '?'
        : name
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w.characters.first)
              .toList()
              .reversed
              .take(2)
              .toList()
              .reversed
              .join()
              .toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: OmniColors.byBrightness(
              context,
              OmniColors.ink,
              OmniColors.darkMuted,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            initials,
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w600,
              color: OmniColors.byBrightness(
                context,
                Colors.white,
                OmniColors.darkForeground,
              ),
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            shown,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _Labels extends StatelessWidget {
  const _Labels({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text(
        'Chưa có nhãn',
        style: _valueStyle(
          context,
        ).copyWith(color: _muted(context), fontWeight: FontWeight.w400),
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LabelDot(label: tag, size: 7),
              const SizedBox(width: 6),
              Text(tag, style: _valueStyle(context)),
            ],
          ),
      ],
    );
  }
}

/// Chấm màu nhãn; luôn kèm nhãn đọc cho trình đọc màn hình.
class _LabelDot extends StatelessWidget {
  const _LabelDot({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Nhãn: $label',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OmniLabelColors.of(label),
      ),
    ),
  );
}

/// Thẻ "BÁN HÀNG": cơ hội của khách, tổng đã mua, hoặc lối tạo cơ hội.
class _SalesCard extends ConsumerWidget {
  const _SalesCard({
    required this.conversation,
    required this.customer,
    required this.canCreate,
  });

  final Conversation conversation;
  final Customer? customer;
  final bool canCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final contextData = ref.watch(conversationContextProvider(conversation.id));
    final catalog = ref.watch(pipelineCatalogProvider).valueOrNull;
    final opportunities = contextData.valueOrNull?.opportunities ?? const [];
    final loaded = !contextData.isLoading;
    final failed = contextData.hasError;
    final bought = customer?.lifetimeValue ?? 0;
    final showCreate = canCreate && loaded && !failed && opportunities.isEmpty;
    if (opportunities.isEmpty && bought <= 0 && !showCreate && !failed) {
      return const SizedBox.shrink();
    }

    final card = _Section(
      title: 'BÁN HÀNG',
      children: [
        if (failed)
          _InfoRow(
            label: 'Không tải được cơ hội. Thử lại',
            plainLabel: true,
            onTap: () =>
                ref.invalidate(conversationContextProvider(conversation.id)),
          ),
        for (final o in opportunities)
          InkWell(
            onTap: () => context.pushNamed(
              OpportunityRoutes.detail,
              pathParameters: {'id': o.id},
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _valueStyle(context),
                          ),
                          Text(
                            o.budget == null
                                ? 'Cơ hội'
                                : 'Cơ hội · ${Formatters.vndCompact(o.budget)}',
                            style: OmniType.micro.copyWith(
                              color: _muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (o.stage != null) ...[
                      const SizedBox(width: 8),
                      _StageChip(
                        label: catalog?.stageLabel(o.stage!) ?? o.stage!,
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (bought > 0)
          _InfoRow(
            label: 'Đã mua',
            value: Text(
              Formatters.vndCompact(bought),
              style: _valueStyle(context),
            ),
          ),
        if (showCreate)
          _InfoRow(
            label: 'Tạo cơ hội',
            plainLabel: true,
            onTap: () => context.pushNamed(
              OpportunityRoutes.create,
              queryParameters: {
                if (conversation.isLinkedToCustomer)
                  'customer': conversation.customerId!,
              },
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _Rise(index: 2, child: card),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: OmniColors.byBrightness(
        context,
        OmniColors.accent,
        OmniColors.darkAccent,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: OmniType.micro.copyWith(
        fontWeight: FontWeight.w600,
        color: OmniColors.byBrightness(
          context,
          OmniColors.accentForeground,
          OmniColors.darkAccentForeground,
        ),
      ),
    ),
  );
}

/// Khối hiện dần: dịch 10→0 và mờ→rõ trong 500ms, trễ 50ms × [index]. Giảm
/// chuyển động thì hiện ngay. Một controller + Interval (không Timer) để
/// không treo test và không rò khi trang đóng.
class _Rise extends StatefulWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  static const _rise = 500;
  static const _step = 50;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _rise + _step * widget.index),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OmniMotion.enabled(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _rise + _step * widget.index;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        _step * widget.index / total,
        1,
        curve: OmniCurves.standard,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}
