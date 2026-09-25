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
    test('giai đoạn tuỳ biến hiện ở cột Mới nhưng gửi lại đúng mã gốc', () {
      final opp = Opportunity.fromJson(json());
      expect(opp.stage, PipelineStage.fresh);
      expect(opp.rawStage, 'demo_sp');
      expect(opp.toPayload()['opportunity_stage'], 'demo_sp');
    });

    test('sửa form mà KHÔNG đổi giai đoạn → vẫn gửi mã gốc', () {
      final opp = Opportunity.fromJson(json());
      final edited = opp.applyForm(
        title: 'Piano điện',
        stage: PipelineStage.fresh,
        value: 2000,
      );
      expect(edited.toPayload()['opportunity_stage'], 'demo_sp');
      expect(edited.toPayload()['title'], 'Piano điện');
    });

    test('người dùng đổi giai đoạn → gửi giai đoạn mới', () {
      final opp = Opportunity.fromJson(json());
      expect(
        opp
            .applyForm(title: 'x', stage: PipelineStage.quoted, value: 1)
            .toPayload()['opportunity_stage'],
        'quoted',
      );
      expect(
        opp.copyWith(stage: PipelineStage.won).toPayload()['opportunity_stage'],
        'won',
      );
    });

    test('mã cũ viết HOA được chuẩn hoá (API chỉ nhận chữ thường)', () {
      final opp = Opportunity.fromJson(json(stage: 'NEGOTIATION'));
      expect(opp.toPayload()['opportunity_stage'], 'negotiating');
    });

    test('tạo mới dùng slug của giai đoạn đã chọn', () {
      final draft = Opportunity.blank().applyForm(
        title: 'Mới',
        stage: PipelineStage.consulted,
        value: 5,
        customerId: 'c9',
      );
      expect(draft.toPayload()['opportunity_stage'], 'consulted');
      expect(draft.toPayload()['customer_id'], 'c9');
    });
  });

  group('metadata', () {
    test(
      'không có xác suất → không gửi (không ghim xác suất mặc định của giai đoạn)',
      () {
        final metadata =
            Opportunity.fromJson(json()).toPayload()['metadata'] as Map;
        expect(metadata.containsKey('probability'), isFalse);
        expect(metadata['notes'], 'n');
      },
    );

    test('có xác suất → gửi đúng số đó', () {
      final opp = Opportunity.fromJson(json(metadata: {'probability': 40}));
      expect((opp.toPayload()['metadata'] as Map)['probability'], 40);
    });

    test('sửa form giữ tags/kênh của bản ghi gốc', () {
      final opp = Opportunity.fromJson(
        json(
          metadata: {
            'tags': ['nóng'],
            'channel': 'zalo',
          },
        ),
      );
      final metadata =
          opp
                  .applyForm(title: 'x', stage: PipelineStage.fresh, value: 1)
                  .toPayload()['metadata']
              as Map;
      expect(metadata['tags'], ['nóng']);
      expect(metadata['channel'], 'zalo');
    });
  });
}
