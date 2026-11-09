import 'dart:math' as math;

import '../../core/utils/formatters.dart';
import '../../core/utils/text_search.dart';
import '../../modules/finance/domain/finance_models.dart';
import '../demo_backend.dart';
import '../demo_seed.dart';

/// Kho dữ liệu trong RAM cho phân hệ **Sổ chi phí** ở chế độ Demo và kiểm thử.
/// Mô phỏng chính xác hợp đồng `/api/v1/finance/*` của Laravel API
/// (`CreateExpenseRequest`, `SaveExpense`, `ReplaceExpensePayments`, `BuildMonthLedger`).
class FinanceDemoStore {
  FinanceDemoStore({this.clock, bool seedInitialData = true}) {
    _initCatalog();
    if (seedInitialData) {
      _seedSampleExpenses();
    }
  }

  final DateTime? clock;

  final List<Map<String, dynamic>> groups = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> accounts = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> recurringTemplates =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> expenses = <Map<String, dynamic>>[];

  int _seq = 1;

  String _nextId(String prefix) => '${prefix}_${_seq++}';

  String get _todayIso {
    final now = VnTime.now(clock);
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get _nowIsoUtc => (clock ?? DateTime.now()).toUtc().toIso8601String();

  void _initCatalog() {
    groups.addAll([
      {
        'id': 'g_op',
        'name': 'Vận hành & kho',
        'color': '#0A7D76',
        'sort_order': 1,
        'counts_as_expense': true,
        'archived': false,
      },
      {
        'id': 'g_pe',
        'name': 'Nhân sự & lương',
        'color': '#2563EB',
        'sort_order': 2,
        'counts_as_expense': true,
        'archived': false,
      },
      {
        'id': 'g_mk',
        'name': 'Tiếp thị & khách',
        'color': '#D97706',
        'sort_order': 3,
        'counts_as_expense': true,
        'archived': false,
      },
      {
        'id': 'g_sw',
        'name': 'Phần mềm & dịch vụ',
        'color': '#7C3AED',
        'sort_order': 4,
        'counts_as_expense': true,
        'archived': false,
      },
      {
        'id': 'g_tax',
        'name': 'Thuế & phí',
        'color': '#DC2626',
        'sort_order': 5,
        'counts_as_expense': true,
        'archived': false,
      },
      {
        'id': 'g_profit',
        'name': 'Chia lợi nhuận',
        'color': '#64748B',
        'sort_order': 6,
        'counts_as_expense': false,
        'archived': false,
      },
    ]);

    accounts.addAll([
      {
        'id': 'acc_bank',
        'name': 'TK ngân hàng',
        'kind': 'bank',
        'archived': false,
      },
      {'id': 'acc_cash', 'name': 'Tiền mặt', 'kind': 'cash', 'archived': false},
      {
        'id': 'acc_advance',
        'name': 'Tiền ứng',
        'kind': 'advance',
        'archived': false,
      },
    ]);

    recurringTemplates.addAll([
      {
        'key': 'warehouse',
        'title': 'Chi phí kho',
        'group_id': 'g_op',
        'group_name': 'Vận hành & kho',
      },
      {
        'key': 'utility',
        'title': 'Điện nước',
        'group_id': 'g_op',
        'group_name': 'Vận hành & kho',
      },
      {
        'key': 'loan_interest',
        'title': 'Lãi vay',
        'group_id': 'g_tax',
        'group_name': 'Thuế & phí',
      },
      {
        'key': 'accounting_fee',
        'title': 'Dịch vụ kế toán',
        'group_id': 'g_sw',
        'group_name': 'Phần mềm & dịch vụ',
      },
    ]);
  }

  void _seedSampleExpenses() {
    final m0 = FinanceMonthUtils.currentVnMonth(clock);
    final m1 = FinanceMonthUtils.shiftMonth(m0, -1);
    final m2 = FinanceMonthUtils.shiftMonth(m0, -2);
    final m3 = FinanceMonthUtils.shiftMonth(m0, -3);

    void seedPaid({
      required String ym,
      required int day,
      required String groupId,
      required String title,
      required int amount,
      String accountId = 'acc_bank',
      String timeUtc = '02:00:00Z',
    }) {
      final dd = day.toString().padLeft(2, '0');
      final spentOn = '$ym-$dd';
      final paidOn = FinanceMonthUtils.clampPaidOn(spentOn, clock);
      insertRawExpense(
        spentOn: spentOn,
        groupId: groupId,
        title: title,
        amount: amount,
        accountId: accountId,
        createdAt: '${spentOn}T$timeUtc',
        payments: [
          {
            'id': _nextId('pay'),
            'paid_on': paidOn,
            'amount': amount,
            'account_id': accountId,
          },
        ],
      );
    }

    // Lịch sử 3 tháng gần nhất để hệ thống tự gợi ý 5 khoản cố định
    for (final entry in [
      (ym: m3, util: 1950000),
      (ym: m2, util: 1920000),
      (ym: m1, util: 1850000),
    ]) {
      final mNum = FinanceMonthUtils.monthNumberOf(entry.ym);
      seedPaid(
        ym: entry.ym,
        day: 1,
        groupId: 'g_op',
        title: 'Chi phí kho T$mNum',
        amount: 12000000,
      );
      seedPaid(
        ym: entry.ym,
        day: 2,
        groupId: 'g_op',
        title: 'Điện nước T$mNum',
        amount: entry.util,
      );
      seedPaid(
        ym: entry.ym,
        day: 5,
        groupId: 'g_tax',
        title: 'Lãi vay T$mNum',
        amount: 4500000,
      );
      seedPaid(
        ym: entry.ym,
        day: 6,
        groupId: 'g_sw',
        title: 'Dịch vụ kế toán T$mNum',
        amount: 3000000,
      );
    }

    // Dữ liệu mẫu của tháng hiện tại (chưa ghi 5 khoản cố định để người dùng thử nghiệm)
    final m0Day1 = '$m0-01';
    final m0Day2 = FinanceMonthUtils.clampPaidOn('$m0-02', clock);
    insertRawExpense(
      spentOn: m0Day2,
      groupId: 'g_mk',
      title: 'Tiếp khách đối tác chiến lược',
      amount: 2450000,
      accountId: 'acc_cash',
      createdAt: '${m0Day1}T03:30:00Z',
      payments: [
        {
          'id': _nextId('pay'),
          'paid_on': m0Day2,
          'amount': 2450000,
          'account_id': 'acc_cash',
        },
      ],
      attachments: [
        {
          'id': 'att_demo_1',
          'name': 'Hoa-don-tiep-khach.jpg',
          'url': '/api/v1/finance/media/demo/att_demo_1/Hoa-don-tiep-khach.jpg',
          'mime_type': 'image/jpeg',
          'size': 419840,
          'uploaded_at': '${m0Day1}T03:32:00Z',
        },
      ],
    );
    insertRawExpense(
      spentOn: m0Day1,
      groupId: 'g_mk',
      title: 'Quảng cáo chiến dịch đầu tháng',
      amount: 6000000,
      accountId: 'acc_bank',
      createdAt: '${m0Day1}T02:15:00Z',
      payments: [
        {
          'id': _nextId('pay'),
          'paid_on': FinanceMonthUtils.clampPaidOn(m0Day1, clock),
          'amount': 3000000,
          'account_id': 'acc_bank',
        },
      ],
    );
    insertRawExpense(
      spentOn: m0Day1,
      groupId: 'g_op',
      title: 'Vật tư đóng gói & vận đơn',
      amount: 1650000,
      createdAt: '${m0Day1}T01:40:00Z',
      payments: const [],
    );
  }

  Map<String, dynamic>? _findGroup(String id) {
    for (final g in groups) {
      if (g['id'] == id) return g;
    }
    return null;
  }

  /// Số khoản chi của nhóm (mọi năm) — `expense_count` của API.
  int groupExpenseCount(String id) =>
      expenses.where((e) => e['group_id'] == id).length;

  /// Số khoản chi dùng nguồn tiền: khoản mang `account_id` hoặc có một lần
  /// trả từ nguồn đó.
  int accountExpenseCount(String id) => expenses.where((e) {
    if (e['account_id'] == id) return true;
    final pays = e['payments'];
    return pays is List &&
        pays.whereType<Map>().any((p) => p['account_id'] == id);
  }).length;

  Map<String, dynamic> groupJson(Map<String, dynamic> g) => {
    ...g,
    'expense_count': groupExpenseCount('${g['id']}'),
  };

  Map<String, dynamic> accountJson(Map<String, dynamic> a) => {
    ...a,
    'expense_count': accountExpenseCount('${a['id']}'),
  };

  Map<String, dynamic>? _findAccount(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in accounts) {
      if (a['id'] == id) return a;
    }
    return null;
  }

