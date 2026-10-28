import '../../core/utils/formatters.dart';
import '../../core/utils/text_search.dart';
import '../demo_backend.dart';
import '../demo_seed.dart';

/// Dữ liệu mẫu: công việc, dự án (kế hoạch), đội nhóm, thành viên, nhãn việc.
///
/// Mọi lượt ghi chỉ sống trong RAM của phiên: tạo/sửa việc, đổi trạng thái,
/// kéo cột, tick việc con, bình luận, tạo kế hoạch/team, yêu thích… đều hiện
/// ngay ở lượt đọc sau, và mất khi tắt app. Tên người, khách, sản phẩm đều BỊA.
///
/// Không có URL ảnh nào: tệp đính kèm chỉ mang tên (`type: file`, `url` rỗng),
/// ảnh nền kế hoạch là token gradient — không lượt nào chạm máy chủ thật.
void registerWorkDemo(DemoRoutes r) => _WorkDemo().register(r);

// ── Người trong dữ liệu mẫu ────────────────────────────────────────────────

final _me = demoPeople[0].id;
final _anh = demoPeople[1].id;
final _bao = demoPeople[2].id;
final _ha = demoPeople[3].id;
final _long = demoPeople[4].id;

// ── Id cố định của dữ liệu gốc (dạng uuid) ─────────────────────────────────

const _teamSales = '01900000-0000-7000-8000-00000000c001';
const _teamTech = '01900000-0000-7000-8000-00000000c002';

const _pDelivery = '01900000-0000-7000-8000-00000000b001';
const _pWarranty = '01900000-0000-7000-8000-00000000b002';
const _pTet = '01900000-0000-7000-8000-00000000b003';
const _pStore = '01900000-0000-7000-8000-00000000b004';

String _taskId(int n) =>
    '01900000-0000-7000-8000-00000000e${n.toString().padLeft(3, '0')}';

// ── Tiện ích nhỏ ───────────────────────────────────────────────────────────

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Ngày lịch VN cách hôm nay [offset] ngày, dạng `YYYY-MM-DD` như API.
String _day(int offset) => _ymd(VnTime.today().add(Duration(days: offset)));

String _now() => DateTime.now().toUtc().toIso8601String();

String _hoursAgo(num hours) => DateTime.now()
    .toUtc()
    .subtract(Duration(minutes: (hours * 60).round()))
    .toIso8601String();

String? _s(Object? v) {
  if (v == null) return null;
  final text = '$v'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

/// Mảng chuỗi (bỏ phần tử rỗng). Một chuỗi đơn — trường multipart chỉ có một
/// giá trị — thành mảng một phần tử.
List<String> _strs(Object? v) => switch (v) {
  final List list => [for (final x in list) ?_s(x)],
  _ => [?_s(v)],
};

/// Tham số query dạng `a,b,c` (`ids=`, `types=`).
List<String> _csv(Object? v) => [
  for (final part in _strs(v).expand((s) => s.split(',')))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Id người (user id). Nhận cả membership id cho chắc.
String? _userId(Object? raw) {
  final id = _s(raw);
  if (id == null) return null;
  return demoPersonById(id)?.id;
}

String? _nameOf(Object? id) => demoPersonById(_s(id))?.name;

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final x in v)
          if (x is Map) Map<String, dynamic>.from(x),
      ]
    : <Map<String, dynamic>>[];

bool _bool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

/// Mức ưu tiên API nhận. Giá trị lạ giữ `med` như server.
String _priority(Object? v) => switch (_s(v)) {
  'low' => 'low',
  'high' => 'high',
  _ => 'med',
};

DemoResponse _locked() => const DemoResponse(423, {
  'success': false,
  'code': 'task_locked',
  'message': 'Việc đã khoá. Mở khoá trước khi sửa.',
});

DemoResponse _invalid(String field, String message) => DemoResponse(422, {
  'success': false,
  'message': message,
  'errors': {
    field: [message],
  },
});

/// Một việc con trong dữ liệu gốc: tên, đã xong, người làm.
typedef _Step = (String title, bool done, String? assignee);

class _WorkDemo {
  _WorkDemo() {
    _seedLabels();
    _seedTeams();
    _seedProjects();
    _seedTasks();
  }

  final _labels = <Map<String, dynamic>>[];
  final _teams = <Map<String, dynamic>>[];
  final _projects = <Map<String, dynamic>>[];
  final _tasks = <Map<String, dynamic>>[];

  /// Lời nhắc theo id việc.
  final _reminders = <String, List<Map<String, dynamic>>>{};

  /// Kế hoạch người dùng demo đã đánh dấu yêu thích.
  final _favorites = <String>{_pDelivery};

  /// `zalo_user_id` theo membership id.
  final _zalo = <String, String>{};

  int _coverTurn = 0;

  // ── Dữ liệu gốc ──────────────────────────────────────────────────────────

  void _seedLabels() {
    const rows = [
      ('giao_gap', 'Giao gấp', '#DC2626'),
      ('khach_vip', 'Khách VIP', '#E8890C'),
      ('lap_dat', 'Lắp đặt', '#0A7D76'),
      ('bao_hanh', 'Bảo hành', '#2563EB'),
      ('cho_hang', 'Chờ hàng', '#56637A'),
    ];
    for (var i = 0; i < rows.length; i++) {
      final (code, label, color) = rows[i];
      _labels.add({
        'id': '01900000-0000-7000-8000-00000000f00${i + 1}',
        'tenant_id': demoTenantId,
        'group_key': 'TASK_LABEL',
        'code': code,
        'label': label,
        'color': color,
        'icon': null,
        'sort_order': i + 1,
        'is_default': false,
        'is_system': false,
        'is_active': true,
        'created_at': demoAgo(days: 60),
        'updated_at': demoAgo(days: 60),
      });
    }
  }

  void _seedTeams() {
    _teams.addAll([
      {
        'id': _teamSales,
        'name': 'Kinh doanh & CSKH',
        'description':
            'Bán hàng tại cửa hàng, tư vấn qua điện thoại, chăm sóc '
            'khách sau mua.',
        'color': '#2563EB',
        'member_ids': [_me, _anh, _bao, _ha],
        'archived': false,
        'org_unit_type': 'team',
        'leader_user_id': _anh,
        'use_sales': true,
        'use_inbox': true,
        'leader_scope': false,
        'created_at': demoAgo(days: 120),
        'updated_at': demoAgo(days: 10),
      },
      {
        'id': _teamTech,
        'name': 'Kỹ thuật – giao lắp',
        'description': 'Giao hàng, lắp đặt và bảo hành tại nhà khách.',
        'color': '#0A7D76',
        'member_ids': [_me, _long, _anh],
        'archived': false,
        'org_unit_type': 'team',
        'leader_user_id': _long,
        'use_sales': false,
        'use_inbox': false,
        'leader_scope': false,
        'created_at': demoAgo(days: 120),
        'updated_at': demoAgo(days: 12),
      },
    ]);
  }

