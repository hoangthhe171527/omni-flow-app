import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/finance_providers.dart';
import '../data/finance_api.dart';
import '../domain/finance_models.dart';

/// Danh mục chi trên app: nhóm chi (đang dùng, đã lưu trữ) và nguồn tiền.
///
/// Sửa tên, tính / không tính vào chi phí, lưu trữ, xoá khi trống — cùng
/// endpoint với trang Danh mục của web (`PUT/DELETE /finance/expense-groups/{id}`,
/// `/finance/money-accounts/{id}`). Gộp nhóm chỉ có trên web.
class FinanceCatalogPage extends ConsumerWidget {
  const FinanceCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeLedgerProvider);

    final active = [
      for (final g in state.groups)
        if (!g.archived) g,
    ];
    final archived = [
      for (final g in state.groups)
        if (g.archived) g,
    ];
    final accounts = [
      for (final a in state.accounts)
        if (!a.archived) a,
      for (final a in state.accounts)
        if (a.archived) a,
    ];
    final empty = state.groups.isEmpty && state.accounts.isEmpty;

    Widget body;
    if (state.isLoading && empty) {
      body = const OmniSkeletonList(count: 6, height: 52);
    } else if (state.errorMessage != null && empty) {
      body = OmniErrorView(
        error: state.errorMessage!,
        onRetry: () => ref.read(financeLedgerProvider.notifier).refresh(),
      );
    } else if (empty) {
      body = OmniEmptyState(
        icon: Icons.sell_outlined,
        title: 'Chưa có danh mục',
        actionLabel: 'Thêm',
        onAction: () => _add(context, ref),
      );
    } else {
      body = RefreshIndicator.adaptive(
        onRefresh: () => ref.read(financeLedgerProvider.notifier).refresh(),
        child: ListView(
          key: const ValueKey('finance-catalog-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          // Chừa phần đáy bị che + nút + kính.
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            OmniFabLayer.listBottom(context),
          ),
          children: [
            OmniGroupSection(
              key: const ValueKey('finance-catalog-groups'),
              title: 'Nhóm chi',
              dividerIndent: 54,
              trailingTitle: _Count(active.length),
              children: [
                for (final g in active)
                  _GroupRow(group: g, onTap: () => _editGroup(context, ref, g)),
              ],
            ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: OmniGroupSection.gap),
              OmniGroupSection(
                key: const ValueKey('finance-catalog-archived'),
                title: 'Đã lưu trữ',
                dividerIndent: 54,
                trailingTitle: _Count(archived.length),
                children: [
                  for (final g in archived)
                    _GroupRow(
                      group: g,
                      onTap: () => _editGroup(context, ref, g),
                    ),
                ],
              ),
            ],
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: OmniGroupSection.gap),
              OmniGroupSection(
                key: const ValueKey('finance-catalog-accounts'),
                title: 'Nguồn tiền',
                dividerIndent: 54,
                trailingTitle: _Count(
                  accounts.where((a) => !a.archived).length,
                ),
                children: [
                  for (final a in accounts)
                    _AccountRow(
                      account: a,
                      onTap: () => _editAccount(context, ref, a),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const OmniAppBar(title: 'Danh mục chi'),
      // Thêm nhóm chi / nguồn tiền: nút + kính góc phải dưới (rà soát 12/11),
      // mở sheet hai dòng như dấu + ở header trước đây.
      body: OmniFabLayer(
        fab: OmniLiquidFab(
          key: const ValueKey('finance-catalog-add'),
          tooltip: 'Thêm',
          onPressed: (_) => _add(context, ref),
        ),
        body: body,
      ),
    );
  }

  static FinanceApi _api(WidgetRef ref) => ref.read(financeApiProvider);

  /// Tải lại danh mục trong sổ — bộ chọn nhóm / nguồn của Sổ chi phí đọc
  /// cùng state nên thấy ngay thay đổi.
  static Future<void> _reload(WidgetRef ref) =>
      ref.read(financeLedgerProvider.notifier).refresh();

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  static String _errorText(Object error) =>
      error is AppException && error.message.trim().isNotEmpty
      ? error.message
      : 'Không lưu được. Thử lại sau.';

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final kind = await showOmniSheet<_CatalogKind>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Thêm danh mục',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.md),
              onPressed: () => Navigator.of(sheet).maybePop(),
            ),
          ),
        ),
        children: [
          OmniGroupSection(
            dividerIndent: 54,
            children: [
              OmniGroupRow(
                key: const ValueKey('finance-catalog-add-group'),
                icon: Icons.sell_outlined,
                title: 'Nhóm chi',
                onTap: () => Navigator.of(sheet).pop(_CatalogKind.group),
              ),
              OmniGroupRow(
                key: const ValueKey('finance-catalog-add-account'),
                icon: Icons.account_balance_wallet_outlined,
                title: 'Nguồn tiền',
                onTap: () => Navigator.of(sheet).pop(_CatalogKind.account),
              ),
            ],
          ),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;

    final name = await showOmniPrompt(
      context: context,
      title: kind == _CatalogKind.group ? 'Nhóm chi mới' : 'Nguồn tiền mới',
      confirmLabel: 'Thêm',
      hintText: kind == _CatalogKind.group ? 'Tên nhóm' : 'Tên nguồn tiền',
      maxLength: 80,
      fieldKey: const ValueKey('finance-catalog-name-field'),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;

    try {
      if (kind == _CatalogKind.group) {
        await _api(ref).createGroup(name: trimmed);
      } else {
        await _api(ref).createAccount(name: trimmed);
      }
      await _reload(ref);
    } catch (e) {
      if (context.mounted) _toast(context, _errorText(e));
    }
  }

  Future<void> _editGroup(
    BuildContext context,
    WidgetRef ref,
    ExpenseGroup group,
  ) async {
    await showOmniSheet<void>(
      context: context,
      builder: (_) => _CatalogEditSheet(
        title: group.name,
        expenseCount: group.expenseCount,
        archived: group.archived,
        countsAsExpense: group.countsAsExpense,
        onSave: (name, counts) => _api(ref).updateGroup(
          group.id,
          name: name == group.name ? null : name,
          countsAsExpense: counts == group.countsAsExpense ? null : counts,
        ),
        onToggleArchive: () =>
            _api(ref).updateGroup(group.id, archived: !group.archived),
        onDelete: () => _api(ref).deleteGroup(group.id),
        deleteLabel: 'Xoá nhóm',
        archiveLabel: group.archived ? 'Bỏ lưu trữ' : 'Lưu trữ nhóm',
        onDone: () => _reload(ref),
        errorText: _errorText,
      ),
    );
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    MoneyAccount account,
  ) async {
    await showOmniSheet<void>(
      context: context,
      builder: (_) => _CatalogEditSheet(
        title: account.name,
        expenseCount: account.expenseCount,
        archived: account.archived,
        onSave: (name, _) => _api(
          ref,
        ).updateAccount(account.id, name: name == account.name ? null : name),
        onToggleArchive: () =>
            _api(ref).updateAccount(account.id, archived: !account.archived),
        onDelete: () => _api(ref).deleteAccount(account.id),
        deleteLabel: 'Xoá nguồn tiền',
        archiveLabel: account.archived ? 'Bỏ lưu trữ' : 'Lưu trữ nguồn tiền',
        onDone: () => _reload(ref),
        errorText: _errorText,
      ),
    );
  }
}

