import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Pipeline stages, in the order a deal moves through them.
enum PipelineStage {
  fresh,
  consulted,
  quoted,
  negotiating,
  won,
  lost;

  /// The API stores both a legacy UPPERCASE vocabulary and the canonical
  /// lowercase one, so both are accepted on read.
  static PipelineStage parse(String? raw) => switch (raw) {
        'LEAD' || 'new' => PipelineStage.fresh,
        'QUALIFIED' || 'consulted' => PipelineStage.consulted,
        'PROPOSAL' || 'quoted' => PipelineStage.quoted,
        'NEGOTIATION' || 'negotiating' => PipelineStage.negotiating,
        'WON' || 'won' => PipelineStage.won,
        'LOST' || 'lost' => PipelineStage.lost,
        _ => PipelineStage.fresh,
      };

  /// Canonical value written back.
  String get slug => switch (this) {
        PipelineStage.fresh => 'new',
        PipelineStage.consulted => 'consulted',
        PipelineStage.quoted => 'quoted',
        PipelineStage.negotiating => 'negotiating',
        PipelineStage.won => 'won',
        PipelineStage.lost => 'lost',
      };

  String get label => switch (this) {
        PipelineStage.fresh => 'Mới',
        PipelineStage.consulted => 'Tư vấn',
        PipelineStage.quoted => 'Báo giá',
        PipelineStage.negotiating => 'Đàm phán',
        PipelineStage.won => 'Thắng',
        PipelineStage.lost => 'Thua',
      };

  bool get isClosed => this == PipelineStage.won || this == PipelineStage.lost;

  /// Default probability when the record carries none — the shape of a normal
  /// funnel, so forecasts aren't all zero on day one.
  int get defaultProbability => switch (this) {
        PipelineStage.fresh => 10,
        PipelineStage.consulted => 30,
        PipelineStage.quoted => 50,
        PipelineStage.negotiating => 75,
        PipelineStage.won => 100,
        PipelineStage.lost => 0,
      };

  static const board = [
    PipelineStage.fresh,
    PipelineStage.consulted,
    PipelineStage.quoted,
    PipelineStage.negotiating,
    PipelineStage.won,
    PipelineStage.lost,
  ];
}

class OpportunityNote {
  const OpportunityNote({required this.content, this.author, this.at});

  factory OpportunityNote.fromJson(Map<String, dynamic> json) => OpportunityNote(
        content: json.strOr('content', ''),
        author: json.str('author'),
        at: DateUtilsX.parse(json['at']) ?? DateUtilsX.parse(json['created_at']),
      );

  final String content;
  final String? author;
  final DateTime? at;
}

class Opportunity {
  const Opportunity({
    required this.id,
    required this.title,
    required this.stage,
    this.code = '',
    this.customerId,
    this.customerName,
    this.value = 0,
    this.probability,
    this.product,
    this.expectedCloseAt,
    this.ownerId,
    this.ownerName,
    this.source = Channel.web,
    this.tags = const [],
    this.notes = const [],
    this.metadata = const {},
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final metadata = json.child('metadata');
    final stage = PipelineStage.parse(
      json.str('opportunity_stage') ?? json.str('pipeline'),
    );

    return Opportunity(
      id: json.strOr('id', ''),
      code: json.strOr('opportunity_code', ''),
      title: json.strOr('title', 'Cơ hội'),
      stage: stage,
      customerId: json.str('customer_id'),
      customerName: metadata.str('customer_name'),
      value: json.dbl('estimated_budget') ?? 0,
      probability: metadata['probability'] is num
          ? (metadata['probability'] as num).toInt()
          : null,
      product: metadata.str('product') ?? json.str('campaign_objective'),
      expectedCloseAt: DateUtilsX.parse(json['expected_end_date']),
      ownerId: json.str('owner_user_id'),
      ownerName: metadata.str('owner_name'),
      source: Channel.parse(metadata.str('channel') ?? metadata.str('source')),
      tags: metadata.strList('tags'),
      notes: metadata.mapList('notes').map(OpportunityNote.fromJson).toList(),
      metadata: metadata,
    );
  }

  final String id;
  final String code;
  final String title;
  final PipelineStage stage;
  final String? customerId;
  final String? customerName;
  final double value;
  final int? probability;
  final String? product;
  final DateTime? expectedCloseAt;
  final String? ownerId;
  final String? ownerName;
  final Channel source;
  final List<String> tags;
  final List<OpportunityNote> notes;

  /// The full metadata bag, kept so a patch never drops keys this app doesn't
  /// know about (the web client writes several).
  final Map<String, dynamic> metadata;

  int get effectiveProbability => probability ?? stage.defaultProbability;

  /// Value weighted by probability — what a forecast actually sums.
  double get weightedValue => value * effectiveProbability / 100;

  bool get isOverdue {
    final due = expectedCloseAt;
    if (due == null || stage.isClosed) return false;
    return due.isBefore(DateUtilsX.startOfDay(DateTime.now()));
  }

  Map<String, dynamic> toPayload() => {
        'title': title,
        if (customerId != null) 'customer_id': customerId,
        if (ownerId != null) 'owner_user_id': ownerId,
        'estimated_budget': value,
        'opportunity_stage': stage.slug,
        if (expectedCloseAt != null)
          'expected_end_date': expectedCloseAt!.toIso8601String().split('T').first,
        'metadata': {
          ...metadata,
          if (customerName != null) 'customer_name': customerName,
          if (product != null) 'product': product,
          'probability': effectiveProbability,
          'channel': source.slug,
          'tags': tags,
        },
      };

  Opportunity copyWith({
    String? title,
    PipelineStage? stage,
    String? customerId,
    String? customerName,
    double? value,
    int? probability,
    String? product,
    DateTime? expectedCloseAt,
    String? ownerId,
    List<String>? tags,
  }) {
    return Opportunity(
      id: id,
      code: code,
      title: title ?? this.title,
      stage: stage ?? this.stage,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      value: value ?? this.value,
      probability: probability ?? this.probability,
      product: product ?? this.product,
      expectedCloseAt: expectedCloseAt ?? this.expectedCloseAt,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName,
      source: source,
      tags: tags ?? this.tags,
      notes: notes,
      metadata: metadata,
    );
  }
}

/// Per-stage totals, computed server-side by `/sales-opportunities/summary`.
///
/// Server-side because summing a full pipeline client-side means fetching every
/// record — fine for a demo tenant, fatal for a real one.
class PipelineSummary {
  const PipelineSummary({this.byStage = const {}});

  factory PipelineSummary.fromJson(Map<String, dynamic> json) {
    final byStage = <PipelineStage, StageTotal>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final row = value.cast<String, dynamic>();
      byStage[PipelineStage.parse(entry.key)] = StageTotal(
        count: row.intOr('count'),
        value: row.dbl('value') ?? row.dbl('total') ?? 0,
      );
    }
    return PipelineSummary(byStage: byStage);
  }

  final Map<PipelineStage, StageTotal> byStage;

  StageTotal totalFor(PipelineStage stage) =>
      byStage[stage] ?? const StageTotal(count: 0, value: 0);

  double get openValue => PipelineStage.board
      .where((stage) => !stage.isClosed)
      .fold(0, (sum, stage) => sum + totalFor(stage).value);

  int get openCount => PipelineStage.board
      .where((stage) => !stage.isClosed)
      .fold(0, (sum, stage) => sum + totalFor(stage).count);
}

class StageTotal {
  const StageTotal({required this.count, required this.value});

  final int count;
  final double value;
}
