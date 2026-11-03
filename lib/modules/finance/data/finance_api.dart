import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/finance_models.dart';

final financeApiProvider = Provider<FinanceApi>((ref) {
  return FinanceApi(ref.watch(apiClientProvider));
});

/// Danh mục nhóm chi phí kèm mẫu 5 khoản chi cố định trả về từ `GET /finance/expense-groups`.
class ExpenseGroupsCatalog {
  const ExpenseGroupsCatalog({
    required this.groups,
    required this.recurringTemplates,
  });

  final List<ExpenseGroup> groups;
  final List<RecurringTemplateMeta> recurringTemplates;
}

/// API client cho Sổ chi phí (`/finance/...`, tương đối với `/api/v1`).
class FinanceApi {
  const FinanceApi(this._api);

  final ApiClient _api;

  Future<ExpenseGroupsCatalog> fetchGroupsCatalog({int? year}) async {
    final resp = await _api.get(
      '/finance/expense-groups',
      query: {'year': ?year},
    );
    final items = resp.list.isNotEmpty
        ? resp.list
        : (resp.object['items'] is List
              ? (resp.object['items'] as List)
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList()
              : const <Map<String, dynamic>>[]);
    final groups = [for (final item in items) ExpenseGroup.fromJson(item)];

    final rawMeta = resp.raw['meta'];
    final rawTemplates = rawMeta is Map ? rawMeta['recurring_templates'] : null;
    final templates = rawTemplates is List
        ? rawTemplates
              .whereType<Map>()
              .map(
                (e) =>
                    RecurringTemplateMeta.fromJson(e.cast<String, dynamic>()),
              )
              .toList()
        : const <RecurringTemplateMeta>[];

    return ExpenseGroupsCatalog(groups: groups, recurringTemplates: templates);
  }

  Future<List<ExpenseGroup>> fetchGroups({int? year}) async {
    final catalog = await fetchGroupsCatalog(year: year);
    return catalog.groups;
  }

  Future<ExpenseGroup> createGroup({
    required String name,
    String color = '#0A7D76',
    bool countsAsExpense = true,
  }) async {
    final resp = await _api.post(
      '/finance/expense-groups',
      body: {
        'name': name.trim(),
        'color': color,
        'counts_as_expense': countsAsExpense,
      },
    );
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return ExpenseGroup.fromJson(item);
  }

  Future<List<MoneyAccount>> fetchAccounts() async {
    final resp = await _api.get('/finance/money-accounts');
    final items = resp.list.isNotEmpty
        ? resp.list
        : (resp.object['items'] is List
              ? (resp.object['items'] as List)
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList()
              : const <Map<String, dynamic>>[]);
    return [for (final item in items) MoneyAccount.fromJson(item)];
  }

  Future<MoneyAccount> createAccount({
    required String name,
    MoneyAccountKind kind = MoneyAccountKind.bank,
  }) async {
    final resp = await _api.post(
      '/finance/money-accounts',
      body: {'name': name.trim(), 'kind': kind.apiValue},
    );
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return MoneyAccount.fromJson(item);
  }

  Future<MonthLedger> fetchMonthLedger({
    required String month,
    String? groupId,
    String? accountId,
    String? status,
    String? q,
  }) async {
    final ym = FinanceMonthUtils.toYearMonth(month);
    final resp = await _api.get(
      '/finance/expenses',
      query: {
        'month': ym,
        'group_id': ?groupId,
        'account_id': ?accountId,
        'status': ?status,
        'q': ?q,
      },
    );
    return MonthLedger.fromJson(resp.object);
  }

  /// Tạo khoản chi mới (`POST /finance/expenses`).
  /// Khi truyền `payments` (kể cả mảng rỗng `[]` cho khoản chưa trả theo hợp đồng E5),
  /// API cấm gửi đồng thời `status` / `paid_amount` (`prohibits:status,paid_amount`).
  Future<ExpenseItem> createExpense({
    required String spentOn,
    required String groupId,
    required String title,
    required int amount,
    ExpenseStatus? status,
    int? paidAmount,
    String? accountId,
    String? note,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final hasPayments = payments != null;
    final resp = await _api.post(
      '/finance/expenses',
      body: {
        'spent_on': spentOn,
        'group_id': groupId,
        'title': title.trim(),
        'amount': amount,
        if (!hasPayments && status != null) 'status': status.apiValue,
        if (!hasPayments && paidAmount != null) 'paid_amount': paidAmount,
        'account_id': ?accountId,
        'note': ?note,
        if (hasPayments) 'payments': payments,
        'attachments': ?attachments,
      },
    );
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return ExpenseItem.fromJson(item);
  }

  Future<ExpenseItem> updateExpense({
    required String id,
    required Map<String, dynamic> patch,
  }) async {
    final resp = await _api.put('/finance/expenses/$id', body: patch);
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return ExpenseItem.fromJson(item);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('/finance/expenses/$id');
  }

  Future<ExpenseItem> replacePayments({
    required String expenseId,
    required List<Map<String, dynamic>> payments,
  }) async {
    final resp = await _api.put(
      '/finance/expenses/$expenseId/payments',
      body: {'payments': payments},
    );
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return ExpenseItem.fromJson(item);
  }

  /// Tải tệp chứng từ / phiếu chi lên máy chủ (`POST /finance/attachments`).
  Future<ExpenseAttachment> uploadAttachment({
    required String filePath,
    String? filename,
  }) async {
    final resp = await _api.upload(
      '/finance/attachments',
      field: 'file',
      filePath: filePath,
      filename: filename,
    );
    final body = resp.object;
    final item = body['item'] is Map
        ? (body['item'] as Map).cast<String, dynamic>()
        : body;
    return ExpenseAttachment.fromJson(item);
  }
}
