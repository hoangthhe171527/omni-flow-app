import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/module/customer_opportunities_section.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/presentation/customer_opportunities_section.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer_activity.dart';
import 'package:omni_app/modules/customers/presentation/customer_detail_page.dart';
import 'package:omni_app/modules/customers/presentation/widgets/customer_activity_list.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

/// ApiClient giả: một "máy chủ" nhỏ giữ hồ sơ `c1`, nhận PUT và ghi lại đúng
/// khoá đã gửi (lớp lỗi "ghi bị nuốt lặng" — khoá sai thì giá trị không đổi).
class _FakeServer extends ApiClient {
  _FakeServer() : super(Dio());

  Map<String, dynamic> customer = {
    'id': 'c1',
    'display_name': 'Chú Đức',
    'primary_contact_phone': '0900000000',
    'primary_contact_email': 'a@b.vn',
    'address': '12 Lê Thánh Tôn',
    'assigned_sales_rep_id': 'u-1',
    'assigned_sales_rep_name': 'Hoàng Trần',
    'created_at': '2026-03-05T03:00:00Z',
    'metadata': {
      'source': 'zalo',
      'tags': ['Hợp đồng'],
      'notes': 'cũ',
      'note': 'cũ',
    },
  };
  final names = {'u-1': 'Hoàng Trần', 'u-2': 'Lan'};
  final puts = <({String path, Map<String, dynamic> body})>[];
  final gets = <String>[];
  AppException? putError;
  AppException? summaryError;
  AppException? activityError;
  AppException? opportunitiesError;
  List<Map<String, dynamic>> opportunities = [
    {
      'id': 'o1',
      'title': 'Gói spa 12 buổi',
      'opportunity_stage': 'quoted',
      'opportunity_status': 'OPEN',
      'customer_id': 'c1',
      'estimated_budget': 5000000,
    },
    {
      'id': 'o2',
      'title': 'Đã chốt',
      'opportunity_stage': 'won',
      'opportunity_status': 'WON',
      'customer_id': 'c1',
      'estimated_budget': 9000000,
    },
  ];

  int count(String path) => gets.where((p) => p == path).length;

  @override
  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    gets.add(path);
    Object? data;
    switch (path) {
      case '/customers/c1':
        data = customer;
      case '/customers/c1/summary':
        if (summaryError != null) throw summaryError!;
        data = {
          'orders': {'count': 4, 'total_amount': 186000000},
          'opportunities_count': 2,
        };
      case '/interaction-logs':
        if (activityError != null) throw activityError!;
        data = [
          {
            'id': 'a1',
            'interaction_type': 'CALL',
            'content': 'Gọi tư vấn gói spa',
            'interacted_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
          },
        ];
      case '/sales-opportunities':
        if (opportunitiesError != null) throw opportunitiesError!;
        data = opportunities;
      case '/sales-opportunities/pipelines':
        throw const NotFoundException('none');
      default:
        data = <Object>[];
    }
    return ApiEnvelope({'success': true, 'data': data});
  }

  @override
  Future<ApiEnvelope> put(String path, {Object? body}) async {
    final map = (body as Map).cast<String, dynamic>();
    puts.add((path: path, body: map));
    if (putError != null) throw putError!;
    // Máy chủ giả: chuẩn hoá số điện thoại, gộp nông metadata, bỏ gán xoá tên.
    for (final e in map.entries) {
      switch (e.key) {
        case 'primary_contact_phone':
          customer[e.key] = (e.value as String).replaceAll(' ', '');
        case 'assigned_sales_rep_id':
          customer[e.key] = e.value;
          customer['assigned_sales_rep_name'] = names[e.value];
        case 'metadata':
          final meta = Map<String, dynamic>.of(
            (customer['metadata'] as Map).cast<String, dynamic>(),
          )..addAll((e.value as Map).cast<String, dynamic>());
          customer['metadata'] = meta;
        default:
          customer[e.key] = e.value;
      }
    }
    return ApiEnvelope({'success': true, 'data': customer});
  }
}

