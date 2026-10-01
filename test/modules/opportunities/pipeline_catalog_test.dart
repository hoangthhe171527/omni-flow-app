import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';

/// Danh mục quy trình đọc từ `GET /sales-opportunities/pipelines`.
void main() {
  Map<String, dynamic> stage(
    String code,
    String outcome,
    int order, {
    int? probability,
  }) => {
    'code': code,
    'label': code.toUpperCase(),
    'outcome': outcome,
    'probability': probability,
    'sort_order': order,
    'color': '#000000',
  };

  final json = {
    'default': 'ban_le',
    'pipelines': [
      {
        'code': 'standard',
        'label': 'Bán hàng chuẩn',
        'is_default': false,
        'stages': [stage('new', 'open', 1), stage('won', 'won', 2)],
      },
      {
        'code': 'ban_le',
        'label': 'Bán lẻ',
        'is_default': true,
        // Cố ý lộn thứ tự: app sắp lại theo `sort_order`.
        'stages': [
          stage('da_mua', 'won', 3, probability: 100),
          stage('lien_he', 'open', 1, probability: 10),
          stage('khong_mua', 'lost', 4),
          stage('tu_van', 'open', 2),
        ],
      },
    ],
  };

  test('đọc quy trình mặc định, giai đoạn theo thứ tự và kết cục', () {
    final catalog = PipelineCatalog.fromJson(json);
    expect(catalog.fromServer, isTrue);
    expect(catalog.defaultCode, 'ban_le');
    expect(catalog.defaultPipeline.label, 'Bán lẻ');

    final retail = catalog.pipelineOf('ban_le');
    expect(retail.stages.map((s) => s.code), [
      'lien_he',
      'tu_van',
      'da_mua',
      'khong_mua',
    ]);
    expect(retail.openStages.map((s) => s.code), ['lien_he', 'tu_van']);
    expect(retail.stage('da_mua')!.outcome, StageOutcome.won);
    expect(retail.stage('da_mua')!.isClosed, isTrue);
    expect(retail.stage('khong_mua')!.outcome, StageOutcome.lost);
    expect(retail.stage('lien_he')!.probability, 10);
    expect(retail.stage('khong_co'), isNull);
    expect(retail.firstStage!.code, 'lien_he');
  });

  test('mã quy trình null, rỗng hay đã tắt → quy trình mặc định', () {
    final catalog = PipelineCatalog.fromJson(json);
    expect(catalog.pipelineOf(null).code, 'ban_le');
    expect(catalog.pipelineOf('').code, 'ban_le');
    expect(catalog.pipelineOf('da_tat').code, 'ban_le');
    expect(catalog.pipelineOf('STANDARD').code, 'standard');
  });

  test('danh mục dự phòng có đúng 6 giai đoạn chuẩn của máy chủ', () {
    const legacy = PipelineCatalog.legacy;
    expect(legacy.fromServer, isFalse);
    expect(legacy.defaultPipeline.code, 'standard');
    expect(legacy.defaultPipeline.stages.map((s) => s.code), [
      'new',
      'consulted',
      'quoted',
      'negotiating',
      'won',
      'lost',
    ]);
    expect(legacy.defaultPipeline.stage('won')!.outcome, StageOutcome.won);
    expect(legacy.defaultPipeline.stage('lost')!.outcome, StageOutcome.lost);
  });

  test('phản hồi không có quy trình nào → dùng danh mục dự phòng', () {
    final catalog = PipelineCatalog.fromJson({'pipelines': <dynamic>[]});
    expect(catalog.defaultPipeline.stages, hasLength(6));
  });
}