enum _CatalogKind { group, account }

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count',
    style: OmniType.caption.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});

  final ExpenseGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = OmniGroupRow(
      key: ValueKey('finance-catalog-group-${group.id}'),
      leading: OmniIconTile(
        group.archived ? Icons.archive_outlined : Icons.sell_outlined,
      ),
      title: group.name,
      subtitle: group.countsAsExpense ? null : 'Không tính vào chi phí',
      value: '${group.expenseCount} khoản',
      onTap: onTap,
    );
    return group.archived ? Opacity(opacity: 0.6, child: row) : row;
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});

  final MoneyAccount account;
  final VoidCallback onTap;

  static IconData _iconFor(MoneyAccountKind kind) => switch (kind) {
    MoneyAccountKind.bank ||
    MoneyAccountKind.company => Icons.account_balance_outlined,
    MoneyAccountKind.cash => Icons.payments_outlined,
    MoneyAccountKind.advance => Icons.account_balance_wallet_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final row = OmniGroupRow(
      key: ValueKey('finance-catalog-account-${account.id}'),
      leading: OmniIconTile(_iconFor(account.kind)),
      title: account.name,
      subtitle: account.archived ? 'Đã lưu trữ' : null,
      value: '${account.expenseCount} khoản',
      onTap: onTap,
    );
    return account.archived ? Opacity(opacity: 0.6, child: row) : row;
  }
}

