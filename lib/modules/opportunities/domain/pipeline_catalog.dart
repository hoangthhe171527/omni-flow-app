import '../../../core/utils/json.dart';

/// Kết cục của một giai đoạn: còn mở, Thắng hay Thua.
///
/// Máy chủ quyết định điều này theo từng quy trình (`metadata.outcome` của
/// giai đoạn) — một quy trình bán lẻ có thể gọi giai đoạn Thắng là `da_mua`.
/// App không bao giờ suy kết cục từ mã.
enum StageOutcome {
  open,
  won,
  lost;

  static StageOutcome parse(String? raw) => switch (raw) {
    'won' => StageOutcome.won,
    'lost' => StageOutcome.lost,
    _ => StageOutcome.open,
  };

  /// Giá trị `opportunity_status` mà máy chủ ghi khi cơ hội tới giai đoạn này.
  String get status => switch (this) {
    StageOutcome.open => 'OPEN',
    StageOutcome.won => 'WON',
    StageOutcome.lost => 'LOST',
  };
}

/// Một giai đoạn của quy trình, như `GET /sales-opportunities/pipelines` gửi.
class PipelineStageDef {
  const PipelineStageDef({
    required this.code,
    required this.label,
    required this.outcome,
    required this.sortOrder,
    this.probability,
    this.color,
  });

  factory PipelineStageDef.fromJson(Map<String, dynamic> json) {
    final code = json.strOr('code', '');
    final probability = json['probability'];
    return PipelineStageDef(
      code: code,
      label: json.str('label') ?? code,
      outcome: StageOutcome.parse(json.str('outcome')),
      probability: probability is num ? probability.round() : null,
      sortOrder: json.intOr('sort_order'),
      color: json.str('color'),
    );
  }

  /// Mã thô, ghi lại nguyên văn vào `opportunity_stage`.
  final String code;
  final String label;
  final StageOutcome outcome;

  /// Xác suất mặc định (%) của giai đoạn; null khi quy trình không khai.
  final int? probability;
  final int sortOrder;

  /// Màu hex (`#94a3b8`) mà web cấu hình; app chưa dùng.
  final String? color;

  bool get isClosed => outcome != StageOutcome.open;
}

/// Một quy trình bán hàng với các giai đoạn đã sắp theo thứ tự.
class PipelineDef {
  const PipelineDef({
    required this.code,
    required this.label,
    required this.isDefault,
    required this.stages,
  });

  factory PipelineDef.fromJson(Map<String, dynamic> json) {
    final code = json.strOr('code', '').toLowerCase();
    final stages =
        json
            .mapList('stages')
            .map(PipelineStageDef.fromJson)
            .where((stage) => stage.code.isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PipelineDef(
      code: code,
      label: json.str('label') ?? code,
      isDefault: json.flag('is_default'),
      stages: List.unmodifiable(stages),
    );
  }

  final String code;
  final String label;
  final bool isDefault;

  /// Mọi giai đoạn đang bật, theo thứ tự — kể cả Thắng/Thua.
  final List<PipelineStageDef> stages;

  /// Con đường một cơ hội đi qua trước khi chốt.
  List<PipelineStageDef> get openStages =>
      stages.where((stage) => !stage.isClosed).toList();

  PipelineStageDef? stage(String? code) {
    if (code == null) return null;
    for (final stage in stages) {
      if (stage.code == code) return stage;
    }
    return null;
  }

  /// Cột mở mặc định của bảng: giai đoạn mở đầu tiên (hoặc giai đoạn đầu khi
  /// quy trình chỉ có giai đoạn đóng).
  PipelineStageDef? get firstStage {
    final open = openStages;
    if (open.isNotEmpty) return open.first;
    return stages.isEmpty ? null : stages.first;
  }
}

/// Danh mục quy trình của tenant — `GET /sales-opportunities/pipelines`.
class PipelineCatalog {
  const PipelineCatalog({
    required this.defaultCode,
    required this.pipelines,
    this.fromServer = true,
  });

