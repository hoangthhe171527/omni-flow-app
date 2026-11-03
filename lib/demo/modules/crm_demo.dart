import '../demo_backend.dart';
import '../demo_seed.dart';

/// Dữ liệu mẫu: khách hàng, cơ hội, nhật ký tương tác, doanh thu Tổng quan.
///
/// Mọi khách, số điện thoại, email, địa chỉ, mã số thuế đều là BỊA. Trạng thái
/// nằm trong [_CrmStore] tạo mới mỗi lần dựng route: sửa trong phiên thì GET
/// sau thấy ngay, đóng app là mất — bản demo không ghi gì xuống máy.
void registerCrmDemo(DemoRoutes r, [DemoLinks? links]) {
  final s = _CrmStore()..seed();
  links?.createCustomer = ({required name, phone, source}) {
    final res = s.createCustomer(
      DemoRequest(
        method: 'POST',
        path: '/customers',
        params: const {},
        query: const {},
        body: {
          'display_name': name,
          'primary_contact_phone': ?phone,
          'metadata': {'source': ?source},
        },
      ),
    );
    return ((res.json! as Map)['data'] as Map)['id'] as String;
  };

  // ---- Khách hàng ---------------------------------------------------------
  // `check-duplicate` phải đứng trước `/customers/{id}` (cùng hai đoạn).
  r.get('/customers/check-duplicate', (req) {
    final phone = _digits(req.q('phone') ?? '');
    final email = (req.q('email') ?? '').trim().toLowerCase();
    final matches = s.customers.values.where((c) {
      final p = _digits('${c['primary_contact_phone'] ?? ''}');
      final e = '${c['primary_contact_email'] ?? ''}'.trim().toLowerCase();
      return (phone.isNotEmpty && p == phone) ||
          (email.isNotEmpty && e == email);
    });
    return ok([
      for (final c in matches)
        {
          'id': c['id'],
          'display_name': c['display_name'],
          'legal_name': c['legal_name'],
          'primary_contact_phone': c['primary_contact_phone'],
          'in_scope': true,
        },
    ]);
  });

  r.get('/customers', (req) => paged(req, s.listCustomers(req)));
  r.get('/customers/{id}', (req) {
    final c = s.customers[req.params['id']];
    return c == null
        ? notFound('Không tìm thấy khách hàng.')
        : ok(s.customerJson(c));
  });
  r.get('/customers/{id}/summary', (req) {
    final c = s.customers[req.params['id']];
    return c == null
        ? notFound('Không tìm thấy khách hàng.')
        : ok(s.summaryJson(c));
  });
  r.post('/customers', s.createCustomer);
  r.put('/customers/{id}', s.updateCustomer);
  r.patch('/customers/{id}', s.updateCustomer);
  r.delete('/customers/{id}', (req) {
    final removed = s.customers.remove(req.params['id']);
    return removed == null ? notFound('Không tìm thấy khách hàng.') : ok(null);
  });

  // ---- Nhật ký tương tác ---------------------------------------------------
  r.get('/interaction-logs', (req) => paged(req, s.listLogs(req)));
  r.post('/interaction-logs', s.createLog);

  // ---- Cơ hội -------------------------------------------------------------
  // Các đường cố định trước `/sales-opportunities/{id}`.
  r.get('/sales-opportunities/pipelines', (_) => ok(_pipelineCatalog));
  r.get('/sales-opportunities/summary', (req) => ok(s.pipelineSummary(req)));
  r.get('/sales-opportunities', (req) => paged(req, s.listOpportunities(req)));
  r.get('/sales-opportunities/{id}', (req) {
    final o = s.opportunities[req.params['id']];
    return o == null
        ? notFound('Không tìm thấy cơ hội.')
        : ok(s.opportunityJson(o));
  });
  r.post('/sales-opportunities', s.createOpportunity);
  r.put('/sales-opportunities/{id}', s.updateOpportunity);
  r.patch('/sales-opportunities/{id}/stage', s.moveStage);
  r.post('/sales-opportunities/{id}/win', s.markWon);
  r.delete('/sales-opportunities/{id}', (req) {
    final removed = s.opportunities.remove(req.params['id']);
    return removed == null ? notFound('Không tìm thấy cơ hội.') : ok(null);
  });

  // ---- Tổng quan: doanh thu ------------------------------------------------
  r.get('/sales-overview/revenue-series', s.revenueSeries);
}

// ===========================================================================
// Quy trình bán hàng
// ===========================================================================

const _pipelineCode = 'standard';

const _stages = <Map<String, dynamic>>[
  {
    'code': 'new',
    'label': 'Mới',
    'outcome': 'open',
    'probability': 10,
    'sort_order': 1,
    'color': '#94a3b8',
  },
  {
    'code': 'consulted',
    'label': 'Đã tư vấn',
    'outcome': 'open',
    'probability': 25,
    'sort_order': 2,
    'color': '#60a5fa',
  },
  {
    'code': 'quoted',
    'label': 'Đã báo giá',
    'outcome': 'open',
    'probability': 50,
    'sort_order': 3,
    'color': '#a78bfa',
  },
  {
    'code': 'negotiating',
    'label': 'Đàm phán',
    'outcome': 'open',
    'probability': 75,
    'sort_order': 4,
    'color': '#f59e0b',
  },
  {
    'code': 'won',
    'label': 'Chốt',
    'outcome': 'won',
    'probability': 100,
    'sort_order': 5,
    'color': '#22c55e',
  },
  {
    'code': 'lost',
    'label': 'Thất bại',
    'outcome': 'lost',
    'probability': 0,
    'sort_order': 6,
    'color': '#ef4444',
  },
];

const _pipelineCatalog = <String, dynamic>{
  'default': _pipelineCode,
  'pipelines': [
    {
      'code': _pipelineCode,
      'label': 'Bán hàng chuẩn',
      'is_default': true,
      'color': '#2563eb',
      'stages': _stages,
    },
  ],
};

Map<String, dynamic>? _stage(String? code) {
  for (final st in _stages) {
    if (st['code'] == code) return st;
  }
  return null;
}

String _outcomeOf(String? code) => '${_stage(code)?['outcome'] ?? 'open'}';

String _statusOf(String? code) => switch (_outcomeOf(code)) {
  'won' => 'WON',
  'lost' => 'LOST',
  _ => 'OPEN',
};

// ===========================================================================
// Kho trong RAM
// ===========================================================================

class _CrmStore {
  final customers = <String, Map<String, dynamic>>{};
  final opportunities = <String, Map<String, dynamic>>{};
  final logs = <String, Map<String, dynamic>>{};

  /// Doanh thu phát sinh trong phiên (cơ hội vừa chốt), theo ngày giờ VN.
  final _extraRevenue = <String, double>{};

