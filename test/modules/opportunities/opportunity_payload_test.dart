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
    test('giai đoạn tuỳ biến giữ nguyên mã, gửi lại đúng mã gốc', () {
      final opp = Opportunity.fromJson(json());
      expect(opp.stage, PipelineStage.fresh);
      expect(opp.stageCode, 'demo_sp');
      expect(opp.toPayload()['opportunity_stage'], 'demo_sp');
    });

    test('sửa form mà KHÔNG đổi giai đoạn → vẫn gửi mã gốc', () {
      final opp = Opportunity.fromJson(json());
      final edited = opp.applyForm(
        title: 'Piano điện',
        stageCode: opp.stageCode,
        value: 2000,
      );
      expect(edited.toPayload()['opportunity_stage'], 'demo_sp');
      expect(edited.toPayload()['title'], 'Piano điện');
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
      expect(opp.toPayload()['opportunity_stage'], 'negotiating');
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
}
