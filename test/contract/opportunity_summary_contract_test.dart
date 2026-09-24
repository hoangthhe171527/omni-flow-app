import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';

/// `GET /sales-opportunities/summary` — app từng đọc khuôn `{stage: {count,
/// value}}` mà API chưa bao giờ gửi. API gửi `{total_count, value_by_stage,
/// count_by_stage}`, nên mọi cột pipeline hiện 0 mà không lỗi nào.
///
/// Fixture chép NGUYÊN VĂN từ API local (2026-09-24, tenant demo).
void main() {
  Map<String, dynamic> load(String name) {
    final file = File('test/contract/fixtures/$name.json');
    expect(file.existsSync(), isTrue, reason: 'Thiếu bản ghi $name.json.');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('GET /sales-opportunities/summary', () {
    test('đọc được số đếm và giá trị từng giai đoạn từ phản hồi thật', () {
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
        final stage = PipelineStage.parse(code);
        expect(summary.totalFor(stage).count, counts[code]!.toInt());
        expect(summary.totalFor(stage).value, values[code]!.toDouble());
      }
      final total = counts.values.fold<int>(0, (s, n) => s + n.toInt());
      expect(total, data['total_count']);
      expect(
        summary.openCount +
            summary.totalFor(PipelineStage.won).count +
            summary.totalFor(PipelineStage.lost).count,
        total,
      );
    });

    test('pipeline rỗng: API trả [] thay vì {} — không vỡ', () {
      final summary = PipelineSummary.fromJson({
        'total_count': 0,
        'value_by_stage': <dynamic>[],
        'count_by_stage': <dynamic>[],
      });
      expect(summary.openCount, 0);
      expect(summary.openValue, 0);
    });

    test(
      'giai đoạn tuỳ biến không dồn vào cột "Mới"; mã cũ chữ hoa cộng dồn',
      () {
        final summary = PipelineSummary.fromJson({
          'total_count': 4,
          'value_by_stage': {'new': 100, 'LEAD': 50, 'demo_sp': 999, 'won': 70},
          'count_by_stage': {'new': 1, 'LEAD': 1, 'demo_sp': 1, 'won': 1},
        });
        expect(summary.totalFor(PipelineStage.fresh).count, 2);
        expect(summary.totalFor(PipelineStage.fresh).value, 150);
        expect(summary.totalFor(PipelineStage.won).value, 70);
        expect(summary.openValue, 150);
      },
    );

    test('khuôn cũ {stage: {count, value}} vẫn đọc được', () {
      final summary = PipelineSummary.fromJson({
        'quoted': {'count': 3, 'value': 300},
      });
      expect(summary.totalFor(PipelineStage.quoted).count, 3);
      expect(summary.totalFor(PipelineStage.quoted).value, 300);
    });
  });
}