/// Sheet sửa một nhóm chi / nguồn tiền. [countsAsExpense] null = nguồn tiền
/// (không có công tắc "Tính vào chi phí").
class _CatalogEditSheet extends StatefulWidget {
  const _CatalogEditSheet({
    required this.title,
    required this.expenseCount,
    required this.archived,
    required this.onSave,
    required this.onToggleArchive,
    required this.onDelete,
    required this.deleteLabel,
    required this.archiveLabel,
    required this.onDone,
    required this.errorText,
    this.countsAsExpense,
  });

  final String title;
  final int expenseCount;
  final bool archived;
  final bool? countsAsExpense;
  final Future<Object?> Function(String name, bool counts) onSave;
  final Future<Object?> Function() onToggleArchive;
  final Future<void> Function() onDelete;
  final String deleteLabel;
  final String archiveLabel;
  final Future<void> Function() onDone;
  final String Function(Object error) errorText;

  @override
  State<_CatalogEditSheet> createState() => _CatalogEditSheetState();
}

class _CatalogEditSheetState extends State<_CatalogEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.title,
  );
  late bool _counts = widget.countsAsExpense ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canDelete => widget.expenseCount == 0;

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.errorText(e);
        });
      }
    }
  }

  Future<void> _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên.');
      return Future.value();
    }
    final unchanged =
        name == widget.title &&
        (widget.countsAsExpense == null || _counts == widget.countsAsExpense);
    if (unchanged) {
      Navigator.of(context).pop();
      return Future.value();
    }
    return _run(() => widget.onSave(name, _counts));
  }

  Future<void> _delete() async {
    final ok = await showOmniConfirm(
      context: context,
      title: '${widget.deleteLabel} "${widget.title}"?',
      message: 'Không hoàn tác được.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await widget.onDelete();
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isGroup = widget.countsAsExpense != null;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.title,
        subtitle: '${widget.expenseCount} khoản',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(
              Icons.close_rounded,
              size: OmniIconSize.md,
              color: scheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      footer: FilledButton(
        key: const ValueKey('finance-catalog-save'),
        onPressed: _busy ? null : _save,
        child: const Text('Lưu'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tên',
                    style: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    key: const ValueKey('finance-catalog-edit-name'),
                    controller: _name,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    style: OmniType.body.copyWith(color: scheme.onSurface),
                    decoration: const InputDecoration(
                      counterText: '',
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            if (isGroup)
              OmniGroupRow(
                key: const ValueKey('finance-catalog-counts-switch'),
                title: 'Tính vào chi phí',
                subtitle: 'Tắt: báo cáo tách riêng',
                trailing: Switch.adaptive(
                  value: _counts,
                  onChanged: _busy ? null : (v) => setState(() => _counts = v),
                ),
              ),
          ],
        ),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('finance-catalog-archive'),
              icon: widget.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              title: widget.archiveLabel,
              chevron: false,
              onTap: _busy ? null : () => _run(widget.onToggleArchive),
            ),
          ],
        ),
        OmniGroupSection(
          children: [
            Opacity(
              opacity: _canDelete ? 1 : 0.5,
              child: OmniGroupRow(
                key: const ValueKey('finance-catalog-delete'),
                icon: Icons.delete_outline_rounded,
                title: widget.deleteLabel,
                subtitle: _canDelete
                    ? null
                    : 'Còn ${widget.expenseCount} khoản, hãy lưu trữ',
                destructive: true,
                onTap: _canDelete && !_busy ? _delete : null,
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _error!,
              style: OmniType.caption.copyWith(color: scheme.error),
            ),
          ),
        // Nơi người ta thật sự cần tới: đang sửa một nhóm.
        if (isGroup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Gộp nhiều nhóm làm một: dùng bản web.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