  int _customerSeq = 0;
  int _opportunitySeq = 0;

  // ---- Khách ---------------------------------------------------------------

  Map<String, dynamic> customerJson(Map<String, dynamic> c) {
    final owner = demoPersonById(c['assigned_sales_rep_id'] as String?);
    return {
      ...c,
      'tenant_id': demoTenantId,
      'assigned_sales_rep_name': owner?.name,
      'assigned_sales_rep_email': owner?.email,
      'orders_total': c['orders_total'] ?? 0,
      'last_interaction_at': _lastInteraction(c['id'] as String),
    };
  }

  String? _lastInteraction(String customerId) {
    String? latest;
    for (final log in logs.values) {
      if (log['customer_id'] != customerId) continue;
      if (log['interaction_type'] == 'VIEW') continue;
      final at = log['interacted_at'] as String;
      if (latest == null || at.compareTo(latest) > 0) latest = at;
    }
    return latest;
  }

  Map<String, dynamic> summaryJson(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final total = (c['orders_total'] as num?) ?? 0;
    final count = (c['orders_count'] as num?) ?? 0;
    return {
      'orders': {'count': count, 'total_amount': total},
      'paid': total,
      'outstanding': 0,
      'last_order_at': c['last_order_at'],
      'opportunities_count': opportunities.values
          .where((o) => o['customer_id'] == id)
          .length,
      'quotes_count': 0,
    };
  }

