// Ảnh chụp màn THẬT cho "Đơn hàng theo cây" Đợt 3 app — soát bằng mắt so với
// bản mẫu 7LZPEX, không phải bài kiểm hồi quy (tag `screenshots`, bị bỏ qua
// mặc định). Chạy tay:
//
//   flutter test test/_screenshots/don_hang_theo_cay_golden_test.dart \
//     --run-skipped --update-goldens
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/order_units.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/domain/order_list.dart';
import 'package:omni_app/modules/inventory/presentation/order_units_page.dart';
import 'package:omni_app/modules/inventory/presentation/orders_page.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/record_payment_sheet.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/board_unit.dart';
import 'package:omni_app/modules/plans/presentation/widgets/add_task_sheet.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/issue_widgets.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

const _perms = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

Future<void> _loadAppFont() async {
  final loader = FontLoader('Be Vietnam Pro');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = File(
    'D:/_tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = icons.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await iconLoader.load();
  }
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);
  final TaskDetailState _state;
  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}

class _StubPlansApi implements PlansApi {
  @override
  Future<List<BoardUnit>> searchUnits(String q, {int limit = 20}) async => [
    BoardUnit.fromJson(const {
      'id': 'u1',
      'maker': 'YAMAHA',
      'model': 'U3H',
      'serial': '2810452',
      'lot_code': 'JP-2609',
      'workshop': [],
    }),
    BoardUnit.fromJson(const {
      'id': 'u2',
      'maker': 'YAMAHA',
      'model': 'U2H',
      'serial': '2455019',
      'lot_code': 'JP-2609',
      'customer_name': 'Lê Thu Hà',
      'workshop': [],
    }),
    BoardUnit.fromJson(const {
      'id': 'u3',
      'maker': 'YAMAHA',
      'model': 'W106',
      'serial': 'W3006104',
      'workshop': [
        {'role': 'refurbish', 'state': 'doing', 'section_name': 'Bộ phím'},
      ],
    }),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _w(String task, String section, int done, String who) => {
  'task_id': task,
  'section_name': section,
  'assignee_names': [who],
  'due_date': '2026-11-15',
  'state': 'doing',
  'done': done,
  'total': 10,
};

final _order = OrderUnits(
  code: 'DH-2611-014',
  customerName: 'Phạm Minh Đức',
  value: 303500000,
  paid: 100000000,
  units: [
    OrderUnit.fromJson({
      'id': '1',
      'label': 'KAWAI BL-71',
      'serial': '1452098',
      'bucket': 'issue',
      'work': _w('t1', 'Lên dây', 6, 'Bảo'),
      'issue': {
        'task_id': 't1',
        'note': 'Nứt bảng cộng hưởng góc trái',
        'by_name': 'Bảo',
        'photos': [],
      },
    }),
    OrderUnit.fromJson({
      'id': '2',
      'label': 'YAMAHA W106',
      'serial': 'W3006104',
      'bucket': 'in_shop',
      'work': _w('t2', 'Bộ phím', 8, 'Hoàng'),
    }),
    OrderUnit.fromJson(const {
      'id': '3',
      'label': 'YAMAHA U3H',
      'serial': '2810452',
      'bucket': 'ready',
      'location': 'Kho chính · Dãy B',
      'work': {'task_id': 't3', 'state': 'done', 'done': 10, 'total': 10},
    }),
    OrderUnit.fromJson(const {
      'id': '4',
      'label': 'YAMAHA U1H',
      'serial': '1873311',
      'bucket': 'not_in_shop',
      'condition': 'sealed',
      'lot_code': 'JP-2610',
    }),
    OrderUnit.fromJson(const {
      'id': '5',
      'label': 'KAWAI KS-2F',
      'serial': '2210744',
      'bucket': 'delivered',
      'delivered_at': '2026-11-05T09:00:00+07:00',
    }),
  ],
);

final _issueTask = Task.fromJson({
  'id': 't1',
  'title': 'KAWAI BL-71',
  'status': 'doing',
  'project_id': 'p1',
  'project_name': 'Xưởng tân trang T11',
  'section_id': 's2',
  'section_name': 'Lên dây',
  'assignee_ids': ['u-1'],
  'assignee_names': ['Bảo'],
  'subject': {'type': 'unit', 'id': 'unit-1', 'role': 'refurbish'},
  'unit': {
    'id': 'unit-1',
    'maker': 'KAWAI',
    'model': 'BL-71',
    'serial': '1452098',
    'lot_code': 'JP-2610',
    'condition': 'refurbishing',
    'customer_name': 'Phạm Minh Đức',
  },
  'issue': {
    'comment_id': 'c1',
    'note':
        'Nứt bảng cộng hưởng góc trái, cần anh Nguyên xem trước khi lên dây tiếp.',
    'photos': [],
    'by': 'u-2',
    'by_name': 'Bảo',
    'at': '2026-11-11T14:20:00+07:00',
  },
  'checklist': [
    {'id': 'c1', 'title': 'Chỉnh cơ', 'done': true},
    {'id': 'c2', 'title': 'Lên dây', 'done': false},
    {'id': 'c3', 'title': 'Đánh bóng', 'done': false},
  ],
  'comments': [
    {
      'id': 'k1',
      'body':
          'Nứt bảng cộng hưởng góc trái, cần anh Nguyên xem trước khi lên dây tiếp.',
      'kind': 'issue',
      'user_name': 'Bảo',
      'created_at': '2026-11-11T07:20:00Z',
    },
  ],
});

void main() {
  setUpAll(() async {
    await _loadAppFont();
    await initializeDateFormatting('vi_VN');
  });

  Widget app(Widget home, {List<Override> extra = const []}) => ProviderScope(
    overrides: [
      backgroundProvider.overrideWith(() => FixedBackground(null)),
      sessionProvider.overrideWithValue(
        const Session(
          status: SessionStatus.authenticated,
          user: SessionUser(id: 'u-1', fullName: 'Hằng Ni', email: 'h@x.vn'),
        ),
      ),
      taskAccessProvider.overrideWithValue(TaskAccess.of(AccessPolicy(_perms))),
      accessProvider.overrideWithValue(AccessPolicy(_perms)),
      ...extra,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: OmniTheme.light(TargetPlatform.iOS),
      locale: const Locale('vi'),
      home: home,
    ),
  );

  /// Màn đẩy vào (có nút quay lại) — như người dùng thật mở từ ngăn cây.
  Widget pushed(Widget page) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('mở'),
        ),
      ),
    ),
  );

  Future<void> shoot(
    WidgetTester t,
    Widget w,
    String name, {
    Future<void> Function()? act,
  }) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(w);
    await t.pumpAndSettle();
    if (act != null) await act();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dhtc-$name.png'),
    );
  }

  testWidgets(
    'chi tiet don',
    (t) => shoot(
      t,
      app(
        pushed(const OrderUnitsPage(orderId: 'o1')),
        extra: [orderUnitsProvider('o1').overrideWith((ref) async => _order)],
      ),
      'chi-tiet-don',
      act: () => t.tap(find.text('mở')),
    ),
  );

  testWidgets(
    'viec co van de',
    (t) => shoot(
      t,
      app(
        pushed(const TaskDetailPage(taskId: 't1')),
        extra: [
          taskDetailProvider.overrideWith(
            () => _StubDetail(TaskDetailState(task: _issueTask)),
          ),
        ],
      ),
      'viec-co-van-de',
      act: () => t.tap(find.text('mở')),
    ),
  );

  Widget opener(Future<void> Function(BuildContext) open) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('mở'),
        ),
      ),
    ),
  );

  testWidgets(
    'tam bao van de',
    (t) => shoot(
      t,
      app(opener((c) => showReportIssueSheet(c))),
      'bao-van-de',
      act: () async {
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const Key('issue-note')),
          'Nứt bảng cộng hưởng góc trái, cần anh Nguyên xem trước khi lên dây tiếp.',
        );
      },
    ),
  );

  testWidgets(
    'tam them viec - go ten',
    (t) => shoot(
      t,
      app(
        opener((c) => showAddTaskSheet(c, sectionName: 'Kiểm tra đầu vào')),
        extra: [canPickUnitsProvider.overrideWithValue(true)],
      ),
      'them-viec-go-ten',
      act: () => t.tap(find.text('mở')),
    ),
  );

  testWidgets(
    'tam them viec - chon dan',
    (t) => shoot(
      t,
      app(
        opener((c) => showAddTaskSheet(c, sectionName: 'Kiểm tra đầu vào')),
        extra: [
          canPickUnitsProvider.overrideWithValue(true),
          plansApiProvider.overrideWithValue(_StubPlansApi()),
        ],
      ),
      'them-viec-chon-dan',
      act: () async {
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        await t.tap(find.text('Chọn đàn'));
        await t.pumpAndSettle();
        await t.enterText(
          find.descendant(
            of: find.byKey(const Key('add-task-unit-search')),
            matching: find.byType(TextField),
          ),
          'yamaha',
        );
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('add-task-unit-u1')));
      },
    ),
  );

  testWidgets(
    'danh sach don',
    (t) => shoot(
      t,
      app(
        const OrdersPage(),
        extra: [
          inventoryPermsProvider.overrideWithValue(
            const InventoryPerms(read: true, sell: true, reserve: true),
          ),
          inventoryTodayProvider.overrideWithValue(DateTime(2026, 11, 12)),
          ordersDueProvider.overrideWith(
            (ref) async => (outstanding: 512000000.0, awaiting: 4),
          ),
          ordersListProvider.overrideWith(
            (ref, q) async => [for (final j in _orders) OrderRow.fromJson(j)],
          ),
        ],
      ),
      'danh-sach-don',
    ),
  );

  testWidgets(
    'ghi thu',
    (t) => shoot(
      t,
      app(
        opener(
          (c) => openRecordPaymentSheet(
            c,
            orderId: 'o1',
            orderCode: 'DH-2611-014',
            remaining: 203500000,
          ),
        ),
        extra: [
          inventoryTodayProvider.overrideWithValue(DateTime(2026, 11, 12)),
        ],
      ),
      'ghi-thu',
      act: () => t.tap(find.text('mở')),
    ),
  );
}

