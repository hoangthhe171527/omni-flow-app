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

  /// Codes [parse] knows. Anything else is a tenant-defined stage (a pipeline
  /// configured on the web, e.g. `demo_sp`) that this board folds into [fresh].
  static const knownCodes = {
    'new', 'consulted', 'quoted', 'negotiating', 'won', 'lost', //
    'LEAD', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST',
  };
}

class OpportunityNote {
  const OpportunityNote({required this.content, this.author, this.at});

  factory OpportunityNote.fromJson(
    Map<String, dynamic> json,
  ) => OpportunityNote(
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
    this.rawStage,
  });

  /// Empty draft for the create form — filled by [applyForm].
  factory Opportunity.blank() =>
      const Opportunity(id: '', title: '', stage: PipelineStage.fresh);

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final metadata = json.child('metadata');
    // `pipeline` is the pipeline's NAME (`standard`), only a stage on very old
    // records — never echo it back as a stage code.
    final rawStage = json.str('opportunity_stage');
    final stage = PipelineStage.parse(rawStage ?? json.str('pipeline'));

    return Opportunity(
      id: json.strOr('id', ''),
      code: json.strOr('opportunity_code', ''),
      title: json.strOr('title', 'Cơ hội'),
      stage: stage,
      rawStage: rawStage,
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

  /// The stage code exactly as the API sent it. [stage] folds a tenant-defined
  /// code into [PipelineStage.fresh]; writing `stage.slug` back would silently
  /// move the deal to `new`. Cleared as soon as the user picks another stage.
  final String? rawStage;

  /// What goes back to the API: the original code when it is a tenant-defined
  /// stage the user didn't change, otherwise the canonical lowercase slug
  /// (legacy UPPERCASE codes are normalised — the API only accepts lowercase).
  String get stageCode {
    final raw = rawStage;
    if (raw != null &&
        raw.isNotEmpty &&
        !PipelineStage.knownCodes.contains(raw)) {
      return raw;
    }
    return stage.slug;
  }

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
    'opportunity_stage': stageCode,
    if (expectedCloseAt != null)
      'expected_end_date': expectedCloseAt!.toIso8601String().split('T').first,
    'metadata': {
      ...metadata,
      if (customerName != null) 'customer_name': customerName,
      if (product != null) 'product': product,
      // Only a probability someone actually set. Writing the stage default
      // pins it: the deal would keep 10% after moving to "Báo giá".
      if (probability != null) 'probability': probability,
      'channel': source.slug,
      'tags': tags,
    },
  };

  /// The form's fields applied to this record — the loaded opportunity when
  /// editing ([Opportunity.blank] when creating), so everything the form
  /// doesn't show (tags, channel, notes, a tenant-defined stage) survives.
  Opportunity applyForm({
    required String title,
    required PipelineStage stage,
    required double value,
    String? customerId,
    String? customerName,
    String? product,
    DateTime? expectedCloseAt,
  }) => copyWith(
    title: title,
    stage: stage,
    value: value,
    customerId: customerId,
    customerName: customerName,
    product: product,
    expectedCloseAt: expectedCloseAt,
  );

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
      // Same stage → keep the original code; a different one → the user moved it.
      rawStage: stage == null || stage == this.stage ? rawStage : null,
    );
  }
}

/// Per-stage totals, computed server-side by `/sales-opportunities/summary`.
///
/// Server-side because summing a full pipeline client-side means fetching every
/// record — fine for a demo tenant, fatal for a real one.
class PipelineSummary {
  const PipelineSummary({this.byStage = const {}});

  /// The API sends `{total_count, value_by_stage: {stage: value},
  /// count_by_stage: {stage: count}}` (an empty map comes back as `[]`). The
  /// older per-key `{stage: {count, value}}` shape is still read as a fallback.
  factory PipelineSummary.fromJson(Map<String, dynamic> json) {
    final values = json['value_by_stage'];
    final counts = json['count_by_stage'];
    if (values is Map || values is List || counts is Map || counts is List) {
      final valueMap = values is Map ? values : const {};
      final countMap = counts is Map ? counts : const {};
      final byStage = <PipelineStage, StageTotal>{};
      for (final key in {...valueMap.keys, ...countMap.keys}) {
        // A tenant-defined stage (e.g. `demo_sp`) has no column on this board;
        // parse() would fold it into "Mới" and inflate that column.
        if (!PipelineStage.knownCodes.contains(key.toString())) continue;
        final stage = PipelineStage.parse(key.toString());
        final previous = byStage[stage] ?? const StageTotal(count: 0, value: 0);
        final value = valueMap[key];
        final count = countMap[key];
        // Legacy UPPERCASE and lowercase codes collapse onto one stage: add up.
        byStage[stage] = StageTotal(
          count: previous.count + (count is num ? count.toInt() : 0),
          value: previous.value + (value is num ? value.toDouble() : 0),
        );
      }
      return PipelineSummary(byStage: byStage);
    }

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