const _members = [
  TeamMember(membershipId: 'm-1', userId: 'u-1', name: 'Hoàng Trần'),
  TeamMember(membershipId: 'm-2', userId: 'u-2', name: 'Lan'),
];

const _read = 'crm.customers.read';
const _readOwn = 'crm.customers.read.own';
const _update = 'crm.customers.update';
const _logs = 'crm.interaction_logs.read';
const _oppRead = 'crm.sales_opportunities.read';
const _oppCreate = 'crm.sales_opportunities.create';
const _tasks = 'tasks.write';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeServer server;
  late GoRouter router;

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Chớp xanh của dòng sửa dùng một Timer 700ms.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester, {
    Set<String> permissions = const {_read, _update, _logs, _oppRead},
    Map<String, bool> features = const {},
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = server;
    router = GoRouter(
      initialLocation: '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (_, _) => const Scaffold(body: Text('LIST')),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (_, state) =>
              CustomerDetailPage(customerId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          customersApiProvider.overrideWithValue(CustomersApi(client)),
          opportunitiesApiProvider.overrideWithValue(OpportunitiesApi(client)),
          teamMembersProvider.overrideWith((ref) async => _members),
          backgroundProvider.overrideWith(FixedBackground.new),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: const SessionUser(
                id: 'u-1',
                fullName: 'Hoàng Trần',
                email: 'h@x.vn',
              ),
              policy: AccessPolicy(permissions),
              features: features,
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: theme ?? OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/customers/c1');
    await tester.pumpAndSettle();
  }

  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  final launched = <String>[];

  setUp(() {
    server = _FakeServer();
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          launched.add((call.arguments as Map)['url'] as String);
          return false;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null),
  );

  group('bố cục', () {
    testWidgets('không có chữ Sửa; có Tổng quan và nút ‹ Khách hàng', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Sửa'), findsNothing);
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Khách hàng'), findsOneWidget);
      expect(find.text('Chú Đức'), findsOneWidget);
      expect(find.textContaining('Khách từ 03/2026'), findsOneWidget);
    });

    testWidgets('dải số lấy từ summary máy chủ, ô Đang mở cộng cơ hội mở', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Đã mua'), findsOneWidget);
      expect(find.text('186 tr'), findsOneWidget);
      expect(find.text('Đơn hàng'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Đang mở'), findsOneWidget);
      // Chỉ cơ hội còn mở: 5 tr, không cộng cơ hội đã thắng 9 tr.
      expect(find.text('5 tr'), findsOneWidget);
      expect(find.text('Cơ hội · 2'), findsOneWidget);
    });

    testWidgets('summary ném 403 → không dải số, trang vẫn hiện', (
      tester,
    ) async {
      server.summaryError = const ForbiddenException('no');
      await open(tester);
      expect(find.text('Đã mua'), findsNothing);
      expect(find.text('Đơn hàng'), findsNothing);
      expect(find.text('Chú Đức'), findsOneWidget);
      expect(find.text('0900000000'), findsOneWidget);
    });

    testWidgets('cờ cơ hội tắt → không tab, không nút, không ô Đang mở', (
      tester,
    ) async {
      await open(
        tester,
        permissions: {_read, _update, _logs, _oppRead, _oppCreate, _tasks},
        features: const {'opportunities': false},
      );
      expect(find.textContaining('Cơ hội'), findsNothing);
      expect(find.text('Đang mở'), findsNothing);
      expect(server.count('/sales-opportunities'), 0);
    });

    testWidgets('thiếu quyền đọc cơ hội → không tab, không gọi API cơ hội', (
      tester,
    ) async {
      await open(tester, permissions: {_read, _update, _logs});
      expect(find.textContaining('Cơ hội'), findsNothing);
      expect(find.text('Đang mở'), findsNothing);
      expect(server.count('/sales-opportunities'), 0);
    });

    testWidgets('thiếu quyền nhật ký → không tab Hoạt động, không gọi API', (
      tester,
    ) async {
      await open(tester, permissions: {_read, _update, _oppRead});
      expect(find.text('Hoạt động'), findsNothing);
      expect(server.count('/interaction-logs'), 0);
    });

    testWidgets('bốn nút theo quyền: Nhắn, Gọi luôn; Việc, Cơ hội khi có', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Nhắn'), findsOneWidget);
      expect(find.text('Gọi'), findsOneWidget);
      expect(find.text('Việc'), findsNothing);
      expect(find.text('Cơ hội'), findsNothing);
    });

    testWidgets('đủ quyền → có Việc và Cơ hội', (tester) async {
      await open(
        tester,
        permissions: {_read, _update, _logs, _oppRead, _oppCreate, _tasks},
      );
      expect(find.text('Việc'), findsOneWidget);
      expect(find.text('Cơ hội'), findsOneWidget);
    });

    testWidgets('Gọi không mở được → SnackBar báo lỗi', (tester) async {
      await open(tester);
      await tester.tap(find.text('Gọi'));
      await tester.pumpAndSettle();
      expect(launched, ['tel:0900000000']);
      expect(find.text('Không mở được ứng dụng gọi điện.'), findsOneWidget);
    });

    testWidgets('chạm số điện thoại khi không sửa được → gọi', (tester) async {
      await open(tester, permissions: {_read});
      await tester.tap(find.text('0900000000'));
      await tester.pumpAndSettle();
      expect(find.text('Không mở được ứng dụng gọi điện.'), findsOneWidget);
    });

    testWidgets('chạm email khi không sửa được → mailto', (tester) async {
      await open(tester, permissions: {_read});
      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      expect(find.text('Không mở được ứng dụng email.'), findsOneWidget);
    });
  });

  group('tab', () {
    testWidgets('Hoạt động: dòng thời gian; lỗi hiện tại chỗ', (tester) async {
      await open(tester);
      await tester.tap(find.text('Hoạt động'));
      await tester.pumpAndSettle();
      expect(find.text('Gọi tư vấn gói spa'), findsOneWidget);
      expect(find.text('3 ngày'), findsOneWidget);
    });

    testWidgets('Hoạt động lỗi → câu báo + Thử lại, trang không sập', (
      tester,
    ) async {
      server.activityError = const NetworkException('mất mạng');
      await open(tester);
      await tester.tap(find.text('Hoạt động'));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được hoạt động.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Chú Đức'), findsOneWidget);
    });

    testWidgets('CustomerActivityList rỗng → Chưa có hoạt động', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const Scaffold(body: CustomerActivityList(items: [])),
        ),
      );
      expect(find.text('Chưa có hoạt động'), findsOneWidget);
    });

    testWidgets('CustomerActivityList giảm chuyển động → hiện thẳng', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: CustomerActivityList(
                items: [
                  for (final k in ActivityKind.values)
                    CustomerActivity(
                      id: k.name,
                      kind: k,
                      text: 'dòng ${k.name}',
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('dòng message'), findsOneWidget);
      expect(find.text('dòng other'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('Cơ hội: danh sách dòng cơ hội của khách', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cơ hội · 2'));
      await tester.pumpAndSettle();
      expect(find.text('Gói spa 12 buổi'), findsOneWidget);
      expect(find.text('Đã chốt'), findsOneWidget);
    });

    testWidgets('Cơ hội rỗng → Chưa có cơ hội + Tạo cơ hội khi được tạo', (
      tester,
    ) async {
      server.opportunities = [];
      await open(
        tester,
        permissions: {_read, _update, _logs, _oppRead, _oppCreate},
      );
      await tester.tap(find.text('Cơ hội · 0'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có cơ hội'), findsOneWidget);
      expect(find.text('Tạo cơ hội'), findsOneWidget);
    });

    testWidgets(
      'Cơ hội lỗi → coi như rỗng, không sập, không nút khi thiếu quyền tạo',
      (tester) async {
        server.opportunitiesError = const NetworkException('mất mạng');
        await open(tester);
        await tester.tap(find.text('Cơ hội · 2'));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có cơ hội'), findsOneWidget);
        expect(find.text('Tạo cơ hội'), findsNothing);
        expect(find.text('Chú Đức'), findsOneWidget);
      },
    );
  });

  group('sửa tại chỗ', () {
    testWidgets('Điện thoại → primary_contact_phone, hiện giá trị chuẩn hoá', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('0900000000'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0901 000 001');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(server.puts, hasLength(1));
      expect(server.puts.single.path, '/customers/c1');
      expect(server.puts.single.body, {
        'primary_contact_phone': '0901 000 001',
      });
      expect(find.text('0901000001'), findsOneWidget);
    });

    testWidgets('Email → primary_contact_email', (tester) async {
      await open(tester);
      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'moi@b.vn');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(server.puts.single.body, {'primary_contact_email': 'moi@b.vn'});
      expect(find.text('moi@b.vn'), findsOneWidget);
    });

    testWidgets('Địa chỉ → address', (tester) async {
      await open(tester);
      await tester.tap(find.text('12 Lê Thánh Tôn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5 Nguyễn Huệ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(server.puts.single.body, {'address': '5 Nguyễn Huệ'});
      expect(find.text('5 Nguyễn Huệ'), findsOneWidget);
    });

    testWidgets('Ghi chú → metadata {notes, note}; lưu bằng nút ✓', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('cũ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mới');
      await tester.tap(find.byIcon(Icons.check));
      await settle(tester);

      expect(server.puts.single.body, {
        'metadata': {'notes': 'mới', 'note': 'mới'},
      });
      expect(find.text('mới'), findsOneWidget);
    });

    testWidgets('Phụ trách chọn Lan → assigned_sales_rep_id u-2', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Hoàng Trần'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lan'));
      await settle(tester);

      expect(server.puts.single.body, {'assigned_sales_rep_id': 'u-2'});
      expect(find.text('Lan'), findsOneWidget);
    });

    testWidgets('Bỏ gán → khoá có mặt, giá trị null, hiện Chưa gán', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Hoàng Trần'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ gán'));
      await settle(tester);

      final body = server.puts.single.body;
      expect(body.containsKey('assigned_sales_rep_id'), isTrue);
      expect(body['assigned_sales_rep_id'], isNull);
      expect(find.text('Chưa gán'), findsOneWidget);
    });

    testWidgets('khách chỉ có tên người phụ trách vẫn Bỏ gán được', (
      tester,
    ) async {
      server.customer
        ..remove('assigned_sales_rep_id')
        ..['assigned_sales_rep_name'] = 'Cũ'
        ..['metadata'] = {
          'source': 'zalo',
          'owner_name': 'Cũ',
          'tags': ['Hợp đồng'],
        };
      await open(tester);
      await tester.tap(find.text('Cũ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ gán'));
      await settle(tester);

      final body = server.puts.single.body;
      expect(body.containsKey('assigned_sales_rep_id'), isTrue);
      expect(body['assigned_sales_rep_id'], isNull);
      expect((body['metadata'] as Map)['owner_name'], isNull);
      expect(find.text('Chưa gán'), findsOneWidget);
    });

    testWidgets('Nhãn → metadata.tags đầy đủ', (tester) async {
      await open(tester);
      await tester.tap(find.text('Hợp đồng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo giá'));
      await tester.tap(find.text('Xong'));
      await settle(tester);

      expect(server.puts.single.body, {
        'metadata': {
          'tags': ['Hợp đồng', 'Báo giá'],
        },
      });
      expect(find.text('Báo giá'), findsOneWidget);
    });

    testWidgets('lưu xong tải lại summary (dải số theo máy chủ)', (
      tester,
    ) async {
      await open(tester);
      final before = server.count('/customers/c1/summary');
      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'moi@b.vn');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(server.count('/customers/c1/summary'), greaterThan(before));
      expect(server.count('/customers/c1'), greaterThan(1));
    });

    testWidgets('chỉ một dòng sửa tại một thời điểm', (tester) async {
      await open(tester);
      await tester.tap(find.text('0900000000'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'a@b.vn',
      );
    });

    testWidgets('API 422 → lỗi dưới ô, giá trị cũ còn nguyên', (tester) async {
      server.putError = const ValidationException(
        'Email không hợp lệ.',
        errors: {
          'primary_contact_email': ['Email không hợp lệ.'],
        },
      );
      await open(tester);
      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sai');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Email không hợp lệ.'), findsOneWidget);
      expect(server.customer['primary_contact_email'], 'a@b.vn');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('a@b.vn'), findsOneWidget);
    });

    testWidgets('picker lỗi → SnackBar Không lưu được.', (tester) async {
      server.putError = const NetworkException('mất mạng');
      await open(tester);
      await tester.tap(find.text('Hoàng Trần'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lan'));
      await tester.pumpAndSettle();
      expect(find.text('Không lưu được.'), findsOneWidget);
      expect(find.text('Hoàng Trần'), findsOneWidget);
    });
  });

  group('quyền sửa', () {
    testWidgets('không canUpdate → không bút chì, không ô sửa, không sheet', (
      tester,
    ) async {
      await open(tester, permissions: {_read, _logs, _oppRead});
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.text('12 Lê Thánh Tôn'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Hoàng Trần'));
      await tester.pumpAndSettle();
      expect(find.text('Tìm người'), findsNothing);

      await tester.tap(find.text('Hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.text('Xong'), findsNothing);
      expect(server.puts, isEmpty);
    });

    testWidgets('canUpdate → có bút chì ở mỗi dòng', (tester) async {
      await open(tester);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(6));
    });
  });

  group('phạm vi own', () {
    testWidgets(
      'giao khách cho người khác → trang đóng, SnackBar, về danh sách',
      (tester) async {
        await open(tester, permissions: {_readOwn, _update});
        await tester.tap(find.text('Hoàng Trần'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lan'));
        await settle(tester);

        expect(server.puts.single.body, {'assigned_sales_rep_id': 'u-2'});
        expect(find.text('LIST'), findsOneWidget);
        expect(find.text('Đã giao khách cho Lan.'), findsOneWidget);
      },
    );

    testWidgets('own nhưng vẫn là mình → ở lại trang', (tester) async {
      await open(tester, permissions: {_readOwn, _update});
      await tester.tap(find.text('a@b.vn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'moi@b.vn');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('LIST'), findsNothing);
      expect(find.text('moi@b.vn'), findsOneWidget);
    });
  });

  group('làm mới', () {
    testWidgets('kéo để làm mới tải lại hồ sơ, summary, nhật ký, cơ hội', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Hoạt động'));
      await tester.pumpAndSettle();
      final before = {
        for (final p in [
          '/customers/c1',
          '/customers/c1/summary',
          '/interaction-logs',
          '/sales-opportunities',
        ])
          p: server.count(p),
      };

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1500,
      );
      await tester.pumpAndSettle();

      for (final entry in before.entries) {
        expect(
          server.count(entry.key),
          greaterThan(entry.value),
          reason: entry.key,
        );
      }
    });
  });

  group('chế độ tối', () {
    testWidgets('dựng không lỗi; dòng nguồn đủ tương phản 4.5', (tester) async {
      await open(tester, theme: OmniTheme.dark(TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final finder = find.byKey(const ValueKey('customer-source-line'));
      expect(finder, findsOneWidget);
      final context = tester.element(finder);
      final bg = Theme.of(context).scaffoldBackgroundColor;
      final text = tester.widget<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)).first,
      );
      final span = text.text as TextSpan;
      final colors = <Color>[
        for (final s in span.children!.cast<TextSpan>())
          s.style?.color ?? span.style!.color!,
      ];
      expect(colors, isNotEmpty);
      for (final c in colors) {
        expect(contrastRatio(c, bg), greaterThanOrEqualTo(4.5));
      }
    });
  });
}
