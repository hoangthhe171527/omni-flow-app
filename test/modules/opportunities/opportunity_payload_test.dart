import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';

/// Lưu cơ hội từ app không được ghi đè giai đoạn tuỳ biến của tenant (pipeline
/// cấu hình trên web, vd `demo_sp`) về `new`, và không ghim xác suất mặc định.
void main() {
  Map<String, dynamic> json({
    String stage = 'demo_sp',
    Map<String, dynamic>? metadata,
  }) => {
    'id': 'o1',
    'title': 'Piano cho con',
    'customer_id': 'c1',
    'estimated_budget': 1000,
    'opportunity_stage': stage,
    'metadata': metadata ?? {'notes': 'n', 'product_group': 'piano'},
  };

  group('giai đoạn gốc', () {
    // Giai đoạn không đổi thì KHÔNG gửi: máy chủ giữ nguyên mã đang lưu. Gửi
    // lại (dù đúng mã) không bao giờ có lợi, và với mã cũ viết HOA thì gửi
    // bản đã chuẩn hoá là một lần ĐỔI giai đoạn với máy chủ.
    test('giai đoạn tuỳ biến giữ nguyên mã, không bị gửi đè thành mã khác', () {
      final opp = Opportunity.fromJson(json());
      expect(opp.stage, PipelineStage.fresh);
      expect(opp.stageCode, 'demo_sp');
      expect(opp.toPayload().containsKey('opportunity_stage'), isFalse);
    });

    test('sửa form mà KHÔNG đổi giai đoạn → không gửi giai đoạn', () {
      final opp = Opportunity.fromJson(json());
      final edited = opp.applyForm(
        title: 'Piano điện',
        stageCode: opp.stageCode,
        value: 2000,
      );
      expect(edited.toPayload().containsKey('opportunity_stage'), isFalse);
      expect(edited.toPayload()['title'], 'Piano điện');
    });

    test('cơ hội ĐÃ HUỶ mang mã HOA cũ: sửa tiêu đề không mở lại nó', () {
      // `LEAD` đọc thành `new`; gửi `new` lên là đổi giai đoạn → máy chủ tính
      // lại trạng thái theo outcome (open) → CANCELLED thành OPEN.
      final opp = Opportunity.fromJson({
        ...json(stage: 'LEAD'),
        'opportunity_status': 'CANCELLED',
      });
      expect(opp.isCancelled, isTrue);
      final p = opp
          .applyForm(title: 'Sửa tên', stageCode: opp.stageCode, value: 1)
          .toPayload();
      expect(p.containsKey('opportunity_stage'), isFalse);
      expect(p.containsKey('opportunity_status'), isFalse);
    });

    test('người dùng đổi giai đoạn → gửi giai đoạn mới', () {
      final opp = Opportunity.fromJson(json());
      expect(
        opp
            .applyForm(title: 'x', stageCode: 'quoted', value: 1)
            .toPayload()['opportunity_stage'],
        'quoted',
      );
      expect(
        opp.copyWith(stageCode: 'won').toPayload()['opportunity_stage'],
        'won',
      );
    });

    test('mã cũ viết HOA được chuẩn hoá (API chỉ nhận chữ thường)', () {
      final opp = Opportunity.fromJson(json(stage: 'NEGOTIATION'));
      expect(opp.stageCode, 'negotiating');
      // Chuyển đi rồi chuyển lại đúng giai đoạn đó thì gửi chữ thường.
      expect(
        opp.copyWith(stageCode: 'quoted').toPayload()['opportunity_stage'],
        'quoted',
      );
    });

    test('tạo mới dùng mã của giai đoạn đã chọn', () {
      final draft = Opportunity.blank().applyForm(
        title: 'Mới',
        stageCode: 'consulted',
        value: 5,
        customerId: 'c9',
      );
      expect(draft.toPayload()['opportunity_stage'], 'consulted');
      expect(draft.toPayload()['customer_id'], 'c9');
    });

    test(
      'tạo mới chưa chọn giai đoạn → không gửi, máy chủ chọn giai đoạn đầu',
      () {
        final draft = Opportunity.blank().applyForm(
          title: 'Mới',
          stageCode: '',
          value: 5,
        );
        expect(draft.toPayload().containsKey('opportunity_stage'), isFalse);
      },
    );
  });

  group('metadata', () {
    test(
      'không có xác suất → không gửi (không ghim xác suất mặc định của giai đoạn)',
      () {
        final payload = Opportunity.fromJson(json()).toPayload();
        final metadata = (payload['metadata'] as Map?) ?? const {};
        expect(metadata.containsKey('probability'), isFalse);
        // API gộp metadata, nên khoá web ghi (`notes`) không cần — và không
        // được — gửi lại: bản app đang cầm có thể đã cũ.
        expect(metadata.containsKey('notes'), isFalse);
      },
    );

    test('có xác suất → gửi đúng số đó khi nó đổi', () {
      final opp = Opportunity.fromJson(json(metadata: {'probability': 40}));
      expect(opp.probability, 40);
      expect(
        (opp.copyWith(probability: 55).toPayload()['metadata']
            as Map)['probability'],
        55,
      );
    });

    test('sửa form không gửi lại tags/kênh của bản ghi gốc (máy chủ giữ)', () {
      final opp = Opportunity.fromJson(
        json(
          metadata: {
            'tags': ['nóng'],
            'channel': 'zalo',
          },
        ),
      );
      final payload = opp
          .applyForm(title: 'x', stageCode: opp.stageCode, value: 1)
          .toPayload();
      expect(opp.tags, ['nóng']);
      expect(payload.containsKey('metadata'), isFalse);
    });
  });

  group('xoá ô trên form', () {
    // `UpdateSalesOpportunity`: `expected_end_date`/`campaign_objective` là
    // CLEARABLE (null → ghi null); metadata gộp nông (khoá null → xoá khoá).
    // Trước đây ô bị xoá thành null rồi `copyWith` dùng `??` giữ giá trị cũ:
    // máy chủ trả 200, giá trị cũ vẫn còn.
    Opportunity loaded() => Opportunity.fromJson(
      json(metadata: {'product': 'U1'})
        ..['expected_end_date'] = '2026-10-15'
        ..['opportunity_status'] = 'OPEN',
    );

    test('xoá sản phẩm → metadata.product = null', () {
      final o = loaded();
      final p = o
          .applyForm(
            title: o.title,
            stageCode: o.stageCode,
            value: o.value,
            expectedCloseAt: o.expectedCloseAt,
          )
          .toPayload();
      expect(p['metadata'], {'product': null});
      expect(p['expected_end_date'], '2026-10-15');
    });

    test('xoá ngày dự kiến chốt → expected_end_date = null', () {
      final o = loaded();
      final p = o
          .applyForm(
            title: o.title,
            stageCode: o.stageCode,
            value: o.value,
            product: o.product,
          )
          .toPayload();
      expect(p.containsKey('expected_end_date'), isTrue);
      expect(p['expected_end_date'], isNull);
      expect(p.containsKey('metadata'), isFalse);
    });

    test('sản phẩm lấy từ campaign_objective → xoá cả campaign_objective', () {
      final o = Opportunity.fromJson({
        ...json(metadata: {}),
        'campaign_objective': 'Đàn cơ',
      });
      expect(o.product, 'Đàn cơ');
      final p = o
          .applyForm(title: o.title, stageCode: o.stageCode, value: o.value)
          .toPayload();
      expect(p.containsKey('campaign_objective'), isTrue);
      expect(p['campaign_objective'], isNull);
    });

    test('ngày chưa từng đặt và vẫn trống → không gửi', () {
      final o = Opportunity.fromJson(json());
      final p = o
          .applyForm(title: o.title, stageCode: o.stageCode, value: o.value)
          .toPayload();
      expect(p.containsKey('expected_end_date'), isFalse);
    });
  });

  test('CANCELLED là đã đóng nhưng không phải thắng hay thua', () {
    final o = Opportunity.fromJson({
      ...json(stage: 'lost'),
      'opportunity_status': 'CANCELLED',
    });
    expect(o.isClosed, isTrue);
    expect(o.isCancelled, isTrue);
    expect(o.isWon, isFalse);
  });

  // Web ghi `metadata.notes` dạng CHUỖI; app từng chỉ đọc mảng mục nên ghi chú
  // nhập trên web biến mất trên app (OPP-X7, APP-I6).
  group('ghi chú', () {
    test('notes dạng chuỗi (web) → một ghi chú', () {
      final o = Opportunity.fromJson(
        json(metadata: {'notes': 'Khách hẹn tuần sau'}),
      );
      expect(o.notes.single.content, 'Khách hẹn tuần sau');
    });

    test('notes dạng mảng (bản app cũ) vẫn đọc như trước', () {
      final o = Opportunity.fromJson(
        json(
          metadata: {
            'notes': [
              {'content': 'Gọi lại', 'author': 'Lan'},
              {'content': 'Báo giá'},
            ],
          },
        ),
      );
      expect(o.notes.map((n) => n.content), ['Gọi lại', 'Báo giá']);
    });

    test('notes chuỗi rỗng → không có ghi chú', () {
      final o = Opportunity.fromJson(json(metadata: {'notes': '  '}));
      expect(o.notes, isEmpty);
    });
  });

  // Ngân sách trống không được thành 0: `value ?? 0` rồi luôn gửi
  // `estimated_budget` là ghi 0 lên cơ hội web để trống (OPP-X8).
  group('ngân sách', () {
    Map<String, dynamic> noBudget() => {...json()}..remove('estimated_budget');

    test('không có ngân sách, sửa tên → không gửi estimated_budget', () {
      final o = Opportunity.fromJson(noBudget());
      final p = o.copyWith(title: 'Tên mới').toPayload();
      expect(p.containsKey('estimated_budget'), isFalse);
    });

    test('xoá ngân sách đang có → gửi null', () {
      final o = Opportunity.fromJson({...json(), 'estimated_budget': 5e6});
      final p = o
          .applyForm(title: o.title, stageCode: o.stageCode, value: null)
          .toPayload();
      expect(p.containsKey('estimated_budget'), isTrue);
      expect(p['estimated_budget'], isNull);
    });

    test('đổi ngân sách → gửi giá trị mới', () {
      final o = Opportunity.fromJson({...json(), 'estimated_budget': 5e6});
      final p = o
          .applyForm(title: o.title, stageCode: o.stageCode, value: 7e6)
          .toPayload();
      expect(p['estimated_budget'], 7e6);
    });

    test('tạo mới có ngân sách → gửi', () {
      final p = Opportunity.blank()
          .applyForm(title: 'Đàn', stageCode: 'new', value: 3e6)
          .toPayload();
      expect(p['estimated_budget'], 3e6);
    });
  });
}
