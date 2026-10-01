import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';

/// `GET /sales-opportunities/summary` — app từng đọc khuôn `{stage: {count,
/// value}}` mà API chưa bao giờ gửi. API gửi `{total_count, value_by_stage,
/// count_by_stage}`, nên mọi cột pipeline hiện 0 mà không lỗi nào.
///
/// Fixture chép NGUYÊN VĂN từ API local (tenant demo, có quy trình `ban_le`).
void main() {
  Map<String, dynamic> load(String name) {
    final file = File('test/contract/fixtures/$name.json');
    expect(file.existsSync(), isTrue, reason: 'Thiếu bản ghi $name.json.');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('GET /sales-opportunities/summary', () {
    test('đọc được số đếm và giá trị MỌI giai đoạn từ phản hồi thật', () {
      final data = load('sales_opportunities_summary')['data'];
      final summary = PipelineSummary.fromJson(
        (data as Map).cast<String, dynamic>(),
      );

      final values = (data['value_by_stage'] as Map).cast<String, num>();
      final counts = (data['count_by_stage'] as Map).cast<String, num>();
      expect(
        values,
        isNotEmpty,
        reason: 'Bản ghi rỗng thì không kiểm được gì.',
      );

      for (final code in counts.keys) {
        expect(summary.totalFor(code).count, counts[code]!.toInt());
        expect(summary.totalFor(code).value, values[code]!.toDouble());
      }
      final total = counts.values.fold<int>(0, (s, n) => s + n.toInt());
      expect(total, data['total_count']);
      expect(
        summary.byCode.values.fold<int>(0, (s, t) => s + t.count),
        total,
        reason: 'Mã tuỳ biến không được rơi mất.',
      );
    });

    test('pipeline rỗng: API trả [] thay vì {} — không vỡ', () {
      final summary = PipelineSummary.fromJson({
        'total_count': 0,
        'value_by_stage': <dynamic>[],
        'count_by_stage': <dynamic>[],
      });
      final standard = PipelineCatalog.legacy.defaultPipeline;
      expect(summary.openCount(standard), 0);
      expect(summary.openValue(standard), 0);
    });

    test(
      'giai đoạn tuỳ biến giữ cột riêng, không dồn vào "Mới"; mã cũ chữ hoa cộng dồn',
      () {
        final summary = PipelineSummary.fromJson({
          'total_count': 4,
          'value_by_stage': {'new': 100, 'LEAD': 50, 'demo_sp': 999, 'won': 70},
          'count_by_stage': {'new': 1, 'LEAD': 1, 'demo_sp': 1, 'won': 1},
        });
        final standard = PipelineCatalog.legacy.defaultPipeline;
        expect(summary.totalFor('new').count, 2);
        expect(summary.totalFor('new').value, 150);
        expect(summary.totalFor('demo_sp').value, 999);
        expect(summary.totalFor('won').value, 70);
        expect(summary.openValue(standard), 150);
      },
    );

    test('khuôn cũ {stage: {count, value}} vẫn đọc được', () {
      final summary = PipelineSummary.fromJson({
        'quoted': {'count': 3, 'value': 300},
      });
      expect(summary.totalFor('quoted').count, 3);
      expect(summary.totalFor('quoted').value, 300);
    });
  });
}