  /// `{default, pipelines: [{code, label, is_default, stages: [...]}]}`.
  factory PipelineCatalog.fromJson(Map<String, dynamic> json) {
    final pipelines = json
        .mapList('pipelines')
        .map(PipelineDef.fromJson)
        .where((pipeline) => pipeline.code.isNotEmpty)
        .toList();
    if (pipelines.isEmpty) return legacy;
    final flagged = pipelines.where((p) => p.isDefault).map((p) => p.code);
    return PipelineCatalog(
      defaultCode:
          json.str('default')?.toLowerCase() ??
          (flagged.isEmpty ? pipelines.first.code : flagged.first),
      pipelines: List.unmodifiable(pipelines),
    );
  }

  final String defaultCode;
  final List<PipelineDef> pipelines;

  /// false cho [legacy] — danh mục app tự dựng khi API chưa có `/pipelines`.
  /// Khi đó app không biết mã quy trình thật, nên không được gửi `pipeline`
  /// trong truy vấn (tenant có thể đặt một quy trình khác làm mặc định).
  final bool fromServer;

  PipelineDef get defaultPipeline {
    for (final pipeline in pipelines) {
      if (pipeline.code == defaultCode) return pipeline;
    }
    return pipelines.isEmpty ? legacy.pipelines.first : pipelines.first;
  }

  /// Quy trình theo mã; null, rỗng hay mã không còn bật → quy trình mặc định
  /// (đúng cách máy chủ hiểu một cơ hội không có `pipeline`).
  PipelineDef pipelineOf(String? code) {
    final wanted = code?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return defaultPipeline;
    for (final pipeline in pipelines) {
      if (pipeline.code == wanted) return pipeline;
    }
    return defaultPipeline;
  }

  /// Nhãn của mã giai đoạn để hiển thị: tra trong [pipeline] (null = mặc
  /// định) trước, rồi mọi quy trình khác (nơi không biết quy trình, như ngữ
  /// cảnh hộp thư); không thấy ở đâu thì trả nguyên mã.
  String stageLabel(String code, {String? pipeline}) {
    final own = pipelineOf(pipeline).stage(code);
    if (own != null) return own.label;
    for (final p in pipelines) {
      final stage = p.stage(code);
      if (stage != null) return stage.label;
    }
    return code;
  }

  /// Danh mục dự phòng khi API cũ chưa có `/pipelines` (404): đúng 6 giai
  /// đoạn chuẩn mà máy chủ dùng cho quy trình `standard` chưa cấu hình
  /// (`SeedDefaultCrmPipelines::standardStageDefaults`).
  static const PipelineCatalog legacy = PipelineCatalog(
    defaultCode: 'standard',
    fromServer: false,
    pipelines: [
      PipelineDef(
        code: 'standard',
        label: 'Bán hàng chuẩn',
        isDefault: true,
        stages: [
          PipelineStageDef(
            code: 'new',
            label: 'Mới',
            outcome: StageOutcome.open,
            probability: 10,
            sortOrder: 1,
          ),
          PipelineStageDef(
            code: 'consulted',
            label: 'Đã tư vấn',
            outcome: StageOutcome.open,
            probability: 25,
            sortOrder: 2,
          ),
          PipelineStageDef(
            code: 'quoted',
            label: 'Đã báo giá',
            outcome: StageOutcome.open,
            probability: 50,
            sortOrder: 3,
          ),
          PipelineStageDef(
            code: 'negotiating',
            label: 'Đàm phán',
            outcome: StageOutcome.open,
            probability: 75,
            sortOrder: 4,
          ),
          PipelineStageDef(
            code: 'won',
            label: 'Chốt',
            outcome: StageOutcome.won,
            probability: 100,
            sortOrder: 5,
          ),
          PipelineStageDef(
            code: 'lost',
            label: 'Thất bại',
            outcome: StageOutcome.lost,
            probability: 0,
            sortOrder: 6,
          ),
        ],
      ),
    ],
  );
}
