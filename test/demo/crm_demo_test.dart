import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/demo/demo_app.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/demo/demo_seed.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/domain/customer_field.dart';
import 'package:omni_app/modules/dashboard/data/dashboard_api.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';

/// Máy chủ demo của khách hàng / cơ hội / Tổng quan: đi qua đúng lớp API thật
/// của app (parse JSON y như với máy chủ thật), nên lệch tên khoá hay hình
/// envelope là đỏ ở đây chứ không phải màn trắng trên máy người kiểm thử.
void main() {
  late CustomersApi customers;
  late OpportunitiesApi opportunities;
  late DashboardApi dashboard;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(
        buildDemoRoutes(),
        latency: Duration.zero,
      );
    final client = ApiClient(dio);
    customers = CustomersApi(client);
    opportunities = OpportunitiesApi(client);
    dashboard = DashboardApi(client);
  });

  group('khách hàng — đọc', () {
    test('danh sách có dữ liệu và phân trang', () async {
      final page = await customers.list(perPage: 10);
      expect(page.items, hasLength(10));
      expect(page.pagination.total, greaterThanOrEqualTo(15));
      expect(page.hasMore, isTrue);
      final next = await customers.list(page: 2, perPage: 10);
      expect(next.items, isNotEmpty);
      // Thứ tự theo `updated_at` tương đối với giờ chạy — khách đứng đầu có
      // thể là khách chưa giao ai, nên kiểm trên cả trang.
      expect(page.items.where((c) => c.ownerName != null), isNotEmpty);
    });

    test('tìm theo tên không dấu và theo số điện thoại', () async {
      final byName = await customers.list(query: {'search': 'hung'});
      expect(byName.items.map((c) => c.name), contains('Trần Văn Hùng'));
      final byPhone = await customers.list(query: {'search': '0900100005'});
      expect(byPhone.items.single.name, 'Lê Hoàng Nam');
    });

    test('lọc nhanh: VIP, ngưng hoạt động, của tôi, mới trong tháng', () async {
      final vip = await customers.list(query: {'customer_status': 'WARM'});
      expect(vip.items, isNotEmpty);
      expect(vip.items.every((c) => c.status == CustomerStatus.vip), isTrue);

      final inactive = await customers.list(
        query: {'customer_status': 'INACTIVE,AT_RISK,LOST'},
      );
      expect(inactive.items, hasLength(3));

      final mine = await customers.list(
        query: {'assigned_sales_rep_id': demoMeId},
      );
      expect(mine.items, isNotEmpty);
      expect(mine.items.every((c) => c.ownerId == demoMeId), isTrue);

      final fresh = await customers.list(query: {'tab': 'new_month'});
      expect(fresh.items, isNotEmpty);
    });

    test('hồ sơ, thẻ tổng hợp, nhật ký, kiểm tra trùng', () async {
      final first = (await customers.list(
        query: {'search': 'Khách sạn Phố Núi'},
      )).items.single;
      final detail = await customers.get(first.id);
      expect(detail.isBusiness, isTrue);
      expect(detail.legalName, startsWith('Công ty'));
      expect(detail.lifetimeValue, greaterThan(0));
      expect(detail.lastInteractionAt, isNotNull);

      final summary = await customers.summary(first.id);
      expect(summary.ordersCount, greaterThan(0));
      expect(summary.opportunitiesCount, 1);

      final activities = await customers.activities(first.id);
      expect(activities, hasLength(3));

      final dup = await customers.checkDuplicate(phone: detail.phone);
      expect(dup?.id, first.id);
      expect(await customers.checkDuplicate(phone: '0000000000'), isNull);
    });
  });

  group('cơ hội — đọc', () {
    test('quy trình từ máy chủ, đủ 6 giai đoạn', () async {
      final catalog = await opportunities.pipelines();
      expect(catalog.fromServer, isTrue);
      expect(catalog.defaultPipeline.stages, hasLength(6));
      expect(catalog.defaultPipeline.openStages, hasLength(4));
    });

    test('danh sách theo giai đoạn, trạng thái, của tôi, khách', () async {
      final all = await opportunities.list(pipeline: 'standard');
      expect(all.items.length, greaterThanOrEqualTo(10));
      expect(all.items.first.customerName, isNotNull);
      expect(all.items.first.ownerName, isNotNull);

      final quoted = await opportunities.list(stageCode: 'quoted');
      expect(quoted.items, isNotEmpty);
      expect(quoted.items.every((o) => o.stageCode == 'quoted'), isTrue);

      final open = await opportunities.list(status: 'OPEN');
      expect(open.items.every((o) => !o.isClosed), isTrue);
      final won = await opportunities.list(stageCode: 'won');
      expect(won.items.every((o) => o.isWon), isTrue);

      final mine = await opportunities.list(mine: true);
      expect(mine.items.every((o) => o.ownerId == demoMeId), isTrue);
      expect(mine.items, isNotEmpty);

      final search = await opportunities.list(search: 'sofa');
      expect(search.items.single.title, contains('Sofa'));

      final cust = all.items.first.customerId!;
      final ofCustomer = await opportunities.list(customerId: cust);
      expect(ofCustomer.items.every((o) => o.customerId == cust), isTrue);
    });

    test('tổng theo giai đoạn khớp danh sách', () async {
      final catalog = await opportunities.pipelines();
      final summary = await opportunities.summary(pipeline: 'standard');
      final quoted = await opportunities.list(stageCode: 'quoted');
      expect(summary.totalFor('quoted').count, quoted.items.length);
      expect(summary.openValue(catalog.defaultPipeline), greaterThan(0));
    });

    test('chi tiết có ghi chú và ngày chốt', () async {
      final row = (await opportunities.list(search: '20 phòng')).items.single;
      final detail = await opportunities.get(row.id);
      expect(detail.notes, hasLength(2));
      expect(detail.expectedCloseAt, isNotNull);
      expect(detail.value, 480000000);
    });
  });

  group('Tổng quan — doanh thu', () {
    for (final range in RevenueRange.values) {
      test('chuỗi ${range.name} parse được', () async {
        final series = await dashboard.revenueSeries(range);
        expect(series, isNotNull);
        expect(series!.current, isNotEmpty);
        expect(series.previous, isNotEmpty);
        expect(series.current.length, lessThanOrEqualTo(series.slots));
        expect(series.headline, greaterThan(0));
        expect(series.target, isNotNull);
      });
    }
  });

  group('ghi trong phiên', () {
    test('tạo khách → có trong danh sách; sửa; xoá', () async {
      final draft = Customer.blank().applyForm(
        name: 'Khách Thử Nghiệm',
        contactName: '',
        phone: '0900999888',
        email: 'thu@example.com',
        address: '1 Đường Thử, TP Hồ Chí Minh',
        source: Channel.zalo,
        status: CustomerStatus.active,
        note: 'Ghi chú thử',
      );
      final createdCustomer = await customers.create(draft);
      expect(createdCustomer.id, isNotEmpty);
      expect(createdCustomer.note, 'Ghi chú thử');

      final listed = await customers.list(query: {'search': 'thu nghiem'});
      expect(listed.items.single.id, createdCustomer.id);
      expect((await customers.list()).items.first.id, createdCustomer.id);

      final edited = await customers.update(
        createdCustomer.id,
        createdCustomer.patch(CustomerField.phone, '0900777666'),
      );
      expect(edited.phone, '0900777666');
      expect((await customers.get(createdCustomer.id)).phone, '0900777666');
      expect(edited.note, 'Ghi chú thử', reason: 'metadata gộp nông');

      await customers.delete(createdCustomer.id);
      expect(
        () => customers.get(createdCustomer.id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'đổi giai đoạn → chi tiết, tổng và nhật ký của khách đổi theo',
      () async {
        final row = (await opportunities.list(stageCode: 'new')).items.first;
        final before = await opportunities.summary(pipeline: 'standard');

        final moved = await opportunities.moveStage(
          row.id,
          stageCode: 'quoted',
        );
        expect(moved.stageCode, 'quoted');
        expect((await opportunities.get(row.id)).stageCode, 'quoted');

        final after = await opportunities.summary(pipeline: 'standard');
        expect(after.totalFor('new').count, before.totalFor('new').count - 1);
        expect(
          after.totalFor('quoted').count,
          before.totalFor('quoted').count + 1,
        );

        final log = await customers.activities(row.customerId!);
        expect(log.first.text, contains('Đã báo giá'));

        expect(
          () => opportunities.moveStage(row.id, stageCode: 'khong_co'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('tạo cơ hội, sửa, đánh dấu thắng', () async {
      final customer = (await customers.list(
        query: {'search': 'Lan'},
      )).items.firstWhere((c) => c.name == 'Nguyễn Thị Lan');
      final draft = Opportunity.blank().applyForm(
        title: 'Máy rửa bát âm tủ',
        stageCode: '',
        value: 16000000,
        customerId: customer.id,
        customerName: customer.name,
        product: 'Máy rửa bát 14 bộ',
        expectedCloseAt: DateTime.now().add(const Duration(days: 5)),
      );
      final createdOpp = await opportunities.create(draft);
      expect(createdOpp.stageCode, 'new');
      expect(createdOpp.status, 'OPEN');
      expect(createdOpp.product, 'Máy rửa bát 14 bộ');

      final ofCustomer = await opportunities.list(customerId: customer.id);
      expect(ofCustomer.items.map((o) => o.id), contains(createdOpp.id));

      final edited = await opportunities.update(
        createdOpp.id,
        createdOpp.applyForm(
          title: 'Máy rửa bát âm tủ (2 chiếc)',
          stageCode: 'negotiating',
          value: 30000000,
          product: 'Máy rửa bát 14 bộ',
          expectedCloseAt: createdOpp.expectedCloseAt,
        ),
      );
      expect(edited.title, 'Máy rửa bát âm tủ (2 chiếc)');
      expect(edited.stageCode, 'negotiating');
      expect(edited.value, 30000000);

      final summaryBefore = await customers.summary(customer.id);
      final win = await opportunities.markWon(createdOpp.id);
      expect(win.orderCreated, isTrue);
      expect(win.opportunity.isWon, isTrue);
      final again = await opportunities.markWon(createdOpp.id);
      expect(again.orderCreated, isFalse);
      expect(again.orderId, win.orderId);

      final summaryAfter = await customers.summary(customer.id);
      expect(summaryAfter.ordersCount, summaryBefore.ordersCount + 1);
    });
  });
}