  List<Map<String, dynamic>> listCustomers(DemoRequest req) {
    final search = _fold(req.q('search') ?? '');
    final searchDigits = _digits(req.q('search') ?? '');
    final owner = req.q('assigned_sales_rep_id');
    final statuses = req
        .q('customer_status')
        ?.split(',')
        .map((e) => e.trim())
        .toSet();
    final tab = req.q('tab');
    final monthStart = _vnMonthStartIso();

    final rows =
        customers.values.where((c) {
          if (owner != null && c['assigned_sales_rep_id'] != owner) {
            return false;
          }
          if (statuses != null && !statuses.contains(c['customer_status'])) {
            return false;
          }
          if (tab == 'new_month' &&
              '${c['created_at']}'.compareTo(monthStart) < 0) {
            return false;
          }
          if (search.isNotEmpty) {
            final hay = _fold(
              [
                c['display_name'],
                c['legal_name'],
                c['primary_contact_name'],
                c['primary_contact_email'],
                c['customer_code'],
              ].whereType<String>().join(' '),
            );
            final phone = _digits('${c['primary_contact_phone'] ?? ''}');
            final byPhone =
                searchDigits.length >= 3 && phone.contains(searchDigits);
            if (!hay.contains(search) && !byPhone) return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'),
        );
    return [for (final c in rows) customerJson(c)];
  }

  DemoResponse createCustomer(DemoRequest req) {
    final body = req.json;
    final name = '${body['display_name'] ?? body['legal_name'] ?? ''}'.trim();
    if (name.isEmpty) {
      return _invalid('legal_name', 'Vui lòng nhập tên khách hàng.');
    }
    final phone = '${body['primary_contact_phone'] ?? ''}'.trim();
    if (phone.isNotEmpty && _digits(phone).length < 9) {
      return _invalid('primary_contact_phone', 'Số điện thoại chưa đúng.');
    }

    final id = demoNewId();
    final now = demoAgo();
    _customerSeq++;
    final c = <String, dynamic>{
      'id': id,
      'customer_code': 'KH-${_customerSeq.toString().padLeft(4, '0')}',
      'legal_name': '${body['legal_name'] ?? name}'.trim(),
      'display_name': name,
      'customer_type': body['customer_type'] ?? 'DIRECT_CLIENT',
      'industry_category': null,
      'tax_code': _blankToNull(body['tax_code']),
      'primary_contact_name':
          _blankToNull(body['primary_contact_name']) ?? name,
      'primary_contact_phone': _blankToNull(body['primary_contact_phone']),
      'primary_contact_email': _blankToNull(body['primary_contact_email']),
      'address': _blankToNull(body['address']),
      // Không chọn người phụ trách thì máy chủ giao cho người tạo.
      'assigned_sales_rep_id': body.containsKey('assigned_sales_rep_id')
          ? body['assigned_sales_rep_id']
          : demoMeId,
      'customer_status': body['customer_status'] ?? 'ACTIVE',
      'metadata': _mergeMeta(const {}, body['metadata']),
      'orders_total': 0,
      'orders_count': 0,
      'last_order_at': null,
      'created_at': now,
      'updated_at': now,
    };
    customers[id] = c;
    return created(customerJson(c));
  }

  DemoResponse updateCustomer(DemoRequest req) {
    final c = customers[req.params['id']];
    if (c == null) return notFound('Không tìm thấy khách hàng.');
    final body = req.json;
    const editable = [
      'legal_name',
      'display_name',
      'customer_type',
      'tax_code',
      'primary_contact_name',
      'primary_contact_phone',
      'primary_contact_email',
      'address',
      'assigned_sales_rep_id',
      'customer_status',
    ];
    if (body.containsKey('display_name') &&
        '${body['display_name'] ?? ''}'.trim().isEmpty) {
      return _invalid('display_name', 'Tên khách hàng không được để trống.');
    }
    for (final key in editable) {
      if (body.containsKey(key)) c[key] = _blankToNull(body[key]);
    }
    if (body['metadata'] is Map) {
      c['metadata'] = _mergeMeta(c['metadata'] as Map, body['metadata']);
    }
    c['updated_at'] = demoAgo();
    return ok(customerJson(c));
  }

  // ---- Nhật ký ---------------------------------------------------------------

  Map<String, dynamic> logJson(Map<String, dynamic> log) {
    final c = customers[log['customer_id']];
    return {
      ...log,
      'customer_name': c?['display_name'] ?? log['customer_name'],
    };
  }

  List<Map<String, dynamic>> listLogs(DemoRequest req) {
    final customerId = req.q('customer_id');
    final opportunityId = req.q('sales_opportunity_id');
    final type = req.q('interaction_type');
    final exclude = (req.q('exclude_types') ?? '').split(',').toSet();
    final rows =
        logs.values.where((l) {
          if (customerId != null && l['customer_id'] != customerId) {
            return false;
          }
          if (opportunityId != null &&
              l['sales_opportunity_id'] != opportunityId) {
            return false;
          }
          if (type != null && l['interaction_type'] != type) return false;
          return !exclude.contains(l['interaction_type']);
        }).toList()..sort(
          (a, b) => '${b['interacted_at']}'.compareTo('${a['interacted_at']}'),
        );
    return [for (final l in rows) logJson(l)];
  }

  DemoResponse createLog(DemoRequest req) {
    final body = req.json;
    final customerId = body['customer_id'] as String?;
    if (customerId == null || !customers.containsKey(customerId)) {
      return _invalid('customer_id', 'Vui lòng chọn khách hàng.');
    }
    final content = '${body['content'] ?? ''}'.trim();
    if (content.isEmpty) return _invalid('content', 'Vui lòng nhập nội dung.');
    final log = _addLog(
      customerId: customerId,
      type: '${body['interaction_type'] ?? 'NOTE'}',
      content: content,
      at: body['interacted_at'] as String? ?? demoAgo(),
      opportunityId: body['sales_opportunity_id'] as String?,
      nextFollowUpAt: body['next_follow_up_at'] as String?,
    );
    return created(logJson(log));
  }

  Map<String, dynamic> _addLog({
    required String customerId,
    required String type,
    required String content,
    required String at,
    String? opportunityId,
    String? byUserId,
    String? nextFollowUpAt,
    bool auto = false,
  }) {
    final id = demoNewId();
    final log = <String, dynamic>{
      'id': id,
      'customer_id': customerId,
      'customer_name': customers[customerId]?['display_name'],
      'sales_opportunity_id': opportunityId,
      'performed_by_user_id': byUserId ?? demoMeId,
      'interaction_type': type,
      'content': content,
      'interacted_at': at,
      'next_follow_up_at': nextFollowUpAt,
      'metadata': {if (auto) 'auto': true},
      'created_at': at,
      'follow_up_completed_at': null,
    };
    logs[id] = log;
    return log;
  }

  // ---- Cơ hội -------------------------------------------------------------

  Map<String, dynamic> opportunityJson(Map<String, dynamic> o) {
    final owner = demoPersonById(o['owner_user_id'] as String?);
    final customer = customers[o['customer_id']];
    final meta = Map<String, dynamic>.from(o['metadata'] as Map);
    if (owner != null) meta['owner_name'] = owner.name;
    final customerName = customer?['display_name'] ?? meta['customer_name'];
    return {
      ...o,
      'customer_name': customerName,
      'metadata': meta,
      'outcome': _outcomeOf(o['opportunity_stage'] as String?),
    };
  }

  /// Bộ lọc chung của danh sách và tổng theo giai đoạn (không gồm giai đoạn/
  /// trạng thái).
  bool _matchesBoard(Map<String, dynamic> o, DemoRequest req) {
    final pipeline = req.q('pipeline')?.toLowerCase();
    // Quy trình mặc định cũng khớp cơ hội không ghi `pipeline`.
    if (pipeline != null && (o['pipeline'] ?? _pipelineCode) != pipeline) {
      return false;
    }
    if (req.q('owner') == 'me' && o['owner_user_id'] != demoMeId) return false;
    final ownerId = req.q('owner_user_id');
    if (ownerId != null && o['owner_user_id'] != ownerId) return false;
    final customerId = req.q('customer_id');
    if (customerId != null && o['customer_id'] != customerId) return false;
    final search = _fold(req.q('search') ?? '');
    if (search.isNotEmpty) {
      final hay = _fold(
        [
          o['title'],
          o['opportunity_code'],
          customers[o['customer_id']]?['display_name'],
          (o['metadata'] as Map)['customer_name'],
          (o['metadata'] as Map)['product'],
        ].whereType<String>().join(' '),
      );
      if (!hay.contains(search)) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> listOpportunities(DemoRequest req) {
    final stage = req.q('opportunity_stage');
    final statuses = req.q('status')?.toUpperCase().split(',').toSet();
    final rows =
        opportunities.values.where((o) {
          if (!_matchesBoard(o, req)) return false;
          if (stage != null && o['opportunity_stage'] != stage) return false;
          if (statuses != null && !statuses.contains(o['opportunity_status'])) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'),
        );
    return [for (final o in rows) opportunityJson(o)];
  }

  Map<String, dynamic> pipelineSummary(DemoRequest req) {
    final counts = <String, int>{};
    final values = <String, double>{};
    var wonMonthCount = 0;
    var wonMonthValue = 0.0;
    var lostMonthCount = 0;
    final monthStart = _vnMonthStartIso();
    var total = 0;
    for (final o in opportunities.values) {
      if (!_matchesBoard(o, req)) continue;
      total++;
      final code = o['opportunity_stage'] as String;
      final budget = (o['estimated_budget'] as num?)?.toDouble() ?? 0;
      counts[code] = (counts[code] ?? 0) + 1;
      values[code] = (values[code] ?? 0) + budget;
      final wonAt = o['won_at'] as String?;
      if (wonAt != null && wonAt.compareTo(monthStart) >= 0) {
        wonMonthCount++;
        wonMonthValue += budget;
      }
      final lostAt = o['lost_at'] as String?;
      if (lostAt != null && lostAt.compareTo(monthStart) >= 0) lostMonthCount++;
    }
    return {
      'total_count': total,
      'value_by_stage': values,
      'count_by_stage': counts,
      'won_month_count': wonMonthCount,
      'won_month_value': wonMonthValue,
      'lost_month_count': lostMonthCount,
    };
  }

  DemoResponse createOpportunity(DemoRequest req) {
    final body = req.json;
    final title = '${body['title'] ?? ''}'.trim();
    if (title.isEmpty) return _invalid('title', 'Vui lòng nhập tên cơ hội.');
    final stage = (body['opportunity_stage'] as String?) ?? 'new';
    if (_stage(stage) == null) {
      return _invalid('opportunity_stage', 'Giai đoạn không thuộc quy trình.');
    }
    final customerId = body['customer_id'] as String?;
    if (customerId != null && !customers.containsKey(customerId)) {
      return _invalid('customer_id', 'Khách hàng không tồn tại.');
    }
    final id = demoNewId();
    final now = demoAgo();
    _opportunitySeq++;
    final o = <String, dynamic>{
      'id': id,
      'opportunity_code': 'CH-${_opportunitySeq.toString().padLeft(4, '0')}',
      'customer_id': customerId,
      'customer_name': customers[customerId]?['display_name'],
      'owner_user_id': body['owner_user_id'] ?? demoMeId,
      'title': title,
      'campaign_objective': body['campaign_objective'],
      'estimated_budget': (body['estimated_budget'] as num?)?.toDouble(),
      'expected_start_date': null,
      'expected_end_date': body['expected_end_date'],
      'target_area_id': null,
      'opportunity_stage': 'new',
      'opportunity_status': 'OPEN',
      'pipeline': (body['pipeline'] as String?) ?? _pipelineCode,
      'metadata': _mergeMeta(const {}, body['metadata']),
      'won_at': null,
      'lost_at': null,
      'order_id': null,
      'created_at': now,
      'updated_at': now,
    };
    opportunities[id] = o;
    if (customerId != null) {
      _addLog(
        customerId: customerId,
        type: 'NOTE',
        content: 'Tạo cơ hội “$title”.',
        at: now,
        opportunityId: id,
        auto: true,
      );
    }
    if (stage != 'new') _setStage(o, stage);
    return created(opportunityJson(o));
  }

  DemoResponse updateOpportunity(DemoRequest req) {
    final o = opportunities[req.params['id']];
    if (o == null) return notFound('Không tìm thấy cơ hội.');
    final body = req.json;
    if (body.containsKey('title') && '${body['title'] ?? ''}'.trim().isEmpty) {
      return _invalid('title', 'Vui lòng nhập tên cơ hội.');
    }
    final stage = body['opportunity_stage'] as String?;
    if (stage != null && _stage(stage) == null) {
      return _invalid('opportunity_stage', 'Giai đoạn không thuộc quy trình.');
    }
    final customerId = body['customer_id'] as String?;
    if (customerId != null && !customers.containsKey(customerId)) {
      return _invalid('customer_id', 'Khách hàng không tồn tại.');
    }
    for (final key in const [
      'title',
      'customer_id',
      'owner_user_id',
      'expected_end_date',
      'campaign_objective',
      'pipeline',
    ]) {
      if (body.containsKey(key)) o[key] = body[key];
    }
    if (body.containsKey('estimated_budget')) {
      o['estimated_budget'] = (body['estimated_budget'] as num?)?.toDouble();
    }
    if (customerId != null) {
      o['customer_name'] = customers[customerId]?['display_name'];
    }
    if (body['metadata'] is Map) {
      o['metadata'] = _mergeMeta(o['metadata'] as Map, body['metadata']);
    }
    o['updated_at'] = demoAgo();
    if (stage != null && stage != o['opportunity_stage']) _setStage(o, stage);
    return ok(opportunityJson(o));
  }

  DemoResponse moveStage(DemoRequest req) {
    final o = opportunities[req.params['id']];
    if (o == null) return notFound('Không tìm thấy cơ hội.');
    final stage = req.json['opportunity_stage'] as String?;
    if (stage == null || _stage(stage) == null) {
      return _invalid('opportunity_stage', 'Giai đoạn không thuộc quy trình.');
    }
    if (stage != o['opportunity_stage']) _setStage(o, stage);
    return ok(opportunityJson(o));
  }

  DemoResponse markWon(DemoRequest req) {
    final o = opportunities[req.params['id']];
    if (o == null) return notFound('Không tìm thấy cơ hội.');
    final existing = o['order_id'] as String?;
    if (o['opportunity_stage'] != 'won') _setStage(o, 'won');
    final orderId = existing ?? demoNewId();
    o['order_id'] = orderId;
    return ok({
      'opportunity': opportunityJson(o),
      'order_id': orderId,
      'order_created': existing == null,
      'overrides_ignored': const <String>[],
    });
  }

  /// Đổi giai đoạn như máy chủ: tính lại trạng thái, mốc thắng/thua, ghi vào
  /// nhật ký của khách; chốt thắng thì cộng vào đơn của khách và doanh thu hôm
  /// nay để thẻ Tổng quan nhích lên.
  void _setStage(Map<String, dynamic> o, String stage) {
    final now = demoAgo();
    final wasWon = o['opportunity_status'] == 'WON';
    o['opportunity_stage'] = stage;
    final status = _statusOf(stage);
    o['opportunity_status'] = status;
    o['won_at'] = status == 'WON' ? (o['won_at'] ?? now) : null;
    o['lost_at'] = status == 'LOST' ? (o['lost_at'] ?? now) : null;
    o['updated_at'] = now;

    final customerId = o['customer_id'] as String?;
    final label = _stage(stage)?['label'] ?? stage;
    if (customerId != null) {
      _addLog(
        customerId: customerId,
        type: 'NOTE',
        content: 'Chuyển cơ hội “${o['title']}” sang giai đoạn $label.',
        at: now,
        opportunityId: o['id'] as String,
        auto: true,
      );
    }
    if (status == 'WON' && !wasWon) {
      final budget = (o['estimated_budget'] as num?)?.toDouble() ?? 0;
      final key = _dayKey(_vnNow());
      _extraRevenue[key] = (_extraRevenue[key] ?? 0) + budget;
      final c = customers[customerId];
      if (c != null) {
        c['orders_total'] = ((c['orders_total'] as num?) ?? 0) + budget;
        c['orders_count'] = ((c['orders_count'] as num?) ?? 0) + 1;
        c['last_order_at'] = now;
      }
    }
  }

  // ---- Doanh thu --------------------------------------------------------------

  DemoResponse revenueSeries(DemoRequest req) {
    final range = req.q('range') ?? 'month';
    final nowMs =
        int.tryParse(req.q('now') ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    final w = _windowOf(req, range, nowMs);

    if (range == 'year') {
      final year = _vnDate(w.from).year;
      final prevYear = _vnDate(w.prevFrom).year;
      final today = _vnDate(nowMs);
      final months = today.year == year ? today.month : 12;
      return ok({
        'bucket': 'month',
        'current': [
          for (var m = 1; m <= months; m++) _monthRevenue(year, m, today),
        ],
        'previous': [
          for (var m = 1; m <= 12; m++) _monthRevenue(prevYear, m, null),
        ],
        'target': 15e9,
        'currency': 'VND',
      });
    }

    final slots = ((w.to - w.from) / _dayMs).round();
    final elapsed = ((nowMs - w.from) ~/ _dayMs) + 1;
    final current = elapsed.clamp(1, slots);
    final prevSlots = ((w.prevTo - w.prevFrom) / _dayMs).round();
    return ok({
      'bucket': 'day',
      'current': [
        for (var i = 0; i < current; i++)
          _dayRevenue(
            _vnDate(w.from + i * _dayMs),
            // Hôm nay mới qua một phần ngày.
            partial: i == elapsed - 1
                ? ((nowMs - (w.from + i * _dayMs)) / _dayMs).clamp(0.3, 1.0)
                : 1.0,
          ),
      ],
      'previous': [
        for (var i = 0; i < prevSlots; i++)
          _dayRevenue(_vnDate(w.prevFrom + i * _dayMs)),
      ],
      'target': range == 'week' ? 3e8 : 1.3e9,
      'currency': 'VND',
    });
  }

  /// Doanh thu một ngày (giờ VN): số giả nhưng cố định theo ngày — mở lại app
  /// vẫn ra cùng biểu đồ. Cuối tuần cửa hàng đông hơn.
  double _dayRevenue(DateTime vnDay, {double partial = 1.0}) {
    final seed = vnDay.year * 400 + vnDay.month * 32 + vnDay.day;
    final noise = ((seed * 7919) % 997) / 997.0;
    final weekend =
        DateTime.utc(vnDay.year, vnDay.month, vnDay.day).weekday >= 6;
    final base = weekend ? 52e6 : 26e6;
    final spread = weekend ? 34e6 : 22e6;
    final value = ((base + noise * spread) * partial / 1e5).round() * 1e5;
    return value + (_extraRevenue[_dayKey(vnDay)] ?? 0);
  }

  /// Tổng tháng [month]; [today] khác null = chỉ cộng tới hôm nay.
  double _monthRevenue(int year, int month, DateTime? today) {
    final days = DateTime.utc(year, month + 1, 0).day;
    final thisMonth =
        today != null && today.year == year && today.month == month;
    final last = thisMonth ? today.day : days;
    var sum = 0.0;
    for (var d = 1; d <= last; d++) {
      sum += _dayRevenue(DateTime.utc(year, month, d));
    }
    return sum;
  }

  // ---- Dữ liệu mẫu ------------------------------------------------------------

  void seed() {
    final people = demoPeople;
    final me = people[0].id;
    final minhAnh = people[1].id;
    final bao = people[2].id;
    final thuHa = people[3].id;

    String cust({
      required int n,
      required String name,
      String? legalName,
      String? contact,
      required String phone,
      String? email,
      String? address,
      String? status,
      String? owner,
      required String source,
      List<String> tags = const [],
      String? notes,
      bool business = false,
      String? taxCode,
      double ordersTotal = 0,
      int ordersCount = 0,
      required int createdDays,
      int updatedDays = 0,
      int updatedHours = 0,
    }) {
      final id =
          '01900000-0000-7000-8000-0000000c${n.toString().padLeft(4, '0')}';
      _customerSeq = n;
      customers[id] = {
        'id': id,
        'customer_code': 'KH-${n.toString().padLeft(4, '0')}',
        'legal_name': legalName ?? name,
        'display_name': name,
        'customer_type': 'DIRECT_CLIENT',
        'industry_category': null,
        'tax_code': taxCode,
        'primary_contact_name': contact ?? name,
        'primary_contact_phone': phone,
        'primary_contact_email': email,
        'address': address,
        'assigned_sales_rep_id': owner,
        'customer_status': status,
        'metadata': {
          'source': source,
          'party_type': business ? 'business' : 'individual',
          'tags': tags,
          'notes': ?notes,
          'note': ?notes,
        },
        'orders_total': ordersTotal,
        'orders_count': ordersCount,
        'last_order_at': ordersCount > 0
            ? demoAgo(days: updatedDays + 3)
            : null,
        'created_at': demoAgo(days: createdDays, hours: 2),
        'updated_at': demoAgo(days: updatedDays, hours: updatedHours),
      };
      return id;
    }

    final lan = cust(
      n: 1,
      name: 'Nguyễn Thị Lan',
      phone: '0900100001',
      email: 'lan.nguyen@example.com',
      address: '18 Đường số 5, Phường Bình An, TP Thủ Đức, TP Hồ Chí Minh',
      status: 'ACTIVE',
      owner: bao,
      source: 'zalo',
      tags: ['Đặt lịch'],
      notes: 'Thích màu trắng, cần giao hàng buổi tối sau 18h.',
      ordersTotal: 23400000,
      ordersCount: 2,
      createdDays: 120,
      updatedHours: 3,
    );
    final hung = cust(
      n: 2,
      name: 'Trần Văn Hùng',
      phone: '0900100002',
      email: 'hung.tran@example.com',
      address: '45 Lê Văn Lương, Phường Tân Hưng, Quận 7, TP Hồ Chí Minh',
      status: 'WARM',
      owner: minhAnh,
      source: 'facebook',
      notes: 'Khách quen, hay mua đồ cho cả nhà người thân.',
      ordersTotal: 186000000,
      ordersCount: 5,
      createdDays: 400,
      updatedDays: 1,
    );
    final phoNui = cust(
      n: 3,
      name: 'Khách sạn Phố Núi',
      legalName: 'Công ty TNHH Khách sạn Phố Núi',
      contact: 'Hồ Thanh Vân',
      phone: '0900100003',
      email: 'muahang@phonui.example.com',
      address: '7 Đường Hoa Đào, Phường 3, TP Đà Lạt, Lâm Đồng',
      status: 'WARM',
      owner: minhAnh,
      source: 'web',
      tags: ['Hợp đồng', 'Báo giá'],
      business: true,
      taxCode: '5800000001',
      notes: 'Đang cải tạo 20 phòng, giao theo từng tầng.',
      ordersTotal: 640000000,
      ordersCount: 3,
      createdDays: 300,
      updatedDays: 2,
    );
    final lamVien = cust(
      n: 4,
      name: 'Văn phòng Kiến trúc Lam Viên',
      legalName: 'Công ty CP Kiến trúc Lam Viên',
      contact: 'Mai Xuân Đạt',
      phone: '0900100004',
      email: 'lienhe@lamvien.example.com',
      address: '102 Nguyễn Văn Trỗi, Phường 8, Quận Phú Nhuận, TP Hồ Chí Minh',
      status: 'ACTIVE',
      owner: me,
      source: 'web',
      tags: ['Báo giá'],
      business: true,
      taxCode: '0300000004',
      ordersTotal: 48000000,
      ordersCount: 1,
      createdDays: 90,
      updatedHours: 6,
    );
    final nam = cust(
      n: 5,
      name: 'Lê Hoàng Nam',
      phone: '0900100005',
      address: '23 Trần Phú, Phường Lộc Thọ, TP Nha Trang, Khánh Hoà',
      status: 'ACTIVE',
      owner: bao,
      source: 'zalo',
      ordersTotal: 9800000,
      ordersCount: 1,
      createdDays: 60,
      updatedDays: 3,
    );
    final chi = cust(
      n: 6,
      name: 'Phạm Mai Chi',
      phone: '0900100006',
      email: 'maichi.pham@example.com',
      address: '9 Ngõ 12 Phố Mẫu Sơn, Phường Dịch Vọng, Cầu Giấy, Hà Nội',
      status: 'ACTIVE',
      owner: thuHa,
      source: 'facebook',
      ordersTotal: 35000000,
      ordersCount: 2,
      createdDays: 45,
      updatedDays: 3,
    );
    final tung = cust(
      n: 7,
      name: 'Võ Thanh Tùng',
      phone: '0900100007',
      address: '56 Nguyễn Huệ, Phường Vĩnh Ninh, TP Huế',
      status: 'AT_RISK',
      owner: bao,
      source: 'zalo_personal',
      tags: ['Khiếu nại'],
      notes:
          'Phàn nàn giao trễ lần trước — cần gọi xin lỗi và tặng phiếu bảo trì.',
      ordersTotal: 6500000,
      ordersCount: 1,
      createdDays: 200,
      updatedDays: 8,
    );
    final han = cust(
      n: 8,
      name: 'Đặng Ngọc Hân',
      phone: '0900100008',
      email: 'ngochan.dang@example.com',
      address: '31 Đường số 9, Phường An Khánh, TP Thủ Đức, TP Hồ Chí Minh',
      owner: thuHa,
      source: 'tiktok',
      createdDays: 2,
      updatedDays: 2,
    );
    final gioBien = cust(
      n: 9,
      name: 'Nhà hàng Gió Biển',
      legalName: 'Công ty TNHH Ẩm thực Gió Biển',
      contact: 'Lương Văn Phúc',
      phone: '0900100009',
      email: 'quanly@giobien.example.com',
      address: '88 Võ Nguyên Giáp, Phường Phước Mỹ, Quận Sơn Trà, Đà Nẵng',
      status: 'ACTIVE',
      owner: me,
      source: 'facebook',
      tags: ['Báo giá'],
      business: true,
      taxCode: '0400000009',
      createdDays: 20,
      updatedDays: 1,
    );
    final huy = cust(
      n: 10,
      name: 'Bùi Quang Huy',
      phone: '0900100010',
      address: '14 Hai Bà Trưng, Phường Tân Định, Quận 1, TP Hồ Chí Minh',
      owner: thuHa,
      source: 'web',
      createdDays: 1,
      updatedHours: 20,
    );
    final chau = cust(
      n: 11,
      name: 'Hoàng Minh Châu',
      phone: '0900100011',
      email: 'minhchau.hoang@example.com',
      address: 'Căn hộ B-1205, Khu đô thị Mẫu, Quận Hoàng Mai, Hà Nội',
      status: 'WARM',
      owner: minhAnh,
      source: 'zalo',
      notes: 'Vừa nhận nhà mới, quan tâm trọn gói nội thất.',
      ordersTotal: 212000000,
      ordersCount: 4,
      createdDays: 500,
      updatedDays: 12,
    );
    final thinh = cust(
      n: 12,
      name: 'Ngô Đức Thịnh',
      phone: '0900100012',
      address: '5 Lý Thường Kiệt, Phường 4, TP Vũng Tàu',
      status: 'LOST',
      owner: bao,
      source: 'facebook',
      createdDays: 150,
      updatedDays: 20,
    );
    cust(
      n: 13,
      name: 'Đỗ Thu Trang',
      phone: '0900100013',
      email: 'thutrang.do@example.com',
      address: '77 Phan Đình Phùng, Phường 2, TP Tân An, Long An',
      status: 'INACTIVE',
      owner: thuHa,
      source: 'zalo',
      ordersTotal: 4200000,
      ordersCount: 1,
      createdDays: 380,
      updatedDays: 60,
    );
    final giaBao = cust(
      n: 14,
      name: 'Trịnh Gia Bảo',
      phone: '0900100014',
      address: '40 Đường 30/4, Phường Xuân Khánh, Ninh Kiều, Cần Thơ',
      status: 'ACTIVE',
      owner: me,
      source: 'instagram',
      tags: ['Đặt lịch'],
      ordersTotal: 15000000,
      ordersCount: 1,
      createdDays: 30,
      updatedDays: 4,
    );
    final ngan = cust(
      n: 15,
      name: 'Lý Kim Ngân',
      phone: '0900100015',
      address: '3 Đường Hoa Sữa, Phường 7, Quận Gò Vấp, TP Hồ Chí Minh',
      source: 'zalo',
      createdDays: 0,
      updatedHours: 3,
    );

    // ---- Cơ hội -----------------------------------------------------------
    var oppN = 0;
    String opp({
      required String title,
      required String? customer,
      required String owner,
      required String stage,
      required double budget,
      required String product,
      required String channel,
      int? closeInDays,
      int createdDays = 10,
      int updatedDays = 0,
      int updatedHours = 2,
      int? closedDaysAgo,
      Object? notes,
      String? lostReason,
      List<String> tags = const [],
    }) {
      oppN++;
      final id =
          '01900000-0000-7000-8000-0000000b${oppN.toString().padLeft(4, '0')}';
      final status = _statusOf(stage);
      final closedAt = closedDaysAgo == null
          ? null
          : demoAgo(days: closedDaysAgo);
      opportunities[id] = {
        'id': id,
        'opportunity_code': 'CH-${oppN.toString().padLeft(4, '0')}',
        'customer_id': customer,
        'customer_name': customers[customer]?['display_name'],
        'owner_user_id': owner,
        'title': title,
        'campaign_objective': null,
        'estimated_budget': budget,
        'expected_start_date': null,
        'expected_end_date': closeInDays == null
            ? null
            : _isoDay(DateTime.now().add(Duration(days: closeInDays))),
        'target_area_id': null,
        'opportunity_stage': stage,
        'opportunity_status': status,
        'pipeline': _pipelineCode,
        'metadata': {
          'product': product,
          'channel': channel,
          'tags': tags,
          'notes': ?notes,
          'lost_reason': ?lostReason,
        },
        'won_at': status == 'WON' ? closedAt : null,
        'lost_at': status == 'LOST' ? closedAt : null,
        'order_id': status == 'WON' ? demoNewId() : null,
        'created_at': demoAgo(days: createdDays),
        'updated_at': demoAgo(days: updatedDays, hours: updatedHours),
      };
      _opportunitySeq = oppN;
      return id;
    }

    opp(
      title: 'Combo bếp từ và máy hút mùi',
      customer: lan,
      owner: bao,
      stage: 'new',
      budget: 18500000,
      product: 'Bếp từ đôi + máy hút mùi kính cong',
      channel: 'zalo',
      closeInDays: 10,
      createdDays: 2,
      updatedHours: 4,
    );
    opp(
      title: 'Sofa da phòng khách chữ L',
      customer: hung,
      owner: minhAnh,
      stage: 'consulted',
      budget: 32000000,
      product: 'Sofa da bò chữ L 2m8',
      channel: 'facebook',
      closeInDays: 7,
      createdDays: 9,
      updatedDays: 1,
      notes: 'Khách muốn xem mẫu da màu nâu bò tại cửa hàng cuối tuần.',
    );
    final phoNuiOpp = opp(
      title: 'Nội thất 20 phòng khách sạn',
      customer: phoNui,
      owner: minhAnh,
      stage: 'quoted',
      budget: 480000000,
      product: 'Giường, tủ đầu giường, bàn làm việc cho 20 phòng',
      channel: 'web',
      closeInDays: 25,
      createdDays: 21,
      updatedDays: 2,
      tags: ['Dự án'],
      notes: [
        {
          'content': 'Đã gửi báo giá lần 2, giảm 5% cho đơn trên 15 phòng.',
          'author': people[1].name,
          'at': demoAgo(days: 2),
        },
        {
          'content': 'Chủ đầu tư muốn xem phòng mẫu trước khi ký.',
          'author': people[1].name,
          'at': demoAgo(days: 6),
        },
      ],
    );
    final lamVienOpp = opp(
      title: 'Điều hoà cho văn phòng (12 bộ)',
      customer: lamVien,
      owner: me,
      stage: 'negotiating',
      budget: 156000000,
      product: 'Điều hoà inverter 1,5 HP × 12, kèm lắp đặt',
      channel: 'web',
      closeInDays: 5,
      createdDays: 18,
      updatedHours: 6,
      notes: 'Đang thương lượng thời gian bảo hành 3 năm.',
    );
    opp(
      title: 'Tủ lạnh side-by-side',
      customer: nam,
      owner: bao,
      stage: 'quoted',
      budget: 27900000,
      product: 'Tủ lạnh side-by-side 600 lít',
      channel: 'zalo',
      closeInDays: -2,
      createdDays: 12,
      updatedDays: 3,
    );
    opp(
      title: 'Máy giặt sấy cửa trước',
      customer: chi,
      owner: thuHa,
      stage: 'won',
      budget: 21000000,
      product: 'Máy giặt sấy 10 kg',
      channel: 'facebook',
      closeInDays: -3,
      createdDays: 15,
      updatedDays: 3,
      closedDaysAgo: 3,
    );
    opp(
      title: 'Bàn ăn gỗ sồi 6 ghế',
      customer: tung,
      owner: bao,
      stage: 'lost',
      budget: 15500000,
      product: 'Bộ bàn ăn gỗ sồi 1m6, 6 ghế',
      channel: 'zalo_personal',
      closeInDays: -9,
      createdDays: 30,
      updatedDays: 9,
      closedDaysAgo: 9,
      lostReason: 'Khách chọn mua nơi khác vì giá thấp hơn.',
    );
    opp(
      title: 'Giường ngủ kèm nệm',
      customer: han,
      owner: thuHa,
      stage: 'new',
      budget: 12000000,
      product: 'Giường gỗ 1m6 + nệm lò xo túi',
      channel: 'tiktok',
      closeInDays: 14,
      createdDays: 2,
      updatedDays: 2,
    );
    opp(
      title: 'Thiết bị bếp nhà hàng',
      customer: gioBien,
      owner: me,
      stage: 'consulted',
      budget: 210000000,
      product: 'Bếp công nghiệp, tủ mát inox, máy rửa bát',
      channel: 'facebook',
      closeInDays: 30,
      createdDays: 14,
      updatedDays: 1,
      tags: ['Dự án'],
    );
    final huyOpp = opp(
      title: 'Máy lọc không khí (3 chiếc)',
      customer: huy,
      owner: thuHa,
      stage: 'negotiating',
      budget: 24000000,
      product: 'Máy lọc không khí HEPA × 3',
      channel: 'web',
      closeInDays: 3,
      createdDays: 1,
      updatedHours: 18,
    );
    opp(
      title: 'Trọn bộ nội thất căn hộ',
      customer: chau,
      owner: minhAnh,
      stage: 'won',
      budget: 125000000,
      product: 'Phòng khách, phòng ngủ, bếp — căn 2 phòng ngủ',
      channel: 'zalo',
      closeInDays: -12,
      createdDays: 40,
      updatedDays: 12,
      closedDaysAgo: 12,
    );
    opp(
      title: 'Tivi 75 inch và dàn loa',
      customer: thinh,
      owner: bao,
      stage: 'lost',
      budget: 38000000,
      product: 'Tivi 75 inch + loa thanh 5.1',
      channel: 'facebook',
      closeInDays: -20,
      createdDays: 35,
      updatedDays: 20,
      closedDaysAgo: 20,
      lostReason: 'Khách hoãn mua sang năm sau.',
    );
    opp(
      title: 'Kệ tivi và tủ giày',
      customer: giaBao,
      owner: me,
      stage: 'new',
      budget: 9500000,
      product: 'Kệ tivi gỗ óc chó + tủ giày 3 tầng',
      channel: 'instagram',
      closeInDays: 12,
      createdDays: 4,
      updatedDays: 4,
    );

    // ---- Nhật ký ----------------------------------------------------------
    void log(
      String customer,
      String type,
      String content, {
      int days = 0,
      int hours = 0,
      String? by,
      String? opportunity,
    }) => _addLog(
      customerId: customer,
      type: type,
      content: content,
      at: demoAgo(days: days, hours: hours),
      byUserId: by,
      opportunityId: opportunity,
    );

    log(
      lan,
      'MESSAGE',
      'Khách hỏi giá bếp từ đôi qua Zalo OA.',
      hours: 3,
      by: bao,
    );
    log(
      lan,
      'CALL',
      'Gọi tư vấn kích thước mặt đá, hẹn đo tại nhà.',
      days: 1,
      by: bao,
    );
    log(
      lan,
      'NOTE',
      'Đơn máy xay sinh tố đã giao đủ, khách hài lòng.',
      days: 40,
      by: people[3].id,
    );

    log(
      hung,
      'MEETING',
      'Khách ghé cửa hàng xem sofa, thích mẫu chữ L.',
      days: 1,
      by: minhAnh,
    );
    log(
      hung,
      'CALL',
      'Hỏi thăm sau khi lắp tủ lạnh tháng trước.',
      days: 25,
      by: people[3].id,
    );

    log(
      phoNui,
      'QUOTATION',
      'Gửi báo giá lần 2 — 480 triệu cho 20 phòng.',
      days: 2,
      by: minhAnh,
      opportunity: phoNuiOpp,
    );
    log(
      phoNui,
      'MEETING',
      'Khảo sát hiện trạng 2 tầng đầu cùng chị Vân.',
      days: 9,
      by: minhAnh,
      opportunity: phoNuiOpp,
    );
    log(
      phoNui,
      'EMAIL',
      'Gửi catalogue giường khách sạn và bảng vật liệu.',
      days: 15,
      by: minhAnh,
    );

    log(
      lamVien,
      'CALL',
      'Anh Đạt xác nhận cần lắp xong trước ngày 15.',
      hours: 6,
      by: me,
      opportunity: lamVienOpp,
    );
    log(
      lamVien,
      'QUOTATION',
      'Báo giá 12 bộ điều hoà kèm vật tư lắp đặt.',
      days: 6,
      by: me,
      opportunity: lamVienOpp,
    );
    log(
      lamVien,
      'FOLLOW_UP',
      'Nhắc gửi bản vẽ mặt bằng để tính đường ống.',
      days: 10,
      by: me,
    );

    log(
      nam,
      'MESSAGE',
      'Khách hỏi còn hàng tủ lạnh màu đen không.',
      days: 3,
      by: bao,
    );
    log(
      nam,
      'QUOTATION',
      'Báo giá tủ lạnh side-by-side kèm khuyến mãi.',
      days: 8,
      by: bao,
    );

    log(
      chi,
      'NOTE',
      'Đã giao và lắp máy giặt sấy, hướng dẫn sử dụng.',
      days: 3,
      by: people[4].id,
    );
    log(
      chi,
      'CALL',
      'Xác nhận lịch giao hàng sáng thứ Bảy.',
      days: 5,
      by: thuHa,
    );

    log(
      tung,
      'CALL',
      'Khách phàn nàn giao trễ 2 ngày, đã xin lỗi.',
      days: 8,
      by: bao,
    );
    log(
      tung,
      'NOTE',
      'Đề xuất tặng phiếu vệ sinh máy lạnh miễn phí.',
      days: 8,
      by: minhAnh,
    );

    log(
      han,
      'MESSAGE',
      'Khách để lại bình luận trên video TikTok hỏi giá giường.',
      days: 2,
      by: thuHa,
    );

    log(
      gioBien,
      'MEETING',
      'Gặp anh Phúc tại nhà hàng, đo khu bếp 40 m².',
      days: 1,
      by: me,
    );
    log(
      gioBien,
      'MESSAGE',
      'Nhận danh sách thiết bị cần thay qua Messenger.',
      days: 6,
      by: me,
    );

    log(
      huy,
      'CALL',
      'Tư vấn công suất lọc cho phòng 30 m².',
      hours: 18,
      by: thuHa,
      opportunity: huyOpp,
    );

    log(
      chau,
      'NOTE',
      'Bàn giao trọn bộ nội thất, khách gửi lời cảm ơn.',
      days: 12,
      by: minhAnh,
    );
    log(
      chau,
      'MEETING',
      'Duyệt phối cảnh 3D phòng khách tại căn hộ.',
      days: 30,
      by: minhAnh,
    );

    log(
      thinh,
      'CALL',
      'Khách báo hoãn mua tivi sang năm sau.',
      days: 20,
      by: bao,
    );

    log(
      giaBao,
      'MESSAGE',
      'Khách gửi ảnh phòng khách qua Instagram nhờ tư vấn kệ.',
      days: 4,
      by: me,
    );
    log(ngan, 'MESSAGE', 'Khách nhắn hỏi chương trình trả góp 0%.', hours: 3);
  }
}

// ===========================================================================
// Tiện ích
// ===========================================================================

const _dayMs = 86400000;
const _vnOffset = Duration(hours: 7);

/// Ngày giờ VN (các trường năm/tháng/ngày là giờ VN) của mốc [ms].
DateTime _vnDate(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(_vnOffset);

DateTime _vnNow() => DateTime.now().toUtc().add(_vnOffset);

String _dayKey(DateTime vnDay) => '${vnDay.year}-${vnDay.month}-${vnDay.day}';

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Đầu tháng này theo giờ VN, dạng ISO UTC — để so chuỗi với `created_at`.
String _vnMonthStartIso() {
  final vn = _vnNow();
  return DateTime.utc(vn.year, vn.month).subtract(_vnOffset).toIso8601String();
}

typedef _Window = ({int from, int to, int prevFrom, int prevTo});

/// Mốc kỳ app gửi; thiếu thì tự tính như `revenueWindow` của app.
_Window _windowOf(DemoRequest req, String range, int nowMs) {
  final from = int.tryParse(req.q('from') ?? '');
  final to = int.tryParse(req.q('to') ?? '');
  final prevFrom = int.tryParse(req.q('prev_from') ?? '');
  final prevTo = int.tryParse(req.q('prev_to') ?? '');
  if (from != null && to != null && prevFrom != null && prevTo != null) {
    return (from: from, to: to, prevFrom: prevFrom, prevTo: prevTo);
  }
  int mid(int y, int m, int d) =>
      DateTime.utc(y, m, d).subtract(_vnOffset).millisecondsSinceEpoch;
  final vn = _vnDate(nowMs);
  switch (range) {
    case 'week':
      final d = vn.day - (vn.weekday - DateTime.monday);
      return (
        from: mid(vn.year, vn.month, d),
        to: mid(vn.year, vn.month, d + 7),
        prevFrom: mid(vn.year, vn.month, d - 7),
        prevTo: mid(vn.year, vn.month, d),
      );
    case 'year':
      return (
        from: mid(vn.year, 1, 1),
        to: mid(vn.year + 1, 1, 1),
        prevFrom: mid(vn.year - 1, 1, 1),
        prevTo: mid(vn.year, 1, 1),
      );
    default:
      return (
        from: mid(vn.year, vn.month, 1),
        to: mid(vn.year, vn.month + 1, 1),
        prevFrom: mid(vn.year, vn.month - 1, 1),
        prevTo: mid(vn.year, vn.month, 1),
      );
  }
}

/// 422 kèm lỗi theo trường, như `FormRequest` của API.
DemoResponse _invalid(String field, String message) => DemoResponse(422, {
  'success': false,
  'message': message,
  'errors': {
    field: [message],
  },
});

/// Gộp NÔNG như `MetadataPatch::merge`: khoá gửi lên ghi đè, khoá gửi null bị
/// xoá, khoá không gửi giữ nguyên.
Map<String, dynamic> _mergeMeta(Map<dynamic, dynamic> stored, Object? patch) {
  final merged = Map<String, dynamic>.from(stored);
  if (patch is Map) {
    patch.forEach((key, value) {
      if (value == null) {
        merged.remove('$key');
      } else {
        merged['$key'] = value;
      }
    });
  }
  return merged;
}

Object? _blankToNull(Object? value) =>
    value is String && value.trim().isEmpty ? null : value;

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

const _accents = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Chữ thường, bỏ dấu tiếng Việt — gõ "hung" vẫn ra "Hùng".
String _fold(String s) {
  final lower = s.toLowerCase().trim();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    var plain = ch;
    for (final entry in _accents.entries) {
      if (entry.value.contains(ch)) {
        plain = entry.key;
        break;
      }
    }
    out.write(plain);
  }
  return out.toString();
}
