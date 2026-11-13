import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../tasks/domain/task_permissions.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
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
      appBar: OmniAppBar(
        title: 'Thông tin',
        fallbackBack: () => context.go('/inbox/$conversationId'),
      ),
      body: OmniAsyncView(
        value: conversation,
        onRetry: () => ref.invalidate(conversationProvider(conversationId)),
        data: (c) => _InfoBody(conversation: c),
      ),
    );
  }
}

/// Header kính: ‹ và "Thông tin" giữa.
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
    final canCreateTask = policy.can(TaskPermissions.write);
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
                  // Chuyển từ đầu hội thoại về đây để tin nhắn có chỗ.
                  if (canCreateTask)
                    _QuickAction(
                      icon: Icons.task_alt_rounded,
                      label: 'Việc',
                      onTap: () => context.pushNamed(
                        TaskRoutes.create,
                        extra: CreateTaskArgs(
                          initialTitle: 'Liên hệ ${c.title}',
                        ),
                      ),
                    ),
                  // Sở thích riêng, quyền đọc là đủ. Đổi theo phản hồi
                  // server (trang dựng lại từ `conversationProvider`).
                  _QuickAction(
                    icon: Icons.notifications_off_outlined,
                    label: c.isMuted ? 'Đã tắt' : 'Tắt TB',
                    active: c.isMuted,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ConversationActions(ref, context).setMuted(c, !c.isMuted);
                    },
                  ),
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: 'Tìm tin',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(ThreadInfoResult.search);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Rise(
              index: 1,
              child: _Section(
                title: 'Khách hàng',
                children: [
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Phụ trách',
                    onTap: access.canAssign
                        ? () => ConversationActions(ref, context).assign(c)
                        : null,
                    value: _Assignee(conversation: c),
                  ),
                  if (phone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.call_outlined,
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
                    icon: Icons.label_outline_rounded,
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
                title: 'Ảnh, tệp, liên kết',
                children: [ConversationAssetsSection(assets: assets)],
              ),
            ),
            // Mọi người đọc đều thấy (Ghim là sở thích riêng); từng dòng còn
            // lại tự xét quyền.
            const SizedBox(height: 16),
            _Rise(
              index: 4,
              child: _Section(
                title: 'Thao tác',
                children: [
                  // Một nút cho trình đọc màn hình: "Ghim hội thoại, công
                  // tắc, bật". Nhãn lấy từ chữ của dòng, công tắc không lặp.
                  MergeSemantics(
                    child: _InfoRow(
                      icon: Icons.push_pin_outlined,
                      label: 'Ghim hội thoại',
                      plainLabel: true,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ConversationActions(
                          ref,
                          context,
                        ).setPinned(c, !c.isPinned);
                      },
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
                      icon: Icons.mark_chat_unread_outlined,
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
                      icon: closed
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      label: closed ? 'Mở lại hội thoại' : 'Lưu trữ hội thoại',
                      plainLabel: true,
                      onTap: () => ConversationActions(
                        ref,
                        context,
                      ).setArchived(c, !closed),
                    ),
                  if (access.canBlock && c.isBlocked)
                    _InfoRow(
                      icon: Icons.lock_open_outlined,
                      label: 'Bỏ chặn hội thoại',
                      plainLabel: true,
                      onTap: () => ConversationActions(
                        ref,
                        context,
                      ).setBlocked(c, false),
                    ),
                  // Chặn: dòng đỏ, cuối nhóm.
                  if (access.canBlock && !c.isBlocked)
                    _InfoRow(
                      icon: Icons.block_outlined,
                      label: 'Chặn hội thoại',
                      plainLabel: true,
                      destructive: true,
                      // Hội thoại đã chặn ẩn khỏi Hộp thư: về đó luôn.
                      onTap: () => _thenInbox(
                        context,
                        ConversationActions(ref, context).setBlocked(c, true),
                      ),
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
    return Switch.adaptive(
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
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
          spacing: 2,
          runSpacing: 8,
          children: actions,
        ),
      ],
    );
  }
}

/// Nút kính tròn 44, nhãn 11 w600 bên dưới; vùng chạm 64×≥44.
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

  /// Nút đang bật (vd "Đã tắt" thông báo): icon màu chính, không khối đặc.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: active ? true : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OmniGlassCircle(
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              // Không cắt "…" ("Chuyển KH" từng thành "Chuyển …"): rộng 70,
              // nhãn dài thì xuống dòng thứ hai.
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
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

/// Nhóm lồng liquid: nhãn xám ngoài thẻ, thẻ trắng bo 18, vạch thụt.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OmniGroupSection(
    key: ValueKey('thread-info-section-$title'),
    title: title,
    children: children,
  );
}

/// Dòng trong nhóm: icon, nhãn bên trái, giá trị (widget) bên phải, mũi tên
/// khi bấm được. [onTap] null = chỉ xem.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.icon,
    this.value,
    this.onTap,
    this.plainLabel = false,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final Widget? value;
  final VoidCallback? onTap;

  /// Dòng hành động không có giá trị: không mũi tên.
  final bool plainLabel;

  /// Chữ đỏ (vd "Chặn hội thoại").
  final bool destructive;

  @override
  Widget build(BuildContext context) => OmniGroupRow(
    icon: icon,
    title: label,
    trailing: value == null
        ? null
        : Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
    onTap: onTap,
    destructive: destructive,
    chevron: onTap != null && !plainLabel && !destructive,
  );
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
              Flexible(
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _valueStyle(context),
                ),
              ),
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
      title: 'Bán hàng',
      children: [
        if (failed)
          _InfoRow(
            icon: Icons.refresh_rounded,
            label: 'Không tải được cơ hội. Thử lại',
            plainLabel: true,
            onTap: () =>
                ref.invalidate(conversationContextProvider(conversation.id)),
          ),
        for (final o in opportunities)
          OmniGroupRow(
            icon: Icons.trending_up_rounded,
            title: o.title,
            maxTitleLines: 1,
            subtitle: o.budget == null
                ? 'Cơ hội'
                : 'Cơ hội · ${Formatters.vnd(o.budget)}',
            trailing: o.stage == null
                ? null
                : _StageChip(label: catalog?.stageLabel(o.stage!) ?? o.stage!),
            chevron: true,
            onTap: () => context.pushNamed(
              OpportunityRoutes.detail,
              pathParameters: {'id': o.id},
            ),
          ),
        if (bought > 0)
          OmniGroupRow(
            icon: Icons.shopping_bag_outlined,
            title: 'Đã mua',
            value: Formatters.vnd(bought),
          ),
        if (showCreate)
          OmniGroupRow.add(
            title: 'Tạo cơ hội',
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
      borderRadius: BorderRadius.circular(999),
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