  /// Chèn trực tiếp bản ghi (hỗ trợ cả khoản hoàn âm `amount < 0` giống nhập Excel).
  Map<String, dynamic> insertRawExpense({
    String? id,
    required String spentOn,
    required String groupId,
    required String title,
    required int amount,
    String? accountId,
    String? status,
    int? paidAmount,
    String? note,
    String? createdAt,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? attachments,
  }) {
    final grp = _findGroup(groupId) ?? groups.first;
    final month = spentOn.length >= 7
        ? spentOn.substring(0, 7)
        : FinanceMonthUtils.currentVnMonth(clock);
    final normalizedPayments = <Map<String, dynamic>>[
      for (final p in payments ?? const <Map<String, dynamic>>[])
        {
          'id': (p['id'] as String?)?.isNotEmpty == true
              ? p['id']
              : _nextId('pay'),
          'paid_on': '${p['paid_on'] ?? spentOn}',
          'amount': (p['amount'] as num?)?.round() ?? 0,
          'account_id': p['account_id'],
          'account_name':
              _findAccount(p['account_id'] as String?)?['name'] ??
              p['account_name'],
          'note': p['note'],
        },
    ];

    String resolvedStatus;
    int? resolvedPaid;
    int resolvedOutstanding;
    String? resolvedAccId = accountId;

    if (amount < 0) {
      resolvedStatus = 'paid';
      resolvedPaid = amount;
      resolvedOutstanding = 0;
    } else if (payments != null) {
      final sum = normalizedPayments.fold<int>(
        0,
        (acc, p) => acc + ((p['amount'] as int?) ?? 0),
      );
      resolvedPaid = sum;
      resolvedOutstanding = math.max(0, amount - sum);
      if (sum <= 0) {
        resolvedStatus = 'unpaid';
      } else if (sum >= amount) {
        resolvedStatus = 'paid';
      } else {
        resolvedStatus = 'partial';
      }
      if (normalizedPayments.isNotEmpty) {
        resolvedAccId =
            normalizedPayments.last['account_id'] as String? ?? resolvedAccId;
      }
    } else {
      resolvedStatus = status ?? 'unpaid';
      resolvedPaid = switch (resolvedStatus) {
        'paid' => amount,
        'partial' => paidAmount,
        _ => 0,
      };
      resolvedOutstanding = switch (resolvedStatus) {
        'paid' => 0,
        'partial' => math.max(0, amount - (paidAmount ?? 0)),
        _ => math.max(0, amount),
      };
    }

    final accObj = _findAccount(resolvedAccId);
    final record = <String, dynamic>{
      'id': id ?? demoNewId(),
      'spent_on': spentOn,
      'month': month,
      'group_id': grp['id'],
      'group_name': grp['name'],
      'group_color': grp['color'],
      'counts_as_expense': grp['counts_as_expense'] != false,
      'title': title,
      'amount': amount,
      'account_id': resolvedAccId,
      'account_name': accObj?['name'],
      'status': resolvedStatus,
      'paid_amount': resolvedPaid,
      'outstanding': resolvedOutstanding,
      'note': note,
      'created_at': createdAt ?? _nowIsoUtc,
      'payments': normalizedPayments,
      'attachments': <Map<String, dynamic>>[
        for (final a in attachments ?? const <Map<String, dynamic>>[])
          Map<String, dynamic>.from(a),
      ],
    };
    expenses.insert(0, record);
    return record;
  }