  Map<String, dynamic> _seedProject({
    required String id,
    required String name,
    required String? teamId,
    required String cover,
    required String color,
    required List<String> sections,
    Set<String> kpiSections = const {},
    Set<String> gatedSections = const {},
    String? owner,
    String? description,
    List<String> members = const [],
    Map<String, String> roles = const {},
    List<Map<String, dynamic>> customFields = const [],
    int createdDaysAgo = 30,
  }) => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'cover': cover,
    'status': 'active',
    'team_id': teamId,
    'owner_id': owner ?? _me,
    'sections': [
      for (var i = 0; i < sections.length; i++)
        {
          'id': 's${i + 1}',
          'name': sections[i],
          'order': i,
          if (gatedSections.contains(sections[i])) 'requires_checklist': true,
          if (kpiSections.contains(sections[i])) 'counts_for_kpi': true,
        },
    ],
    'member_ids': members,
    'member_roles': roles,
    'custom_fields': customFields,
    'is_template': false,
    'default_points': 0,
    'start_date': _day(-createdDaysAgo),
    'end_date': null,
    'tenant_id': demoTenantId,
    'created_by': owner ?? _me,
    'created_at': demoAgo(days: createdDaysAgo),
    'updated_at': demoAgo(days: 1),
  };

  void _seedProjects() {
    _projects.addAll([
      _seedProject(
        id: _pDelivery,
        name: 'Giao lắp tháng này',
        description: 'Mọi đơn cần giao và lắp đặt tại nhà khách trong tháng.',
        teamId: _teamTech,
        cover: 'teal-1',
        color: '#0A7D76',
        sections: ['Chờ xếp lịch', 'Đang giao', 'Đang lắp đặt', 'Hoàn tất'],
        kpiSections: {'Hoàn tất'},
        gatedSections: {'Hoàn tất'},
        members: [_me, _long, _anh, _ha],
        roles: {_anh: 'manager', _long: 'member', _ha: 'member'},
        createdDaysAgo: 27,
      ),
      _seedProject(
        id: _pWarranty,
        name: 'Bảo hành – sửa chữa',
        description: 'Tiếp nhận và xử lý yêu cầu bảo hành của khách.',
        teamId: _teamTech,
        cover: 'indigo-1',
        color: '#2563EB',
        sections: ['Tiếp nhận', 'Đang kiểm tra', 'Chờ linh kiện', 'Đã xử lý'],
        members: [_me, _long, _ha],
        roles: {_long: 'manager', _ha: 'member'},
        customFields: [
          {'id': 'cf_serial', 'name': 'Số serial', 'type': 'text'},
          {'id': 'cf_han_bh', 'name': 'Hạn bảo hành', 'type': 'date'},
        ],
        createdDaysAgo: 90,
      ),
      _seedProject(
        id: _pTet,
        name: 'Chiến dịch khuyến mãi Tết',
        description: 'Chuẩn bị chương trình giảm giá và quà tặng dịp Tết.',
        teamId: _teamSales,
        cover: 'clay-1',
        color: '#E8890C',
        sections: ['Ý tưởng', 'Chuẩn bị', 'Đang chạy', 'Đã xong'],
        owner: _anh,
        members: [_anh, _me, _bao, _ha],
        roles: {_me: 'manager', _bao: 'member', _ha: 'member'},
        customFields: [
          {'id': 'cf_ngan_sach', 'name': 'Ngân sách (đ)', 'type': 'number'},
          {
            'id': 'cf_kenh',
            'name': 'Kênh',
            'type': 'select',
            'options': ['Facebook', 'Zalo', 'Tại cửa hàng'],
          },
        ],
        createdDaysAgo: 14,
      ),
      _seedProject(
        id: _pStore,
        name: 'Việc chung cửa hàng',
        teamId: null,
        cover: 'slate-1',
        color: '#56637A',
        sections: ['Cần làm', 'Đang làm', 'Xong'],
        members: [_me, _anh, _bao, _ha, _long],
        createdDaysAgo: 60,
      ),
    ]);
  }

  /// Một việc gốc, kèm nhật ký dựng sẵn để màn chi tiết và Dòng việc có cái
  /// mà đọc.
  void _seed(
    int n, {
    required String title,
    required String project,
    required String section,
    String status = 'todo',
    String priority = 'med',
    List<String> assignees = const [],
    int? due,
    int? start,
    List<_Step> steps = const [],
    List<String> labels = const [],
    String? description,
    String? customer,
    int createdDaysAgo = 5,
    String? createdBy,
    bool pinned = false,
    bool archived = false,
    Map<String, dynamic> customFields = const {},
    List<(String user, String body, double hoursAgo, List<String> mentions)>
        comments =
        const [],
    int? doneHoursAgo,
  }) {
    final id = _taskId(n);
    final creator = createdBy ?? _me;
    final createdHours = createdDaysAgo * 24.0;
    final firstSection = _sectionsOf(project).firstOrNull?['id'];
    final order =
        1000.0 * (_tasks.where((t) => t['project_id'] == project).length + 1);
    var seq = 0;
    String actId() => '$id-a${++seq}';

    final activity = <Map<String, dynamic>>[
      {
        'id': actId(),
        'type': 'created',
        'user_id': creator,
        'created_at': _hoursAgo(createdHours),
      },
    ];
    if (assignees.isNotEmpty) {
      activity.add({
        'id': actId(),
        'type': 'assignees',
        'user_id': creator,
        'created_at': _hoursAgo(createdHours - 0.2),
      });
    }
    if (section != firstSection && firstSection != null) {
      activity.add({
        'id': actId(),
        'type': 'section_id',
        'user_id': assignees.firstOrNull ?? creator,
        'from': firstSection,
        'to': section,
        'created_at': _hoursAgo(createdHours * 0.45),
      });
    }

    final doneSteps = steps.where((s) => s.$2).length;
    var doneIndex = 0;
    final checklist = <Map<String, dynamic>>[];
    for (var i = 0; i < steps.length; i++) {
      final (stepTitle, done, who) = steps[i];
      checklist.add({
        'id': '$id-c${i + 1}',
        'title': stepTitle,
        'done': done,
        'assignee_id': ?who,
      });
      if (done) {
        doneIndex++;
        // Rải đều các lần tick trong khoảng từ lúc tạo tới (gần) bây giờ.
        final at = createdHours * (doneSteps + 1 - doneIndex) / (doneSteps + 2);
        activity.add({
          'id': actId(),
          'type': 'subtask_completed',
          'user_id': who ?? assignees.firstOrNull ?? creator,
          'title': stepTitle,
          'created_at': _hoursAgo(at.clamp(0.5, createdHours)),
        });
      }
    }

    String? completedAt;
    if (status == 'done') {
      final hours = (doneHoursAgo ?? 20).toDouble();
      completedAt = _hoursAgo(hours);
      activity.add({
        'id': actId(),
        'type': 'status',
        'user_id': assignees.firstOrNull ?? creator,
        'from': 'doing',
        'to': 'done',
        'created_at': completedAt,
      });
    }
    activity.sort(
      (a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'),
    );

    _tasks.add({
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'project_id': project,
      'section_id': section,
      'assignee_ids': assignees,
      'due_date': due == null ? null : _day(due),
      'start_date': start == null ? null : _day(start),
      'checklist': checklist,
      'custom_fields': customFields,
      'attachments': <Map<String, dynamic>>[],
      'rating': 0,
      'viewers': [
        for (final (i, who) in assignees.indexed)
          {'user_id': who, 'viewed_at': _hoursAgo(1.5 + i * 3)},
      ],
      'comments': [
        for (final (i, (who, body, hours, mentions)) in comments.indexed)
          {
            'id': '$id-m${i + 1}',
            'body': body,
            'user_id': who,
            'mentioned_user_ids': mentions,
            'created_at': _hoursAgo(hours),
            'attachments': <Map<String, dynamic>>[],
          },
      ],
      'activity': activity,
      'labels': labels,
      'likes': <String>[],
      'archived': archived,
      'pinned': pinned,
      'locked': false,
      'follower_ids': null,
      'assigned_by': assignees.isEmpty ? null : creator,
      'created_by': creator,
      'customer_id': null,
      'customer_name': customer,
      'order': order,
      'created_at': _hoursAgo(createdHours),
      'updated_at': _hoursAgo(createdHours * 0.3),
      'completed_at': completedAt,
    });
  }

  void _seedTasks() {
    // ── Giao lắp tháng này ──
    _seed(
      1,
      title: 'Giao tủ lạnh Inverter 380L – chị Hoa, Bình Thạnh',
      project: _pDelivery,
      section: 's2',
      status: 'doing',
      priority: 'high',
      assignees: [_long, _me],
      due: 0,
      customer: 'Chị Hoa',
      labels: ['lap_dat'],
      pinned: true,
      description:
          'Nhà ở tầng 3, không có thang máy — cần 2 người khiêng. '
          'Khách còn thanh toán 4.500.000đ khi nhận hàng.',
      steps: [
        ('Gọi xác nhận giờ giao', true, _me),
        ('Kiểm tra hàng trước khi xuất kho', true, _long),
        ('Giao và hướng dẫn sử dụng', false, _long),
        ('Thu tiền còn lại', false, _long),
      ],
      comments: [
        (_long, 'Khách hẹn giao sau 14h, em đã gọi xác nhận lại.', 3, []),
        (
          _me,
          'Ok em. Nhớ mang phiếu bảo hành và chụp ảnh lúc bàn giao nhé '
              '@Nguyễn Đức Long',
          1.2,
          [_long],
        ),
      ],
      createdDaysAgo: 3,
    );
    _seed(
      2,
      title: 'Lắp máy lạnh 1.5HP – anh Tuấn, Thủ Đức',
      project: _pDelivery,
      section: 's3',
      status: 'doing',
      priority: 'high',
      assignees: [_long],
      due: -1,
      customer: 'Anh Tuấn',
      labels: ['lap_dat', 'giao_gap'],
      steps: [
        ('Khảo sát vị trí dàn nóng', true, _long),
        ('Đi ống đồng, khoan tường', true, _long),
        ('Hút chân không', false, _long),
        ('Chạy thử và bàn giao', false, _long),
      ],
      comments: [
        (
          _long,
          'Ống đồng thiếu 2m, chiều nay em lấy thêm ở kho rồi làm tiếp.',
          20,
          [],
        ),
      ],
      createdDaysAgo: 4,
    );
    _seed(
      3,
      title: 'Giao sofa góc chữ L – cô Lan, Quận 7',
      project: _pDelivery,
      section: 's1',
      assignees: [_me],
      due: 2,
      customer: 'Cô Lan',
      steps: [
        ('Hẹn lịch với khách', false, _me),
        ('Chuẩn bị xe tải nhỏ', false, _long),
      ],
      createdDaysAgo: 2,
    );
    _seed(
      4,
      title: 'Giao bộ bàn ăn 6 ghế gỗ sồi – anh Phúc',
      project: _pDelivery,
      section: 's1',
      assignees: [_long],
      due: 3,
      customer: 'Anh Phúc',
      createdDaysAgo: 1,
    );
    _seed(
      5,
      title: 'Lắp máy giặt cửa trước 9kg – chị Ngọc',
      project: _pDelivery,
      section: 's4',
      status: 'done',
      assignees: [_long],
      due: -2,
      customer: 'Chị Ngọc',
      labels: ['lap_dat'],
      steps: [
        ('Tháo bu lông vận chuyển', true, _long),
        ('Nối ống cấp và xả nước', true, _long),
        ('Chạy thử một chu trình', true, _long),
      ],
      createdDaysAgo: 6,
      doneHoursAgo: 30,
    );
    _seed(
      6,
      title: 'Giao và lắp kệ tivi treo tường – anh Khoa',
      project: _pDelivery,
      section: 's4',
      status: 'done',
      priority: 'low',
      assignees: [_long, _me],
      due: -4,
      customer: 'Anh Khoa',
      steps: [
        ('Khoan và bắt giá treo', true, _long),
        ('Cân thăng bằng, đi dây gọn', true, _long),
      ],
      createdDaysAgo: 8,
      doneHoursAgo: 75,
    );
    _seed(
      7,
      title: 'Giao tủ quần áo 3 cánh – chị My, Gò Vấp',
      project: _pDelivery,
      section: 's2',
      status: 'doing',
      assignees: [_me],
      due: 0,
      customer: 'Chị My',
      labels: ['khach_vip'],
      createdDaysAgo: 2,
    );

    // ── Bảo hành – sửa chữa ──
    _seed(
      8,
      title: 'Máy lạnh không mát – anh Dũng (mua tháng 3)',
      project: _pWarranty,
      section: 's2',
      status: 'doing',
      priority: 'high',
      assignees: [_long],
      due: -3,
      customer: 'Anh Dũng',
      labels: ['bao_hanh'],
      customFields: {'cf_serial': 'ML15-008721'},
      steps: [
        ('Kiểm tra gas', true, _long),
        ('Vệ sinh dàn lạnh', false, _long),
      ],
      comments: [
        (
          _ha,
          'Khách báo máy chạy khoảng 10 phút thì không còn mát. Đã hẹn kỹ '
              'thuật qua kiểm tra gas.',
          50,
          [],
        ),
      ],
      createdDaysAgo: 5,
      createdBy: _ha,
    );
    _seed(
      9,
      title: 'Tủ lạnh kêu to khi chạy – chị Thảo',
      project: _pWarranty,
      section: 's1',
      assignees: [_ha],
      due: 1,
      customer: 'Chị Thảo',
      labels: ['bao_hanh'],
      createdDaysAgo: 1,
      createdBy: _ha,
    );
    _seed(
      10,
      title: 'Thay bo mạch máy giặt – cô Bích',
      project: _pWarranty,
      section: 's3',
      assignees: [_long, _me],
      due: 5,
      customer: 'Cô Bích',
      labels: ['bao_hanh', 'cho_hang'],
      customFields: {'cf_serial': 'MG9-110354'},
      steps: [
        ('Đặt bo mạch với hãng', true, _me),
        ('Hẹn ngày thay với khách', false, _long),
      ],
      createdDaysAgo: 7,
    );
    _seed(
      11,
      title: 'Nồi chiên không dầu lỗi nút nguồn – đổi máy mới',
      project: _pWarranty,
      section: 's4',
      status: 'done',
      priority: 'low',
      assignees: [_ha],
      due: -6,
      labels: ['bao_hanh'],
      createdDaysAgo: 9,
      doneHoursAgo: 120,
      createdBy: _ha,
    );
    _seed(
      12,
      title: 'Ghế sofa bong da tay vịn – kiểm tra tại nhà',
      project: _pWarranty,
      section: 's1',
      priority: 'low',
      assignees: [_me],
      labels: ['bao_hanh'],
      createdDaysAgo: 2,
      createdBy: _ha,
    );

    // ── Chiến dịch khuyến mãi Tết ──
    _seed(
      13,
      title: 'Lên danh sách sản phẩm giảm giá Tết',
      project: _pTet,
      section: 's2',
      status: 'doing',
      priority: 'high',
      assignees: [_anh, _me],
      due: 4,
      createdBy: _anh,
      customFields: {'cf_kenh': 'Tại cửa hàng'},
      steps: [
        ('Chọn 20 mã điện lạnh', true, _anh),
        ('Chọn 10 mã nội thất', false, _me),
        ('Chốt mức giảm với kế toán', false, _anh),
      ],
      comments: [
        (_anh, 'Mọi người góp ý danh sách trước thứ Sáu nhé.', 26, []),
      ],
      createdDaysAgo: 6,
    );
    _seed(
      14,
      title: 'Thiết kế banner và tờ rơi khuyến mãi',
      project: _pTet,
      section: 's2',
      assignees: [_bao],
      due: 7,
      createdBy: _anh,
      customFields: {'cf_kenh': 'Facebook', 'cf_ngan_sach': 3000000},
      createdDaysAgo: 4,
    );
    _seed(
      15,
      title: 'Nhắn tin Zalo chúc Tết cho khách cũ',
      project: _pTet,
      section: 's1',
      assignees: [_ha],
      due: 10,
      createdBy: _anh,
      customFields: {'cf_kenh': 'Zalo'},
      createdDaysAgo: 3,
    );
    _seed(
      16,
      title: 'Chuẩn bị quà tặng kèm (bao lì xì, móc khoá)',
      project: _pTet,
      section: 's1',
      priority: 'low',
      assignees: [_me],
      due: 12,
      createdBy: _anh,
      createdDaysAgo: 3,
    );
    _seed(
      17,
      title: 'Chụp ảnh bộ sản phẩm mới cho fanpage',
      project: _pTet,
      section: 's4',
      status: 'done',
      assignees: [_bao],
      due: -5,
      createdBy: _anh,
      steps: [('Dọn góc trưng bày', true, _bao), ('Chụp 30 tấm', true, _bao)],
      createdDaysAgo: 10,
      doneHoursAgo: 100,
    );

    // ── Việc chung cửa hàng ──
    _seed(
      18,
      title: 'Kiểm kê kho cuối tháng',
      project: _pStore,
      section: 's1',
      priority: 'high',
      assignees: [_me, _bao],
      due: 2,
      steps: [
        ('Kho điện lạnh', false, _bao),
        ('Kho nội thất', false, _me),
        ('Phụ kiện và linh kiện', false, null),
      ],
      createdDaysAgo: 2,
    );
    _seed(
      19,
      title: 'Gửi báo giá điều hoà cho văn phòng anh Vinh',
      project: _pStore,
      section: 's2',
      status: 'doing',
      priority: 'high',
      assignees: [_bao, _me],
      due: -1,
      customer: 'Anh Vinh',
      labels: ['khach_vip'],
      steps: [
        ('Khảo sát diện tích các phòng', true, _bao),
        ('Lập báo giá 6 máy', false, _bao),
      ],
      createdDaysAgo: 4,
    );
    _seed(
      20,
      title: 'Gọi lại khách hỏi giá bếp từ đôi',
      project: _pStore,
      section: 's2',
      status: 'doing',
      assignees: [_me],
      due: 0,
      createdDaysAgo: 1,
    );
    _seed(
      21,
      title: 'Sắp xếp lại khu trưng bày sofa',
      project: _pStore,
      section: 's3',
      status: 'done',
      priority: 'low',
      assignees: [_anh, _long],
      due: -3,
      createdDaysAgo: 7,
      doneHoursAgo: 60,
    );
    _seed(
      22,
      title: 'Cập nhật bảng giá mới lên quầy',
      project: _pStore,
      section: 's1',
      assignees: [_ha],
      createdDaysAgo: 1,
    );
    _seed(
      23,
      title: 'Dọn hàng trưng bày mẫu cũ',
      project: _pStore,
      section: 's3',
      status: 'done',
      priority: 'low',
      assignees: [_long],
      due: -20,
      archived: true,
      createdDaysAgo: 25,
      doneHoursAgo: 400,
    );
  }

  // ── Tra cứu ──────────────────────────────────────────────────────────────

  Map<String, dynamic>? _project(Object? id) {
    final key = _s(id);
    for (final p in _projects) {
      if (p['id'] == key) return p;
    }
    return null;
  }

  Map<String, dynamic>? _task(Object? id) {
    final key = _s(id);
    for (final t in _tasks) {
      if (t['id'] == key) return t;
    }
    return null;
  }

  Map<String, dynamic>? _team(Object? id) {
    final key = _s(id);
    for (final t in _teams) {
      if (t['id'] == key) return t;
    }
    return null;
  }

  List<Map<String, dynamic>> _sectionsOf(Object? projectId) =>
      _maps(_project(projectId)?['sections']);

  void _log(
    Map<String, dynamic> task,
    String type, {
    String? from,
    String? to,
    String? title,
    String? name,
  }) {
    final activity = _maps(task['activity'])
      ..add({
        'id': demoNewId(),
        'type': type,
        'user_id': _me,
        'from': ?from,
        'to': ?to,
        'title': ?title,
        'name': ?name,
        'created_at': _now(),
      });
    // API giữ tối đa 200 dòng, cắt phần cũ nhất.
    task['activity'] = activity.length > 200
        ? activity.sublist(activity.length - 200)
        : activity;
  }

  void _touch(Map<String, dynamic> task) => task['updated_at'] = _now();

  // ── Trình bày như presenter của API ──────────────────────────────────────

  Map<String, dynamic> _presentStep(Map<String, dynamic> c) {
    final who = _s(c['assignee_id']);
    return {
      'id': c['id'],
      'title': c['title'],
      'done': c['done'] == true,
      'assignee_id': ?who,
      'assignee_name': ?_nameOf(who),
      'due_date': ?_s(c['due_date']),
      'start_date': ?_s(c['start_date']),
      'description': ?_s(c['description']),
    };
  }

  Map<String, dynamic> _presentComment(Map<String, dynamic> c) {
    final mentions = _strs(c['mentioned_user_ids']);
    return {
      'id': c['id'],
      'body': c['body'] ?? '',
      'user_id': c['user_id'],
      'user_name': ?_nameOf(c['user_id']),
      'mentioned_user_ids': mentions,
      'mentioned_user_names': [for (final id in mentions) ?_nameOf(id)],
      'created_at': c['created_at'],
      'attachments': _maps(c['attachments']),
    };
  }

  Map<String, dynamic> _present(Map<String, dynamic> t, {bool detail = false}) {
    final project = _project(t['project_id']);
    final sections = _sectionsOf(t['project_id']);
    final sectionId = _s(t['section_id']);
    String? sectionName;
    for (final s in sections) {
      if (s['id'] == sectionId) sectionName = _s(s['name']);
    }
    final assignees = _strs(t['assignee_ids']);
    final followers = t['follower_ids'] == null
        ? null
        : _strs(t['follower_ids']);
    final comments = _maps(t['comments']);
    final assignedBy = _s(t['assigned_by']);
    final due = _s(t['due_date']);

    return {
      'id': t['id'],
      'title': t['title'],
      'description': ?_s(t['description']),
      'status': t['status'],
      'priority': t['priority'],
      'project_id': ?_s(t['project_id']),
      'project_name': ?_s(project?['name']),
      'section_id': ?sectionId,
      'section_name': ?sectionName,
      'assignee_ids': assignees,
      'assignee_names': [
        for (final id in assignees) _nameOf(id) ?? 'Thành viên',
      ],
      'assignee_avatars': [for (final _ in assignees) null],
      'due_date': ?due,
      'deadline': ?due,
      'start_date': ?_s(t['start_date']),
      'checklist': [for (final c in _maps(t['checklist'])) _presentStep(c)],
      'custom_fields': t['custom_fields'] ?? <String, dynamic>{},
      'attachments': _maps(t['attachments']),
      'rating': t['rating'] ?? 0,
      'labels': _strs(t['labels']),
      if (_strs(t['likes']).isNotEmpty) 'likes': _strs(t['likes']),
      'archived': t['archived'] == true,
      'pinned': t['pinned'] == true,
      'locked': t['locked'] == true,
      if (followers != null) ...{
        'follower_ids': followers,
        'follower_names': [for (final id in followers) _nameOf(id)],
        'follower_avatars': [for (final _ in followers) null],
      },
      'assigned_by': ?assignedBy,
      'assigned_by_name': ?_nameOf(assignedBy),
      'created_by': t['created_by'],
      'created_by_name': ?_nameOf(t['created_by']),
      'customer_id': ?_s(t['customer_id']),
      'customer_name': ?_s(t['customer_name']),
      'order': t['order'],
      'comments_count': comments.length,
      'viewers': [
        for (final v in _maps(t['viewers']))
          {
            'user_id': v['user_id'],
            'name': ?_nameOf(v['user_id']),
            'viewed_at': v['viewed_at'],
          },
      ],
      'completed_at': ?_s(t['completed_at']),
      'created_at': t['created_at'],
      'updated_at': t['updated_at'],
      // Chi tiết mới mang những phần nặng, như `TaskController::listRow`.
      if (detail) ...{
        'plan_sections': [
          for (final s in sections)
            {'id': s['id'], 'name': s['name'], 'order': s['order']},
        ],
        'comments': [
          for (final c
              in comments.length > 20
                  ? comments.sublist(comments.length - 20)
                  : comments)
            _presentComment(c),
        ],
        'activity': [
          for (final a in _maps(t['activity']))
            {...a, 'user_name': ?_nameOf(a['user_id'])},
        ],
      },
    };
  }

  Map<String, int> _statsOf(String projectId) {
    final today = _day(0);
    var total = 0, done = 0, overdue = 0;
    for (final t in _tasks) {
      if (t['project_id'] != projectId || t['archived'] == true) continue;
      total++;
      if (t['status'] == 'done') {
        done++;
      } else if (_s(t['due_date']) case final due?
          when due.compareTo(today) < 0) {
        overdue++;
      }
    }
    return {
      'total': total,
      'done': done,
      'overdue': overdue,
      'progress': total == 0 ? 0 : (done * 100 / total).round(),
    };
  }

  Map<String, dynamic> _presentProject(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final people = {..._strs(p['member_ids']), ?_s(p['owner_id'])};
    return {
      ...p,
      'team_name': ?_s(_team(p['team_id'])?['name']),
      'stats': _statsOf(id),
      'is_favorite': _favorites.contains(id),
      'member_names': {for (final u in people) u: _nameOf(u)},
      'member_avatars': {for (final u in people) u: null},
      'member_active': {for (final u in people) u: true},
    };
  }

  Map<String, dynamic> _membership(DemoPerson p) => {
    'id': p.membershipId,
    'tenant_id': demoTenantId,
    'user_id': p.id,
    'employee_code': null,
    'member_type': 'employee',
    'status': 'active',
    'job_title': p.jobTitle,
    'joined_at': demoAgo(days: 200),
    'left_at': null,
    'manager_membership_id': null,
    'zalo_user_id': _zalo[p.membershipId],
    'metadata': {'name': p.name},
    'created_at': demoAgo(days: 200),
    'updated_at': demoAgo(days: 3),
    'accepted': true,
    'can_activate': false,
    'invite_email': null,
  };

  Map<String, dynamic> _user(DemoPerson p) => {
    ...p.toUserJson(),
    'created_at': demoAgo(days: 200),
    'updated_at': demoAgo(days: 3),
  };

  // ── Lọc danh sách việc ───────────────────────────────────────────────────

  bool _inBucket(Map<String, dynamic> t, String bucket) {
    final done = t['status'] == 'done';
    final due = _s(t['due_date']);
    final today = _day(0);
    return switch (bucket) {
      'today' => !done && due == today,
      'overdue' => !done && due != null && due.compareTo(today) < 0,
      'upcoming' => !done && due != null && due.compareTo(today) > 0,
      'open' => !done,
      _ => true,
    };
  }

  bool _matches(Map<String, dynamic> t, String needle) {
    final hay = foldDiacritics(
      [
        t['title'],
        t['description'],
        t['customer_name'],
        _project(t['project_id'])?['name'],
      ].whereType<String>().join(' '),
    );
    return hay.contains(foldDiacritics(needle));
  }

  DemoResponse _listTasks(DemoRequest req) {
    final archived = req.q('archived') ?? 'active';
    final projectId = req.q('project_id');
    final assignee = req.q('assignee') == 'me'
        ? _me
        : _userId(req.q('assignee_id'));
    final search = req.q('search');
    final bucket = req.q('bucket') ?? 'all';

    final rows = _tasks.where((t) {
      final isArchived = t['archived'] == true;
      if (archived == 'active' && isArchived) return false;
      if (archived == 'archived' && !isArchived) return false;
      if (projectId != null && t['project_id'] != projectId) return false;
      if ((req.q('assignee') != null || req.q('assignee_id') != null) &&
          !_strs(t['assignee_ids']).contains(assignee)) {
        return false;
      }
      if (search != null && !_matches(t, search)) return false;
      return _inBucket(t, bucket);
    }).toList();

    if (projectId != null) {
      // Thứ tự bảng: ghim trước, rồi `order`, rồi ngày tạo.
      rows.sort((a, b) {
        final pin =
            (b['pinned'] == true ? 1 : 0) - (a['pinned'] == true ? 1 : 0);
        if (pin != 0) return pin;
        final order = ((a['order'] as num?) ?? 0).compareTo(
          (b['order'] as num?) ?? 0,
        );
        if (order != 0) return order;
        return '${a['created_at']}'.compareTo('${b['created_at']}');
      });
    } else {
      // Hàng đợi của một người: hạn gần nhất trước, việc không hạn xuống cuối.
      rows.sort((a, b) {
        final da = _s(a['due_date']) ?? '9999';
        final db = _s(b['due_date']) ?? '9999';
        final c = da.compareTo(db);
        if (c != 0) return c;
        return '${b['created_at']}'.compareTo('${a['created_at']}');
      });
    }

    return paged(req, [for (final t in rows) _present(t)], defaultPerPage: 30);
  }

  // ── Ghi một việc ─────────────────────────────────────────────────────────

  /// `PUT /tasks/{id}`: chỉ những khoá có gửi. Khoá gửi kèm null/'' là XOÁ
  /// (như `UpdateTaskDTO::$provided`).
  DemoResponse? _applyTaskPatch(
    Map<String, dynamic> t,
    Map<String, dynamic> body,
  ) {
    if (body.containsKey('title')) {
      final title = _s(body['title']);
      if (title == null) return _invalid('title', 'Tên việc không được trống.');
      t['title'] = title;
    }
    if (body.containsKey('description')) {
      t['description'] = _s(body['description']);
    }
    if (body.containsKey('priority')) {
      t['priority'] = _priority(body['priority']);
    }
    if (body.containsKey('rating')) {
      t['rating'] = (int.tryParse('${body['rating']}') ?? 0).clamp(0, 5);
    }
    if (body.containsKey('due_date')) {
      final due = _s(body['due_date']);
      if (due != t['due_date']) {
        t['due_date'] = due;
        _log(t, 'due_date');
      }
    }
    if (body.containsKey('start_date')) {
      t['start_date'] = _s(body['start_date']);
    }
    if (body.containsKey('assignee_ids')) {
      final ids = <String>[];
      for (final raw in _strs(body['assignee_ids'])) {
        final id = _userId(raw);
        if (id == null) {
          return _invalid('assignee_ids', 'Người được giao không hợp lệ.');
        }
        if (!ids.contains(id)) ids.add(id);
      }
      final before = _strs(t['assignee_ids']);
      if (ids.any((id) => !before.contains(id))) t['assigned_by'] = _me;
      if (ids.length != before.length ||
          ids.any((id) => !before.contains(id))) {
        t['assignee_ids'] = ids;
        _log(t, 'assignees');
      }
    }
    if (body.containsKey('follower_ids')) {
      final ids = <String>[];
      for (final raw in _strs(body['follower_ids'])) {
        final id = _userId(raw);
        if (id == null) {
          return _invalid('follower_ids', 'Người theo dõi không hợp lệ.');
        }
        if (!ids.contains(id)) ids.add(id);
      }
      t['follower_ids'] = ids;
    }
    if (body.containsKey('labels')) t['labels'] = _strs(body['labels']);
    if (body.containsKey('archived')) t['archived'] = _bool(body['archived']);
    if (body.containsKey('custom_fields')) {
      final fields = body['custom_fields'];
      t['custom_fields'] = fields is Map
          ? Map<String, dynamic>.from(fields)
          : <String, dynamic>{};
    }
    if (body.containsKey('project_id')) {
      final projectId = _s(body['project_id']);
      if (projectId == null || _project(projectId) == null) {
        return _invalid('project_id', 'Kế hoạch không tồn tại.');
      }
      t['project_id'] = projectId;
    }
    if (body.containsKey('section_id')) {
      final to = _s(body['section_id']);
      final from = _s(t['section_id']);
      if (to != from) {
        t['section_id'] = to;
        _log(t, 'section_id', from: from, to: to);
      }
    }
    if (body['order'] is num) t['order'] = (body['order'] as num).toDouble();
    if (body.containsKey('status')) _setStatus(t, _s(body['status']) ?? 'todo');
    _touch(t);
    return null;
  }

  void _setStatus(Map<String, dynamic> t, String status) {
    final from = _s(t['status']) ?? 'todo';
    if (from == status) return;
    t['status'] = status;
    t['completed_at'] = status == 'done' ? _now() : null;
    _log(t, 'status', from: from, to: status);
  }

  double _nextOrder(String? projectId) {
    var max = 0.0;
    for (final t in _tasks) {
      if (t['project_id'] != projectId) continue;
      final o = (t['order'] as num?)?.toDouble() ?? 0;
      if (o > max) max = o;
    }
    return max + 1000;
  }

  Map<String, dynamic> _newTask({
    required String title,
    String? projectId,
    String? sectionId,
    double? order,
    List<String> assignees = const [],
    String? due,
    String? start,
    String priority = 'med',
    String? description,
    List<Map<String, dynamic>> checklist = const [],
    List<String> labels = const [],
    Map<String, dynamic> customFields = const {},
    String? customerName,
  }) {
    final now = _now();
    final task = <String, dynamic>{
      'id': demoNewId(),
      'title': title,
      'description': description,
      'status': 'todo',
      'priority': priority,
      'project_id': projectId,
      'section_id': sectionId,
      'assignee_ids': assignees,
      'due_date': due,
      'start_date': start,
      'checklist': checklist,
      'custom_fields': {...customFields},
      'attachments': <Map<String, dynamic>>[],
      'rating': 0,
      'viewers': <Map<String, dynamic>>[],
      'comments': <Map<String, dynamic>>[],
      'activity': <Map<String, dynamic>>[],
      'labels': labels,
      'likes': <String>[],
      'archived': false,
      'pinned': false,
      'locked': false,
      'follower_ids': null,
      'assigned_by': assignees.isEmpty ? null : _me,
      'created_by': _me,
      'customer_id': null,
      'customer_name': customerName,
      'order': order ?? _nextOrder(projectId),
      'created_at': now,
      'updated_at': now,
      'completed_at': null,
    };
    _log(task, 'created');
    if (assignees.isNotEmpty) _log(task, 'assignees');
    _tasks.add(task);
    return task;
  }

  // ── KPI và dòng việc ─────────────────────────────────────────────────────

  Map<String, dynamic> _kpi(DemoRequest req) {
    final projectId = req.q('project_id');
    final today = VnTime.today();
    final asked = DateTime.tryParse(req.q('month') ?? '');
    final month = asked == null
        ? DateTime.utc(today.year, today.month)
        : DateTime.utc(asked.year, asked.month);
    final current = DateTime.utc(today.year, today.month);
    final nextMonth = DateTime.utc(month.year, month.month + 1);

    final counting = <String>[];
    var live = 0;
    for (final p in _projects) {
      if (projectId != null && p['id'] != projectId) continue;
      final kpiSections = {
        for (final s in _maps(p['sections']))
          if (s['counts_for_kpi'] == true) s['id'],
      };
      for (final s in _maps(p['sections'])) {
        if (s['counts_for_kpi'] == true) counting.add('${s['name']}');
      }
      for (final t in _tasks) {
        if (t['project_id'] == p['id'] &&
            t['archived'] != true &&
            kpiSections.contains(t['section_id'])) {
          live++;
        }
      }
    }

    // Tháng đang chạy: một nền cố định cộng số việc đang nằm ở cột đích, để
    // kéo một thẻ sang "Hoàn tất" là thấy KPI nhích. Tháng cũ: số cố định.
    final int delivered;
    if (counting.isEmpty || month.isAfter(current)) {
      delivered = 0;
    } else if (month == current) {
      delivered = 19 + live;
    } else {
      delivered = 24 + (month.month % 3) * 4;
    }

    const tiers = {'25': 1500000, '35': 3000000, '50': 5000000};
    var reached = 0;
    Map<String, dynamic>? next;
    for (final e in tiers.entries) {
      final count = int.parse(e.key);
      if (delivered >= count) {
        reached = e.value;
      } else {
        next ??= {
          'count': count,
          'bonus': e.value,
          'remaining': count - delivered,
        };
      }
    }
    final lastDay = nextMonth.subtract(const Duration(days: 1));

    return {
      'from': _ymd(month),
      'until': _ymd(lastDay),
      'delivered': delivered,
      'reached_bonus': reached,
      'next_tier': next,
      'tiers': tiers,
      'days_left': month == current ? lastDay.day - today.day : 0,
      'counting_sections': counting,
      'rework': counting.isEmpty || month.isAfter(current) ? 0 : 1,
    };
  }

  DemoResponse _feed(DemoRequest req) {
    final types = _csv(req.q('types')).toSet();
    final since = req.q('since');
    final limit = req.qInt('limit', 30).clamp(1, 200);

    final entries = <Map<String, dynamic>>[];
    void add(Map<String, dynamic> t, Map<String, dynamic> a) {
      final at = DateTime.tryParse('${a['created_at']}');
      if (at == null) return;
      final day = _ymd(VnTime.day(at));
      if (since != null && day.compareTo(since) < 0) return;
      if (types.isNotEmpty && !types.contains(a['type'])) return;
      entries.add({
        ...a,
        'task_id': t['id'],
        'task_title': t['title'],
        'project_name': ?_s(_project(t['project_id'])?['name']),
        'user_name': ?_nameOf(a['user_id']),
        'day': day,
        'photos': <String>[],
      });
    }

    for (final t in _tasks) {
      if (t['archived'] == true) continue;
      for (final a in _maps(t['activity'])) {
        add(t, a);
      }
      // "Xong toàn bộ": một dòng riêng khi việc chuyển sang xong.
      if (t['status'] == 'done' && _s(t['completed_at']) != null) {
        add(t, {
          'id': '${t['id']}-done',
          'type': 'piano_done',
          'user_id': _strs(t['assignee_ids']).firstOrNull ?? t['created_by'],
          'created_at': t['completed_at'],
        });
      }
    }
    entries.sort(
      (a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'),
    );

    return DemoResponse(200, {
      'success': true,
      'data': entries.length > limit ? entries.sublist(0, limit) : entries,
      'truncated': false,
    });
  }

  // ── Bảng route ───────────────────────────────────────────────────────────

  void register(DemoRoutes r) {
    _registerTasks(r);
    _registerChecklist(r);
    _registerTaskExtras(r);
    _registerProjects(r);
    _registerTeams(r);
    _registerPeople(r);
    _registerLabels(r);
  }

  void _registerTasks(DemoRoutes r) {
    // Đường tĩnh ĐỨNG TRƯỚC `/tasks/{id}`: route khớp theo thứ tự đăng ký.
    r.get('/tasks/kpi', (req) => ok(_kpi(req)));
    r.get('/tasks/feed', _feed);
    r.get('/tasks/stats', (req) {
      final who = _userId(req.q('assignee_id')) ?? _me;
      final overdue = _tasks
          .where(
            (t) =>
                t['archived'] != true &&
                _strs(t['assignee_ids']).contains(who) &&
                _inBucket(t, 'overdue'),
          )
          .length;
      return ok({'overdue': overdue});
    });

    r.get('/tasks', _listTasks);

    r.post('/tasks', (req) {
      final body = req.json;
      final title = _s(body['title']);
      if (title == null) return _invalid('title', 'Tên việc không được trống.');
      final projectId = _s(body['project_id']);
      if (projectId != null && _project(projectId) == null) {
        return _invalid('project_id', 'Kế hoạch không tồn tại.');
      }
      final assignees = <String>[
        for (final raw in _strs(body['assignee_ids'])) ?_userId(raw),
      ];
      final task = _newTask(
        title: title,
        projectId: projectId,
        sectionId: _s(body['section_id']),
        order: body['order'] is num ? (body['order'] as num).toDouble() : null,
        assignees: assignees,
        due: _s(body['due_date']),
        priority: _priority(body['priority']),
        description: _s(body['description']),
      );
      return created(_present(task, detail: true));
    });

    r.get('/tasks/{id}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      // Người mở việc được ghi vào "đã xem", như API.
      final viewers = _maps(t['viewers'])
        ..removeWhere((v) => v['user_id'] == _me)
        ..add({'user_id': _me, 'viewed_at': _now()});
      t['viewers'] = viewers;
      return ok(_present(t, detail: true));
    });

    r.put('/tasks/{id}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final error = _applyTaskPatch(t, req.json);
      return error ?? ok(_present(t, detail: true));
    });

    r.patch('/tasks/{id}/status', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final status = _s(req.json['status']);
      if (status == null) {
        return _invalid('status', 'Trạng thái không hợp lệ.');
      }
      _setStatus(t, status);
      _touch(t);
      return ok(_present(t, detail: true));
    });

    r.delete('/tasks/{id}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      _tasks.remove(t);
      _reminders.remove(t['id']);
      return ok(null);
    });

    r.post('/tasks/{id}/claim', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final ids = _strs(t['assignee_ids']);
      if (!ids.contains(_me)) {
        t['assignee_ids'] = [...ids, _me];
        t['assigned_by'] = _me;
        _log(t, 'assignees');
        _touch(t);
      }
      return ok(_present(t, detail: true));
    });

    r.post('/tasks/{id}/copy', (req) {
      final source = _task(req.params['id']);
      if (source == null) return notFound('Không tìm thấy công việc.');
      final body = req.json;
      final projectId = _s(body['project_id']) ?? _s(source['project_id']);
      if (projectId != null && _project(projectId) == null) {
        return _invalid('project_id', 'Kế hoạch không tồn tại.');
      }
      final sameProject = projectId == source['project_id'];
      final assignees = body.containsKey('assignee_ids')
          ? [for (final raw in _strs(body['assignee_ids'])) ?_userId(raw)]
          : (body['keep_assignees'] == false
                ? <String>[]
                : _strs(source['assignee_ids']));
      final keepChecklist = body['keep_checklist'] != false;
      final keepFields = body.containsKey('keep_custom_fields')
          ? body['keep_custom_fields'] == true
          : sameProject;
      final copy = _newTask(
        title: _s(body['title']) ?? '${source['title']} (bản sao)',
        projectId: projectId,
        sectionId:
            _s(body['section_id']) ??
            (sameProject ? _s(source['section_id']) : null),
        assignees: assignees,
        due: body.containsKey('due_date')
            ? _s(body['due_date'])
            : _s(source['due_date']),
        start: body.containsKey('start_date')
            ? _s(body['start_date'])
            : _s(source['start_date']),
        priority: _priority(source['priority']),
        description: _s(source['description']),
        labels: _strs(source['labels']),
        customerName: _s(source['customer_name']),
        customFields: keepFields
            ? Map<String, dynamic>.from(
                (source['custom_fields'] as Map?) ?? const {},
              )
            : const {},
        checklist: keepChecklist
            ? [
                for (final c in _maps(source['checklist']))
                  {...c, 'id': demoNewId(), 'done': false},
              ]
            : const [],
      );
      return created(_present(copy, detail: true));
    });
  }

  void _registerChecklist(DemoRoutes r) {
    r.post('/tasks/{id}/checklist', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final body = req.json;
      final title = _s(body['title']);
      if (title == null) {
        return _invalid('title', 'Tên việc con không được trống.');
      }
      final assignee = _s(body['assignee_id']);
      if (assignee != null && _userId(assignee) == null) {
        return _invalid('assignee_id', 'Người làm không thuộc workspace.');
      }
      t['checklist'] = [
        ..._maps(t['checklist']),
        {
          'id': demoNewId(),
          'title': title,
          'done': false,
          'assignee_id': ?_userId(assignee),
          'description': ?_s(body['description']),
          'start_date': ?_s(body['start_date']),
          'due_date': ?_s(body['due_date']),
        },
      ];
      _touch(t);
      return created(_present(t, detail: true));
    });

    r.patch('/tasks/{id}/checklist/{itemId}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final items = _maps(t['checklist']);
      final index = items.indexWhere((c) => c['id'] == req.params['itemId']);
      if (index < 0) return notFound('Không tìm thấy việc con.');
      final item = items[index];
      final body = req.json;

      if (body.containsKey('done')) {
        final done = _bool(body['done']);
        if (done && item['done'] != true) {
          _log(t, 'subtask_completed', title: '${item['title']}');
        }
        item['done'] = done;
      }
      if (body.containsKey('title')) {
        final title = _s(body['title']);
        if (title == null) {
          return _invalid('title', 'Tên việc con không được trống.');
        }
        item['title'] = title;
      }
      if (body.containsKey('assignee_id')) {
        final raw = _s(body['assignee_id']);
        final id = _userId(raw);
        if (raw != null && id == null) {
          return _invalid('assignee_id', 'Người làm không thuộc workspace.');
        }
        if (id == null) {
          item.remove('assignee_id');
        } else {
          item['assignee_id'] = id;
          _log(t, 'subtask_assigned', title: '${item['title']}');
        }
      }
      for (final key in const ['due_date', 'start_date', 'description']) {
        if (!body.containsKey(key)) continue;
        final value = _s(body[key]);
        if (value == null) {
          item.remove(key);
        } else {
          item[key] = value;
        }
      }
      items[index] = item;
      t['checklist'] = items;
      _touch(t);
      return ok(_present(t, detail: true));
    });

    r.delete('/tasks/{id}/checklist/{itemId}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      t['checklist'] = _maps(t['checklist'])
        ..removeWhere((c) => c['id'] == req.params['itemId']);
      _touch(t);
      return ok(_present(t, detail: true));
    });

    r.post('/tasks/{id}/checklist/{itemId}/move', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final items = _maps(t['checklist']);
      final index = items.indexWhere((c) => c['id'] == req.params['itemId']);
      if (index < 0) return notFound('Không tìm thấy việc con.');
      final moved = items.removeAt(index);
      final after = _s(req.json['after_id']);
      final at = after == null
          ? 0
          : items.indexWhere((c) => c['id'] == after) + 1;
      items.insert(at.clamp(0, items.length), moved);
      t['checklist'] = items;
      _touch(t);
      return ok(_present(t, detail: true));
    });
  }

  void _registerTaskExtras(DemoRoutes r) {
    // ── Bình luận ──
    r.get('/tasks/{id}/comments', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      final newestFirst = _maps(
        t['comments'],
      ).reversed.map(_presentComment).toList();
      return paged(req, newestFirst);
    });

    r.post('/tasks/{id}/comments', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      final body = req.json;
      final text = _s(body['body']) ?? '';
      // Multipart gộp khoá lặp: `files[]` / `mentioned_user_ids[]` chỉ còn
      // giá trị cuối — đủ cho bản demo.
      final files = _strs(body['files[]'] ?? body['files']);
      if (text.isEmpty && files.isEmpty) {
        return _invalid('body', 'Bình luận không được trống.');
      }
      final mentions = [
        for (final raw in _strs(
          body['mentioned_user_ids'] ?? body['mentioned_user_ids[]'],
        ))
          ?_userId(raw),
      ];
      t['comments'] = [
        ..._maps(t['comments']),
        {
          'id': demoNewId(),
          'body': text,
          'user_id': _me,
          'mentioned_user_ids': mentions,
          'created_at': _now(),
          'attachments': [
            for (final name in files)
              {
                'id': demoNewId(),
                'url': '',
                'name': name,
                'type': 'file',
                'user_id': _me,
              },
          ],
        },
      ];
      _touch(t);
      return created(_present(t, detail: true));
    });

    r.delete('/tasks/{id}/comments/{commentId}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      t['comments'] = _maps(t['comments'])
        ..removeWhere((c) => c['id'] == req.params['commentId']);
      return ok(_present(t, detail: true));
    });

    r.delete('/tasks/{id}/comments/{commentId}/attachments/{fileId}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      t['comments'] = [
        for (final c in _maps(t['comments']))
          if (c['id'] == req.params['commentId'])
            {
              ...c,
              'attachments': _maps(c['attachments'])
                ..removeWhere((a) => a['id'] == req.params['fileId']),
            }
          else
            c,
      ];
      return ok(_present(t, detail: true));
    });

    // ── Tệp đính kèm: chỉ giữ tên, không có URL ──
    r.post('/tasks/{id}/attachments', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      final name = _s(req.json['file']) ?? 'Tệp đính kèm';
      t['attachments'] = [
        ..._maps(t['attachments']),
        {
          'id': demoNewId(),
          'url': '',
          'name': name,
          'type': 'file',
          'user_id': _me,
          'created_at': _now(),
        },
      ];
      _log(t, 'attachment_added', name: name);
      _touch(t);
      return created(_present(t, detail: true));
    });

    r.delete('/tasks/{id}/attachments/{fileId}', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      if (t['locked'] == true) return _locked();
      t['attachments'] = _maps(t['attachments'])
        ..removeWhere((a) => a['id'] == req.params['fileId']);
      _log(t, 'attachment_removed');
      _touch(t);
      return ok(_present(t, detail: true));
    });

    // ── Thích / ghim / khoá / theo dõi ──
    r.post('/tasks/{id}/like', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      final likes = _strs(t['likes']);
      if (!likes.remove(_me)) likes.add(_me);
      t['likes'] = likes;
      return ok(_present(t, detail: true));
    });

    for (final flag in const ['pin', 'lock', 'follow']) {
      DemoResponse toggle(DemoRequest req, bool on) {
        final t = _task(req.params['id']);
        if (t == null) return notFound('Không tìm thấy công việc.');
        switch (flag) {
          case 'pin':
            if (t['locked'] == true) return _locked();
            t['pinned'] = on;
          case 'lock':
            t['locked'] = on;
          case 'follow':
            final ids = _strs(t['follower_ids'])..remove(_me);
            if (on) ids.add(_me);
            t['follower_ids'] = ids;
        }
        _touch(t);
        return ok(_present(t, detail: true));
      }

      r.post('/tasks/{id}/$flag', (req) => toggle(req, true));
      r.delete('/tasks/{id}/$flag', (req) => toggle(req, false));
    }

    // ── Lời nhắc ──
    r.get('/tasks/{id}/reminders', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      final rows =
          (_reminders[t['id']] ?? const [])
              .where(
                (x) => x['created_by'] == _me || x['audience'] == 'everyone',
              )
              .toList()
            ..sort(
              (a, b) => '${a['remind_at']}'.compareTo('${b['remind_at']}'),
            );
      return ok(rows);
    });

    r.post('/tasks/{id}/reminders', (req) {
      final t = _task(req.params['id']);
      if (t == null) return notFound('Không tìm thấy công việc.');
      final at = DateTime.tryParse(_s(req.json['remind_at']) ?? '');
      if (at == null || !at.isAfter(DateTime.now())) {
        return _invalid('remind_at', 'Giờ nhắc phải sau bây giờ.');
      }
      final list = _reminders.putIfAbsent(t['id'] as String, () => []);
      if (list.where((x) => x['status'] == 'pending').length >= 20) {
        return DemoResponse(422, {
          'success': false,
          'code': 'reminder_limit_reached',
          'message': 'Tối đa 20 lời nhắc đang chờ cho một việc.',
        });
      }
      final reminder = {
        'id': demoNewId(),
        'remind_at': at.toUtc().toIso8601String(),
        'audience': req.json['audience'] == 'everyone' ? 'everyone' : 'me',
        'status': 'pending',
        'sent_at': null,
        'created_by': _me,
        'created_by_name': demoMe.name,
      };
      list.add(reminder);
      return created(reminder);
    });

    r.delete('/tasks/{id}/reminders/{reminderId}', (req) {
      _reminders[req.params['id']]?.removeWhere(
        (x) => x['id'] == req.params['reminderId'],
      );
      return ok(null);
    });
  }

  void _registerProjects(DemoRoutes r) {
    r.get('/projects', (req) {
      final teamId = req.q('team_id');
      final search = req.q('search');
      final rows = [
        for (final p in _projects)
          if ((teamId == null || p['team_id'] == teamId) &&
              (search == null ||
                  foldDiacritics(
                    '${p['name']}',
                  ).contains(foldDiacritics(search))))
            _presentProject(p),
      ];
      return paged(req, rows, defaultPerPage: 30);
    });

    r.post('/projects', (req) {
      final body = req.json;
      final name = _s(body['name']);
      if (name == null) {
        return _invalid('name', 'Tên kế hoạch không được trống.');
      }
      final teamId = _s(body['team_id']);
      if (teamId != null && _team(teamId) == null) {
        return _invalid('team_id', 'Team không tồn tại.');
      }
      final now = _now();
      final project = <String, dynamic>{
        'id': demoNewId(),
        'name': name,
        'description': _s(body['description']),
        'color': _s(body['color']) ?? '#0A7D76',
        'cover': _s(body['cover']),
        'status': 'active',
        'team_id': teamId,
        'owner_id': _me,
        'sections': _maps(body['sections']),
        'member_ids': [_me],
        'member_roles': <String, dynamic>{},
        'custom_fields': <Map<String, dynamic>>[],
        'is_template': false,
        'default_points': 0,
        'start_date': null,
        'end_date': null,
        'tenant_id': demoTenantId,
        'created_by': _me,
        'created_at': now,
        'updated_at': now,
      };
      // Kế hoạch mới đứng đầu danh sách, như API (mới nhất trước).
      _projects.insert(0, project);
      return created(_presentProject(project));
    });

    r.get('/projects/{id}', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      return ok(_presentProject(p));
    });

    r.put('/projects/{id}', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      final body = req.json;
      if (body.containsKey('name')) {
        final name = _s(body['name']);
        if (name == null) {
          return _invalid('name', 'Tên kế hoạch không được trống.');
        }
        p['name'] = name;
      }
      for (final key in const [
        'description',
        'cover',
        'color',
        'start_date',
        'end_date',
      ]) {
        if (body.containsKey(key)) p[key] = _s(body[key]);
      }
      if (body.containsKey('team_id')) {
        final teamId = _s(body['team_id']);
        if (teamId != null && _team(teamId) == null) {
          return _invalid('team_id', 'Team không tồn tại.');
        }
        p['team_id'] = teamId;
      }
      if (body.containsKey('status')) {
        p['status'] = switch (_s(body['status'])) {
          'done' => 'done',
          'archived' => 'archived',
          _ => 'active',
        };
      }
      if (body.containsKey('member_ids')) {
        p['member_ids'] = [
          for (final raw in _strs(body['member_ids'])) ?_userId(raw),
        ];
      }
      if (body.containsKey('member_roles')) {
        final roles = body['member_roles'];
        p['member_roles'] = roles is Map
            ? {for (final e in roles.entries) ?_userId(e.key): '${e.value}'}
            : <String, dynamic>{};
      }
      if (body.containsKey('custom_fields')) {
        p['custom_fields'] = _maps(body['custom_fields']);
      }
      if (body.containsKey('sections')) p['sections'] = _maps(body['sections']);
      p['updated_at'] = _now();
      return ok(_presentProject(p));
    });

    r.delete('/projects/{id}', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      _projects.remove(p);
      _favorites.remove(p['id']);
      _tasks.removeWhere((t) => t['project_id'] == p['id']);
      return ok(null);
    });

    r.post('/projects/{id}/copy', (req) {
      final source = _project(req.params['id']);
      if (source == null) return notFound('Không tìm thấy kế hoạch.');
      final body = req.json;
      final name = _s(body['name']);
      if (name == null) {
        return _invalid('name', 'Tên kế hoạch không được trống.');
      }
      final now = _now();
      final copy = <String, dynamic>{
        ...source,
        'id': demoNewId(),
        'name': name,
        'owner_id': _me,
        'is_template': body['as_template'] == true,
        'start_date': _s(body['start_date']) ?? source['start_date'],
        'sections': _maps(source['sections']),
        'member_ids': [..._strs(source['member_ids'])],
        'member_roles': Map<String, dynamic>.from(
          (source['member_roles'] as Map?) ?? const {},
        ),
        'custom_fields': _maps(source['custom_fields']),
        'created_by': _me,
        'created_at': now,
        'updated_at': now,
      };
      if (!_strs(copy['member_ids']).contains(_me)) {
        copy['member_ids'] = [..._strs(copy['member_ids']), _me];
      }
      _projects.insert(0, copy);
      if (body['copy_tasks'] != false) {
        final originals = _tasks
            .where(
              (t) => t['project_id'] == source['id'] && t['archived'] != true,
            )
            .toList();
        for (final t in originals) {
          _newTask(
            title: '${t['title']}',
            projectId: copy['id'] as String,
            sectionId: _s(t['section_id']),
            order: (t['order'] as num?)?.toDouble(),
            assignees: _strs(t['assignee_ids']),
            due: _s(t['due_date']),
            start: _s(t['start_date']),
            priority: _priority(t['priority']),
            description: _s(t['description']),
            labels: _strs(t['labels']),
            customerName: _s(t['customer_name']),
            customFields: Map<String, dynamic>.from(
              (t['custom_fields'] as Map?) ?? const {},
            ),
            checklist: [
              for (final c in _maps(t['checklist']))
                {...c, 'id': demoNewId(), 'done': false},
            ],
          );
        }
      }
      return created(_presentProject(copy));
    });

    r.post('/projects/{id}/favorite', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      _favorites.add(p['id'] as String);
      return ok({'is_favorite': true});
    });

    r.delete('/projects/{id}/favorite', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      _favorites.remove(p['id']);
      return ok({'is_favorite': false});
    });

    r.post('/projects/{id}/transfer-owner', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      final newOwner = _userId(req.json['owner_id']);
      if (newOwner == null) {
        return _invalid('owner_id', 'Chủ mới phải là thành viên đang làm.');
      }
      final previous = _s(p['owner_id']);
      final role = switch (_s(req.json['previous_owner_role'])) {
        'member' => 'member',
        'viewer' => 'viewer',
        _ => 'manager',
      };
      final roles = Map<String, dynamic>.from(
        (p['member_roles'] as Map?) ?? const {},
      )..remove(newOwner);
      final members = _strs(p['member_ids']);
      if (!members.contains(newOwner)) members.add(newOwner);
      if (previous != null && previous != newOwner) {
        roles[previous] = role;
        if (!members.contains(previous)) members.add(previous);
      }
      p
        ..['owner_id'] = newOwner
        ..['member_roles'] = roles
        ..['member_ids'] = members
        ..['updated_at'] = _now();
      return ok(_presentProject(p));
    });

    // Ảnh nền: bản demo không lưu ảnh nào — đổi sang một nền gradient có sẵn
    // để người thử vẫn thấy thay đổi.
    r.post('/projects/{id}/cover', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      const covers = ['plum-1', 'moss-1', 'amber-2', 'teal-2', 'indigo-1'];
      p['cover'] = covers[_coverTurn++ % covers.length];
      p['updated_at'] = _now();
      return ok(_presentProject(p));
    });

    r.delete('/projects/{id}/cover', (req) {
      final p = _project(req.params['id']);
      if (p == null) return notFound('Không tìm thấy kế hoạch.');
      p['cover'] = null;
      p['updated_at'] = _now();
      return ok(_presentProject(p));
    });
  }

  void _registerTeams(DemoRoutes r) {
    r.get('/teams', (req) {
      final search = req.q('search');
      final rows = [
        for (final t in _teams)
          if (search == null ||
              foldDiacritics('${t['name']}').contains(foldDiacritics(search)))
            t,
      ];
      return paged(req, rows, defaultPerPage: 30);
    });

    r.post('/teams', (req) {
      final body = req.json;
      final name = _s(body['name']);
      if (name == null) return _invalid('name', 'Tên team không được trống.');
      final members = <String>[
        for (final raw in _strs(body['member_ids'])) ?_userId(raw),
      ];
      if (!members.contains(_me)) members.insert(0, _me);
      final now = _now();
      final team = <String, dynamic>{
        'id': demoNewId(),
        'name': name,
        'description': _s(body['description']),
        'color': '#0E7490',
        'member_ids': members,
        'archived': false,
        'org_unit_type': 'team',
        'leader_user_id': _me,
        'use_sales': false,
        'use_inbox': false,
        'leader_scope': false,
        'created_at': now,
        'updated_at': now,
      };
      _teams.add(team);
      return created(team);
    });

    r.put('/teams/{id}', (req) {
      final team = _team(req.params['id']);
      if (team == null) return notFound('Không tìm thấy team.');
      final body = req.json;
      if (body.containsKey('name')) {
        final name = _s(body['name']);
        if (name == null) return _invalid('name', 'Tên team không được trống.');
        team['name'] = name;
      }
      if (body.containsKey('description')) {
        team['description'] = _s(body['description']);
      }
      if (body.containsKey('member_ids')) {
        team['member_ids'] = [
          for (final raw in _strs(body['member_ids'])) ?_userId(raw),
        ];
      }
      team['updated_at'] = _now();
      return ok(team);
    });

    r.delete('/teams/{id}', (req) {
      final team = _team(req.params['id']);
      if (team == null) return notFound('Không tìm thấy team.');
      if (_projects.any((p) => p['team_id'] == team['id'])) {
        return const DemoResponse(409, {
          'success': false,
          'message': 'Team còn kế hoạch. Chuyển hoặc xoá các kế hoạch trước.',
        });
      }
      _teams.remove(team);
      return ok(null);
    });
  }

  void _registerPeople(DemoRoutes r) {
    r.get('/memberships', (req) {
      final search = req.q('search');
      final rows = [
        for (final p in demoPeople)
          if (search == null ||
              foldDiacritics(
                '${p.name} ${p.email} ${p.phone}',
              ).contains(foldDiacritics(search)))
            _membership(p),
      ];
      return paged(req, rows);
    });

    r.get('/memberships/{id}', (req) {
      final p = demoPersonById(req.params['id']);
      return p == null ? notFound() : ok(_membership(p));
    });

    r.put('/memberships/{id}', (req) {
      final p = demoPersonById(req.params['id']);
      if (p == null) return notFound('Không tìm thấy thành viên.');
      if (req.json.containsKey('zalo_user_id')) {
        final zalo = _s(req.json['zalo_user_id']);
        if (zalo == null) {
          _zalo.remove(p.membershipId);
        } else {
          _zalo[p.membershipId] = zalo;
        }
      }
      return ok(_membership(p));
    });

    r.get('/identity/users', (req) {
      final ids = _csv(req.q('ids')).toSet();
      final rows = [
        for (final p in demoPeople)
          if (ids.isEmpty || ids.contains(p.id)) _user(p),
      ];
      return paged(req, rows);
    });

    r.get('/identity/users/{id}', (req) {
      final p = demoPersonById(req.params['id']);
      return p == null ? notFound() : ok(_user(p));
    });
  }

  void _registerLabels(DemoRoutes r) {
    // Đường tĩnh trước mọi `/system-options/{id}` (kể cả của module khác).
    r.get(
      '/system-options/task-labels',
      (_) => ok([
        for (final l in _labels)
          if (l['is_active'] == true)
            {
              'code': l['code'],
              'label': l['label'],
              'color': l['color'],
              'sort_order': l['sort_order'],
            },
      ]),
    );

    r.get('/system-options', (req) {
      final group = req.q('group_key');
      if (group == null) {
        return _invalid('group_key', 'Thiếu nhóm danh mục.');
      }
      if (group != 'TASK_LABEL') return ok(const <Object>[]);
      final activeOnly = _bool(req.q('active_only'));
      return ok([
        for (final l in _labels)
          if (!activeOnly || l['is_active'] == true) l,
      ]);
    });

    r.post('/system-options', (req) {
      final body = req.json;
      if (_s(body['group_key']) != 'TASK_LABEL') {
        return _invalid('group_key', 'Bản demo chỉ có danh mục nhãn việc.');
      }
      final label = _s(body['label']);
      if (label == null) return _invalid('label', 'Tên nhãn không được trống.');
      final now = _now();
      final row = <String, dynamic>{
        'id': demoNewId(),
        'tenant_id': demoTenantId,
        'group_key': 'TASK_LABEL',
        'code': _s(body['code']) ?? demoNewId(),
        'label': label,
        'color': _s(body['color']),
        'icon': null,
        'sort_order': _labels.length + 1,
        'is_default': false,
        'is_system': false,
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      };
      _labels.add(row);
      return created(row);
    });

    r.put('/system-options/{id}', (req) {
      Map<String, dynamic>? row;
      for (final l in _labels) {
        if (l['id'] == req.params['id']) row = l;
      }
      if (row == null) return notFound('Không tìm thấy nhãn.');
      final body = req.json;
      if (body.containsKey('label')) {
        final label = _s(body['label']);
        if (label == null) {
          return _invalid('label', 'Tên nhãn không được trống.');
        }
        row['label'] = label;
      }
      if (body.containsKey('color')) row['color'] = _s(body['color']);
      if (body.containsKey('is_active')) {
        row['is_active'] = _bool(body['is_active']);
      }
      row['updated_at'] = _now();
      return ok(row);
    });
  }
}
