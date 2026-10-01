import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';

/// `GET /sales-opportunities/pipelines` và `GET /sales-opportunities`, đo trên
/// phản hồi THẬT (tenant demo có quy trình tuỳ biến `ban_le`). Chép lại bằng
/// `tool/capture_contract.sh`.
void main() {
  Map<String, dynamic> load(String name) {
    final file = File('test/contract/fixtures/$name.json');
    expect(file.existsSync(), isTrue, reason: 'Thiếu bản ghi $name.json.');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('GET /sales-opportunities/pipelines', () {
    test('đọc được quy trình, giai đoạn, kết cục và xác suất', () {
      final data = (load('sales_opportunities_pipelines')['data'] as Map)
          .cast<String, dynamic>();
      final catalog = PipelineCatalog.fromJson(data);

      expect(catalog.fromServer, isTrue);
      expect(catalog.defaultCode, data['default']);
      expect(catalog.pipelines, hasLength((data['pipelines'] as List).length));

      final custom = catalog.pipelines.where(
        (p) => p.stages.any(
          (s) => s.isClosed && s.code != 'won' && s.code != 'lost',
        ),
      );
      expect(
        custom,
        isNotEmpty,
        reason:
            'Bản ghi phải có một quy trình tuỳ biến với giai đoạn Thắng/Thua '
            'mã riêng — chỉ có `standard` thì bài này xanh vô nghĩa.',
      );

      for (final raw in (data['pipelines'] as List).cast<Map>()) {
        final pipeline = catalog.pipelineOf(raw['code'] as String);
        final stages = (raw['stages'] as List).cast<Map>();
        expect(pipeline.stages, hasLength(stages.length));
        for (final stage in stages) {
          final def = pipeline.stage(stage['code'] as String)!;
          expect(def.label, stage['label']);
          expect(def.outcome.name, stage['outcome']);
          expect(def.probability, stage['probability']);
          expect(def.sortOrder, stage['sort_order']);
        }
      }
    });
  });

  group('GET /sales-opportunities', () {
    test('mỗi dòng đọc được mã thô, quy trình, trạng thái và kết cục', () {
      final rows = (load('sales_opportunities_index')['data'] as List)
          .cast<Map<String, dynamic>>();
      expect(rows, isNotEmpty, reason: 'Bản ghi rỗng thì không kiểm được gì.');

      for (final row in rows) {
        // Ba trường bảng cơ hội dựa vào phải có thật trong phản hồi.
        expect(row, contains('opportunity_status'));
        expect(row, contains('pipeline'));
        expect(row, contains('outcome'));

        final o = Opportunity.fromJson(row);
        expect(o.stageCode, row['opportunity_stage']);
        expect(o.pipelineCode, row['pipeline']);
        expect(o.isClosed, row['opportunity_status'] != 'OPEN');
        expect(o.value, double.parse('${row['estimated_budget']}'));
        expect(o.customerName, row['customer_name']);
      }
    });

    test('phân trang có đủ trường để tải trang sau', () {
      final pagination =
          (load('sales_opportunities_index')['pagination'] as Map)
              .cast<String, dynamic>();
      for (final key in ['current_page', 'last_page', 'per_page', 'total']) {
        expect(pagination, contains(key));
      }
    });
  });
}