  Map<String, dynamic> buildLedgerResponse({
    required String month,
    String? groupId,
    String? accountId,
    String? status,
    String? query,
  }) {
    final ym = FinanceMonthUtils.toYearMonth(month);
    final monthAll = expenses.where((e) => e['month'] == ym).toList();

    final filtered = monthAll.where((e) {
      if (groupId != null && groupId.isNotEmpty && e['group_id'] != groupId) {
        return false;
      }
      if (accountId != null &&
          accountId.isNotEmpty &&
          e['account_id'] != accountId) {
        return false;
      }
      if (status != null && status.isNotEmpty) {
        final st = '${e['status']}';
        if (status == 'owe') {
          if (st != 'unpaid' && st != 'partial') return false;
        } else if (st != status) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final hay = foldDiacritics(
          '${e['title']} ${e['group_name'] ?? ''} ${e['account_name'] ?? ''} ${e['amount']}',
        );
        if (!hay.contains(foldDiacritics(query.trim()))) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final cmpDate = '${b['spent_on']}'.compareTo('${a['spent_on']}');
      if (cmpDate != 0) return cmpDate;
      return '${b['created_at']}'.compareTo('${a['created_at']}');
    });

    var total = 0;
    var paid = 0;
    var outstanding = 0;
    var count = 0;
    var paidCount = 0;
    var unpaidCount = 0;
    var partialCount = 0;
    var excludedTotal = 0;
    var excludedCount = 0;
    var cashOutTotal = 0;
    var cashOutCount = 0;

    final byGroupAccum = <String, ({int amount, int count})>{};

    for (final e in filtered) {
      final gId = '${e['group_id']}';
      final amt = (e['amount'] as int?) ?? 0;
      final countsAsExp = e['counts_as_expense'] != false;
      final st = '${e['status']}';
      final paidAmt = (e['paid_amount'] as int?) ?? (st == 'paid' ? amt : 0);
      final outAmt = (e['outstanding'] as int?) ?? math.max(0, amt - paidAmt);

      final prevG = byGroupAccum[gId];
      byGroupAccum[gId] = (
        amount: (prevG?.amount ?? 0) + amt,
        count: (prevG?.count ?? 0) + 1,
      );

      if (paidAmt > 0) {
        cashOutTotal += paidAmt;
        cashOutCount++;
      }

      if (!countsAsExp) {
        excludedTotal += amt;
        excludedCount++;
        continue;
      }

      total += amt;
      paid += paidAmt;
      outstanding += outAmt;
      count++;
      if (st == 'paid') {
        paidCount++;
      } else if (st == 'partial') {
        partialCount++;
      } else {
        unpaidCount++;
      }
    }

    final byGroup = <Map<String, dynamic>>[];
    for (final entry in byGroupAccum.entries) {
      final grp = _findGroup(entry.key);
      byGroup.add({
        'group_id': entry.key,
        'name': grp?['name'] ?? entry.key,
        'color': grp?['color'] ?? '#0A7D76',
        'counts_as_expense': grp?['counts_as_expense'] != false,
        'amount': entry.value.amount,
        'count': entry.value.count,
      });
    }
    byGroup.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

    final prevYm = FinanceMonthUtils.shiftMonth(ym, -1);
    final prevItems = expenses.where(
      (e) => e['month'] == prevYm && e['counts_as_expense'] != false,
    );
    final prevTotal = prevItems.isEmpty
        ? null
        : prevItems.fold<int>(0, (s, e) => s + ((e['amount'] as int?) ?? 0));

    return {
      'month': ym,
      'items': filtered,
      'summary': {
        'total': total,
        'paid': paid,
        'outstanding': outstanding,
        'count': count,
        'paid_count': paidCount,
        'unpaid_count': unpaidCount,
        'partial_count': partialCount,
        'excluded': {'total': excludedTotal, 'count': excludedCount},
        'by_group': byGroup,
        'prev_month': {'month': prevYm, 'total': prevTotal},
        'revenue': {'collected': 0, 'order_count': 0},
        'cash_out': {'total': cashOutTotal, 'payment_count': cashOutCount},
      },
    };
  }
}

FinanceDemoStore registerFinanceDemo(
  DemoRoutes r, {
  DateTime? clock,
  bool seedInitialData = true,
}) {
  final store = FinanceDemoStore(
    clock: clock,
    seedInitialData: seedInitialData,
  );

  r.get('/finance/expense-groups', (req) {
    final year = req.qInt('year', VnTime.now(clock).year);
    return DemoResponse(200, {
      'success': true,
      'meta': {'year': year, 'recurring_templates': store.recurringTemplates},
      'data': [for (final g in store.groups) store.groupJson(g)],
    });
  });

  r.post('/finance/expense-groups', (req) {
    final b = req.json;
    final grp = <String, dynamic>{
      'id': demoNewId(),
      'name': '${b['name'] ?? 'Nhóm mới'}'.trim(),
      'color': '${b['color'] ?? '#0A7D76'}',
      'sort_order': store.groups.length + 1,
      'counts_as_expense': b['counts_as_expense'] != false,
      'archived': false,
    };
    store.groups.add(grp);
    return created(grp);
  });

  r.put('/finance/expense-groups/{id}', (req) {
    final grp = store._findGroup(req.params['id'] ?? '');
    if (grp == null) return notFound();
    final b = req.json;
    if (b.containsKey('name')) grp['name'] = '${b['name']}'.trim();
    if (b.containsKey('color')) grp['color'] = '${b['color']}';
    if (b.containsKey('counts_as_expense')) {
      grp['counts_as_expense'] = b['counts_as_expense'] == true;
    }
    if (b.containsKey('archived')) grp['archived'] = b['archived'] == true;
    return ok(store.groupJson(grp));
  });

  // Khớp ExpenseCatalogController::destroyGroup: còn khoản → 422.
  r.delete('/finance/expense-groups/{id}', (req) {
    final id = req.params['id'] ?? '';
    if (store._findGroup(id) == null) return notFound();
    final left = store.groupExpenseCount(id);
    if (left > 0) {
      return unprocessable('Nhóm còn $left khoản chi, không xoá được.');
    }
    store.groups.removeWhere((g) => g['id'] == id);
    return noContent;
  });

  r.get(
    '/finance/money-accounts',
    (_) => ok([for (final a in store.accounts) store.accountJson(a)]),
  );

  r.put('/finance/money-accounts/{id}', (req) {
    final acc = store._findAccount(req.params['id']);
    if (acc == null) return notFound();
    final b = req.json;
    if (b.containsKey('name')) acc['name'] = '${b['name']}'.trim();
    if (b.containsKey('kind')) acc['kind'] = '${b['kind']}';
    if (b.containsKey('archived')) acc['archived'] = b['archived'] == true;
    return ok(store.accountJson(acc));
  });

  r.delete('/finance/money-accounts/{id}', (req) {
    final id = req.params['id'] ?? '';
    if (store._findAccount(id) == null) return notFound();
    final left = store.accountExpenseCount(id);
    if (left > 0) {
      return unprocessable('Nguồn tiền còn $left khoản chi, không xoá được.');
    }
    store.accounts.removeWhere((a) => a['id'] == id);
    return noContent;
  });

  r.post('/finance/money-accounts', (req) {
    final b = req.json;
    final acc = <String, dynamic>{
      'id': demoNewId(),
      'name': '${b['name'] ?? 'Tài khoản mới'}'.trim(),
      'kind': '${b['kind'] ?? 'bank'}',
      'archived': false,
    };
    store.accounts.add(acc);
    return created(acc);
  });

  r.get('/finance/expenses', (req) {
    final month = req.q('month') ?? FinanceMonthUtils.currentVnMonth(clock);
    return ok(
      store.buildLedgerResponse(
        month: month,
        groupId: req.q('group_id'),
        accountId: req.q('account_id'),
        status: req.q('status'),
        query: req.q('q'),
      ),
    );
  });

  r.post('/finance/expenses', (req) {
    final b = req.json;
    // Khớp CreateExpenseRequest: prohibits:status,paid_amount khi có payments
    if (b.containsKey('payments') &&
        (b.containsKey('status') || b.containsKey('paid_amount'))) {
      return unprocessable(
        'Không gửi đồng thời payments cùng status hoặc paid_amount.',
      );
    }

    final rawPayments = b['payments'];
    List<Map<String, dynamic>>? payments;
    if (rawPayments is List) {
      payments = [
        for (final p in rawPayments.whereType<Map>())
          Map<String, dynamic>.from(p),
      ];
      for (final p in payments) {
        final paidOn = '${p['paid_on'] ?? ''}';
        if (paidOn.compareTo(store._todayIso) > 0) {
          return unprocessable('Ngày thanh toán không được ở tương lai.');
        }
      }
    }

    final rawAtt = b['attachments'];
    final attachments = rawAtt is List
        ? [
            for (final a in rawAtt.whereType<Map>())
              Map<String, dynamic>.from(a),
          ]
        : null;

    final record = store.insertRawExpense(
      spentOn: '${b['spent_on'] ?? store._todayIso}',
      groupId: '${b['group_id'] ?? store.groups.first['id']}',
      title: '${b['title'] ?? ''}'.trim(),
      amount: (b['amount'] as num?)?.round() ?? 0,
      accountId: b['account_id'] as String?,
      status: b['status'] as String?,
      paidAmount: (b['paid_amount'] as num?)?.round(),
      note: b['note'] as String?,
      payments: payments,
      attachments: attachments,
    );
    return created(record);
  });

  r.put('/finance/expenses/{id}', (req) {
    final id = req.params['id'] ?? '';
    final idx = store.expenses.indexWhere((e) => e['id'] == id);
    if (idx < 0) return notFound();
    final cur = store.expenses[idx];
    final b = req.json;

    if (b.containsKey('amount')) {
      final newAmt = (b['amount'] as num).round();
      final curPayments = (cur['payments'] as List?) ?? const [];
      final paidSum = curPayments.fold<int>(
        0,
        (s, p) => s + (((p as Map)['amount'] as int?) ?? 0),
      );
      if (curPayments.isNotEmpty && newAmt < paidSum) {
        return unprocessable('Số tiền nhỏ hơn tổng đã thanh toán.');
      }
      cur['amount'] = newAmt;
    }
    if (b.containsKey('title')) {
      cur['title'] = '${b['title']}'.trim();
    }
    if (b.containsKey('spent_on')) {
      final spent = '${b['spent_on']}';
      cur['spent_on'] = spent;
      if (spent.length >= 7) cur['month'] = spent.substring(0, 7);
    }
    if (b.containsKey('group_id')) {
      final grp = store._findGroup('${b['group_id']}');
      if (grp != null) {
        cur['group_id'] = grp['id'];
        cur['group_name'] = grp['name'];
        cur['group_color'] = grp['color'];
        cur['counts_as_expense'] = grp['counts_as_expense'] != false;
      }
    }
    if (b.containsKey('account_id')) {
      final accId = b['account_id'] as String?;
      cur['account_id'] = accId;
      cur['account_name'] = store._findAccount(accId)?['name'];
    }
    if (b.containsKey('note')) {
      cur['note'] = b['note'];
    }
    if (b.containsKey('attachments') && b['attachments'] is List) {
      cur['attachments'] = [
        for (final a in (b['attachments'] as List).whereType<Map>())
          Map<String, dynamic>.from(a),
      ];
    }

    // Recompute status / outstanding
    final amt = (cur['amount'] as int?) ?? 0;
    final curPayments = (cur['payments'] as List?) ?? const [];
    if (amt >= 0) {
      if (curPayments.isNotEmpty) {
        final sum = curPayments.fold<int>(
          0,
          (s, p) => s + (((p as Map)['amount'] as int?) ?? 0),
        );
        cur['paid_amount'] = sum;
        cur['outstanding'] = math.max(0, amt - sum);
        cur['status'] = sum <= 0 ? 'unpaid' : (sum >= amt ? 'paid' : 'partial');
      } else {
        if (b.containsKey('status')) cur['status'] = '${b['status']}';
        final st = '${cur['status']}';
        if (st == 'paid') {
          cur['paid_amount'] = amt;
          cur['outstanding'] = 0;
        } else if (st == 'unpaid') {
          cur['paid_amount'] = 0;
          cur['outstanding'] = amt;
        } else {
          final pa = (cur['paid_amount'] as int?) ?? 0;
          cur['outstanding'] = math.max(0, amt - pa);
        }
      }
    }
    return ok(cur);
  });

  r.put('/finance/expenses/{id}/payments', (req) {
    final id = req.params['id'] ?? '';
    final idx = store.expenses.indexWhere((e) => e['id'] == id);
    if (idx < 0) return notFound();
    final cur = store.expenses[idx];
    final amt = (cur['amount'] as int?) ?? 0;
    if (amt < 0) {
      return unprocessable('Không thay đổi đợt trả cho khoản hoàn/giảm trừ.');
    }

    final rawList = req.json['payments'];
    final nextPayments = <Map<String, dynamic>>[];
    if (rawList is List) {
      for (final raw in rawList.whereType<Map>()) {
        final paidOn = '${raw['paid_on'] ?? store._todayIso}';
        if (paidOn.compareTo(store._todayIso) > 0) {
          return unprocessable('Ngày thanh toán không được ở tương lai.');
        }
        final accId = raw['account_id'] as String?;
        nextPayments.add({
          'id': (raw['id'] as String?)?.isNotEmpty == true
              ? raw['id']
              : store._nextId('pay'),
          'paid_on': paidOn,
          'amount': (raw['amount'] as num?)?.round() ?? 0,
          'account_id': accId,
          'account_name':
              store._findAccount(accId)?['name'] ?? raw['account_name'],
          'note': raw['note'],
        });
      }
    }

    final sum = nextPayments.fold<int>(
      0,
      (s, p) => s + ((p['amount'] as int?) ?? 0),
    );
    if (sum > amt) {
      return unprocessable('Tổng thanh toán vượt quá số tiền khoản chi.');
    }

    cur['payments'] = nextPayments;
    cur['paid_amount'] = sum;
    cur['outstanding'] = math.max(0, amt - sum);
    cur['status'] = sum <= 0 ? 'unpaid' : (sum >= amt ? 'paid' : 'partial');
    if (nextPayments.isNotEmpty) {
      final lastAccId = nextPayments.last['account_id'] as String?;
      if (lastAccId != null) {
        cur['account_id'] = lastAccId;
        cur['account_name'] = store._findAccount(lastAccId)?['name'];
      }
    }
    return ok(cur);
  });

  r.delete('/finance/expenses/{id}', (req) {
    final before = store.expenses.length;
    store.expenses.removeWhere((e) => e['id'] == req.params['id']);
    return store.expenses.length < before ? noContent : notFound();
  });

  r.post('/finance/attachments', (req) {
    final b = req.json;
    final name = '${b['file'] ?? 'chung-tu.jpg'}';
    final id = store._nextId('att');
    final isPdf = name.toLowerCase().endsWith('.pdf');
    return created({
      'id': id,
      'name': name,
      'url': '/api/v1/finance/media/demo/$id/$name',
      'mime_type': isPdf ? 'application/pdf' : 'image/jpeg',
      'size': isPdf ? 245760 : 419840,
      'uploaded_at': store._nowIsoUtc,
    });
  });

  return store;
}
