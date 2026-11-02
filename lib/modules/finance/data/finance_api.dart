import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/finance_models.dart';

final financeApiProvider = Provider<FinanceApi>((ref) {
  return FinanceApi(ref.watch(apiClientProvider));
});

/// API client cho Sổ chi phí (`/finance/...`, tương đối với `/api/v1`).
class FinanceApi {
  const FinanceApi(this._api);

  final ApiClient _api;

  Future<List<ExpenseGroup>> fetchGroups() async {
    final resp = await _api.get('/finance/expense-groups');
    final items = resp.list.isNotEmpty
        ? resp.list
        : (resp.object['items'] is List
              ? (resp.object['items'] as List)
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList()
              : const <Map<String, dynamic>>[]);
    return [for (final item in items) ExpenseGroup.fromJson(item)];
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
    String? status,
  }) async {
    final ym = FinanceMonthUtils.toYearMonth(month);
    final resp = await _api.get(
      '/finance/expenses',
      query: {
        'month': ym,
        'group_id': ?groupId,
        'status': ?status,
      },
    );
    return MonthLedger.fromJson(resp.object);
  }

  Future<ExpenseItem> createExpense({
    required String spentOn,
    required String groupId,
    required String title,
    required int amount,
    required ExpenseStatus status,
    int? paidAmount,
    String? accountId,
    String? note,
  }) async {
    final resp = await _api.post(
      '/finance/expenses',
      body: {
        'spent_on': spentOn,
        'group_id': groupId,
        'title': title.trim(),
        'amount': amount,
        'status': status.apiValue,
        'paid_amount': ?paidAmount,
        'account_id': ?accountId,
        'note': ?note,
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
}
