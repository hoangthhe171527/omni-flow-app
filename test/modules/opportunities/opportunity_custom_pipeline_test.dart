import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';

/// Cơ hội ở quy trình tuỳ biến (tenant demo có `ban_le`: `lien_he` → `tu_van`
/// → `bao_gia` → `da_mua` (Thắng) / `khong_mua` (Thua)).
///
/// Trước đây app gấp mọi mã lạ về "Mới": cơ hội đã mua bị gắn quá hạn, và
/// kéo thẻ gửi `new` khiến máy chủ trả 200 mà không đổi gì.
void main() {
  final catalog = PipelineCatalog.fromJson(
    ((jsonDecode(
                  File(
                    'test/contract/fixtures/sales_opportunities_pipelines.json',
                  ).readAsStringSync(),
                )
                as Map)['data']
            as Map)
        .cast<String, dynamic>(),
  );

  test('cơ hội đã mua ở quy trình bán lẻ là đã đóng, không quá hạn', () {
    final o = Opportunity.fromJson({
      'id': 'o1',
      'title': 'Đàn U1',
      'opportunity_stage': 'da_mua',
      'pipeline': 'ban_le',
      'opportunity_status': 'WON',
      'expected_end_date': '2020-01-01',
    });
    expect(o.stageCode, 'da_mua');
    expect(o.pipelineCode, 'ban_le');
    expect(o.isClosed, isTrue);
    expect(o.isWon, isTrue);
    expect(o.isOverdue, isFalse);
    expect(
      catalog.pipelineOf('ban_le').stage('da_mua')!.outcome,
      StageOutcome.won,
    );
  });

  test('cơ hội mở quá hạn vẫn bị gắn quá hạn', () {
    final o = Opportunity.fromJson({
      'id': 'o1',
      'opportunity_stage': 'lien_he',
      'pipeline': 'ban_le',
      'opportunity_status': 'OPEN',
      'expected_end_date': '2020-01-01',
    });
    expect(o.isClosed, isFalse);
    expect(o.isOverdue, isTrue);
  });

  test('thiếu opportunity_status → đọc outcome, rồi mới tới mã chuẩn', () {
    expect(
      Opportunity.fromJson({
        'id': 'o1',
        'opportunity_stage': 'khong_mua',
        'outcome': 'lost',
      }).isClosed,
      isTrue,
    );
    expect(
      Opportunity.fromJson({'id': 'o1', 'opportunity_stage': 'won'}).isClosed,
      isTrue,
    );
    expect(
      Opportunity.fromJson({
        'id': 'o1',
        'opportunity_stage': 'da_mua',
      }).isClosed,
      isFalse,
    );
  });

  test('toPayload gửi mã thô và quy trình, không gấp về "new"', () {
    final o = Opportunity.fromJson({
      'id': 'o1',
      'title': 'Đàn',
      'opportunity_stage': 'lien_he',
      'pipeline': 'ban_le',
      'opportunity_status': 'OPEN',
    });
    final p = o.copyWith(stageCode: 'khong_mua').toPayload();
    expect(p['opportunity_stage'], 'khong_mua');
    expect(p['pipeline'], 'ban_le');
  });

  test('cơ hội không có quy trình (mặc định) không gửi pipeline', () {
    final o = Opportunity.fromJson({
      'id': 'o1',
      'title': 'Đàn',
      'opportunity_stage': 'new',
    });
    expect(o.toPayload().containsKey('pipeline'), isFalse);
  });

  test('summary giữ mã tuỳ biến; tổng mở tính theo quy trình', () {
    final s = PipelineSummary.fromJson({
      'total_count': 5,
      'count_by_stage': {'lien_he': 2, 'tu_van': 1, 'da_mua': 1, 'new': 1},
      'value_by_stage': {'lien_he': 10, 'tu_van': 4, 'da_mua': 5, 'new': 7},
    });
    expect(s.byCode['lien_he']!.count, 2);
    expect(s.totalFor('da_mua').value, 5);
    final retail = catalog.pipelineOf('ban_le');
    expect(s.openCount(retail), 3);
    expect(s.openValue(retail), 14);
  });

  test(
    'xác suất: trường đã đặt, không thì xác suất giai đoạn của quy trình',
    () {
      final retail = catalog.pipelineOf('ban_le');
      final o = Opportunity.fromJson({
        'id': 'o1',
        'opportunity_stage': 'tu_van',
        'pipeline': 'ban_le',
        'estimated_budget': '1000',
      });
      expect(o.value, 1000);
      expect(
        o.effectiveProbability(retail),
        retail.stage('tu_van')!.probability,
      );
      final set = Opportunity.fromJson({
        'id': 'o1',
        'opportunity_stage': 'tu_van',
        'metadata': {'probability': 40},
      });
      expect(set.effectiveProbability(retail), 40);
      expect(set.weightedValue(retail), 0);
    },
  );

  group('metadata: chỉ gửi khoá đã đổi', () {
    // API gộp NÔNG metadata khi PUT (`MetadataPatch::merge`): khoá không gửi
    // được giữ nguyên. Gửi lại cả túi chỉ để ghi đè khoá web vừa sửa bằng bản
    // cũ app đang cầm.
    Opportunity load() => Opportunity.fromJson({
      'id': 'o1',
      'title': 'Đàn',
      'opportunity_stage': 'new',
      'customer_name': 'Chị Lan',
      'metadata': {
        'a': 1,
        'lost_reason': 'x',
        'product': 'U1',
        'source': 'zalo',
        'tags': ['vip'],
      },
    });

    test('không đổi gì → không gửi metadata', () {
      expect(load().toPayload().containsKey('metadata'), isFalse);
    });

    test('đổi xác suất → metadata chỉ có probability', () {
      final p = load().copyWith(probability: 60).toPayload();
      expect(p['metadata'], {'probability': 60});
    });

    test('đổi sản phẩm qua form → chỉ product', () {
      final p = load()
          .applyForm(title: 'Đàn', stageCode: 'new', value: 0, product: 'U3')
          .toPayload();
      expect(p['metadata'], {'product': 'U3'});
    });

    test('tạo mới gửi các khoá app có', () {
      final p = Opportunity.blank()
          .applyForm(
            title: 'Mới',
            stageCode: 'lien_he',
            value: 5,
            customerName: 'Anh Minh',
            product: 'P-125',
          )
          .toPayload();
      final metadata = p['metadata'] as Map;
      expect(metadata['customer_name'], 'Anh Minh');
      expect(metadata['product'], 'P-125');
      expect(metadata.containsKey('probability'), isFalse);
    });
  });
}