const _orders = [
  {
    'id': 'a',
    'code': 'DH-2611-014',
    'customer_name': 'Phạm Minh Đức',
    'product': '5 cây: KAWAI BL-71, YAMAHA W106…',
    'value': 303500000,
    'paid': 100000000,
    'pay_status': 'partial',
    'created_at': '2026-11-11T03:00:00Z',
  },
  {
    'id': 'b',
    'code': 'DH-2611-012',
    'customer_name': 'Lê Thu Hà',
    'product': '1 cây: YAMAHA U2H · 2455019',
    'value': 58000000,
    'paid': 0,
    'pay_status': 'unpaid',
    'created_at': '2026-11-10T03:00:00Z',
  },
  {
    'id': 'c',
    'code': 'DH-2611-010',
    'customer_name': 'Trường Mầm non Hoa Sen',
    'product': '3 cây',
    'value': 286000000,
    'paid': 100000000,
    'pay_status': 'partial',
    'created_at': '2026-11-10T03:00:00Z',
  },
  {
    'id': 'd',
    'code': 'DH-2610-087',
    'customer_name': 'Nguyễn Hoàng Long',
    'product': '2 cây',
    'value': 64500000,
    'paid': 0,
    'pay_status': 'unpaid',
    'created_at': '2026-10-28T03:00:00Z',
  },
];
