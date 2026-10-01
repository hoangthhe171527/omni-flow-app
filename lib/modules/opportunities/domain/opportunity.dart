import 'package:flutter/foundation.dart';

import '../../../core/domain/channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import 'pipeline_catalog.dart';

/// The six stages of the server's built-in `standard` pipeline.
///
/// Only a compatibility vocabulary now: the board, picker and form read the
/// tenant's real stages from [PipelineCatalog], and [Opportunity.stageCode]
/// carries the raw code. A tenant-defined code has NO member here — [parse]
/// folds it into [fresh], so never write [slug] back for a record you read.
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

  /// Default probability when neither the record nor its pipeline carries one.
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

  /// Codes [parse] knows.
  static const knownCodes = {
    'new', 'consulted', 'quoted', 'negotiating', 'won', 'lost', //
    'LEAD', 'QUALIFIED', 'PROPOSAL', 'NEGOTIATION', 'WON', 'LOST',
  };

  /// A legacy UPPERCASE code mapped to its lowercase slug (the API only accepts
  /// lowercase on write); any other code — canonical or tenant-defined — as is.
  static String canonicalCode(String raw) =>
      knownCodes.contains(raw) ? parse(raw).slug : raw;
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
    required this.stageCode,
    this.pipelineCode,
    this.status,
    this.outcome,
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
    this.loadedMetadata = const {},
  });

  /// Empty draft for the create form — filled by [applyForm]. An empty
  /// [stageCode] is not sent, and the server picks the pipeline's first stage.
  factory Opportunity.blank() =>
      const Opportunity(id: '', title: '', stageCode: '');

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final metadata = json.child('metadata');
    final customerName =
        json.str('customer_name') ?? metadata.str('customer_name');
    final product = metadata.str('product') ?? json.str('campaign_objective');
    final probability = metadata['probability'] is num
        ? (metadata['probability'] as num).toInt()
        : null;
    final source = Channel.parse(
      metadata.str('channel') ?? metadata.str('source'),
    );
    final tags = metadata.strList('tags');
    final outcome = json.str('outcome');

    return Opportunity(
      id: json.strOr('id', ''),
      code: json.strOr('opportunity_code', ''),
      title: json.strOr('title', 'Cơ hội'),
      stageCode: PipelineStage.canonicalCode(
        json.str('opportunity_stage') ?? '',
      ),
      pipelineCode: json.str('pipeline')?.toLowerCase(),
      status: json.str('opportunity_status')?.toUpperCase(),
      outcome: outcome == null ? null : StageOutcome.parse(outcome),
      customerId: json.str('customer_id'),
      customerName: customerName,
      value: json.dbl('estimated_budget') ?? 0,
      probability: probability,
      product: product,
      expectedCloseAt: DateUtilsX.parse(json['expected_end_date']),
      ownerId: json.str('owner_user_id'),
      ownerName: metadata.str('owner_name'),
      source: source,
      tags: tags,
      notes: metadata.mapList('notes').map(OpportunityNote.fromJson).toList(),
      metadata: metadata,
      loadedMetadata: _ownMetadata(
        customerName: customerName,
        product: product,
        probability: probability,
        source: source,
        tags: tags,
      ),
    );
  }

  final String id;
  final String code;
  final String title;

  /// The stage code exactly as the server stores it (`da_mua`, `quoted`…),
  /// legacy UPPERCASE codes normalised. Empty only on a fresh draft.
  final String stageCode;

  /// `pipeline` of the record; null = the tenant's default pipeline.
  final String? pipelineCode;

  /// `opportunity_status`: OPEN / WON / LOST / CANCELLED. The server derives it
  /// from the stage's outcome in the record's pipeline — the source of truth
  /// for "is this deal closed".
  final String? status;

  /// `outcome` of the stage in its pipeline (only `SalesOpportunityResource`
  /// sends it; null when the code is not in the pipeline).
  final StageOutcome? outcome;

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

  /// The full metadata bag as loaded. Read-only here: the app never echoes it
  /// back (see [toPayload]).
  final Map<String, dynamic> metadata;

  /// The metadata keys this app writes, as they were when the record was
  /// loaded — what [toPayload] diffs against.
  final Map<String, dynamic> loadedMetadata;

  /// Compatibility view of [stageCode]; a tenant-defined code reads as
  /// [PipelineStage.fresh]. Display code uses the [PipelineCatalog].
  PipelineStage get stage => PipelineStage.parse(stageCode);

  /// Closed = won, lost or cancelled — by `opportunity_status`, then the
  /// stage's `outcome`, and only for a record carrying neither, by the code.
  bool get isClosed {
    if (status case final s?) return s != 'OPEN';
    if (outcome case final o?) return o != StageOutcome.open;
    return PipelineStage.knownCodes.contains(stageCode) && stage.isClosed;
  }

  bool get isWon {
    if (status case final s?) return s == 'WON';
    if (outcome case final o?) return o == StageOutcome.won;
    return stageCode == 'won';
  }

  /// The probability someone set on the record, else the stage's default in
  /// [pipeline], else the built-in funnel default.
  int effectiveProbability([PipelineDef? pipeline]) =>
      probability ??
      pipeline?.stage(stageCode)?.probability ??
      stage.defaultProbability;

  /// Value weighted by probability — what a forecast actually sums.
  double weightedValue([PipelineDef? pipeline]) =>
      value * effectiveProbability(pipeline) / 100;

  bool get isOverdue {
    final due = expectedCloseAt;
    if (due == null || isClosed) return false;
    return due.isBefore(DateUtilsX.startOfDay(DateTime.now()));
  }

  /// `PUT`/`POST` body.
  ///
  /// `metadata`: the API merges it SHALLOWLY into what is stored
  /// (`UpdateSalesOpportunity` → `MetadataPatch::merge`: a key sent overwrites,
  /// a key sent as null is removed, a key not sent is kept). So only the keys
  /// this app changed since loading go out. Echoing the whole bag would write
  /// back the copy the app is holding — overwriting whatever the web changed
  /// in the meantime (`lost_reason`, `notes`, `source`…).
  ///
  /// `pipeline` goes with the stage when the record has one, so the server
  /// checks the code against that pipeline instead of guessing.
  Map<String, dynamic> toPayload() {
    final own = _ownMetadata(
      customerName: customerName,
      product: product,
      probability: probability,
      source: source,
      tags: tags,
    );
    final changed = <String, dynamic>{
      for (final entry in own.entries)
        if (!_sameValue(entry.value, loadedMetadata[entry.key]))
          entry.key: entry.value,
    };

    return {
      'title': title,
      if (customerId != null) 'customer_id': customerId,
      if (ownerId != null) 'owner_user_id': ownerId,
      'estimated_budget': value,
      if (stageCode.isNotEmpty) 'opportunity_stage': stageCode,
      if (pipelineCode != null) 'pipeline': pipelineCode,
      if (expectedCloseAt != null)
        'expected_end_date': expectedCloseAt!
            .toIso8601String()
            .split('T')
            .first,
      if (changed.isNotEmpty) 'metadata': changed,
    };
  }

  /// The form's fields applied to this record — the loaded opportunity when
  /// editing ([Opportunity.blank] when creating), so everything the form
  /// doesn't show (tags, channel, notes, the pipeline) survives.
  Opportunity applyForm({
    required String title,
    required String stageCode,
    required double value,
    String? customerId,
    String? customerName,
    String? product,
    DateTime? expectedCloseAt,
  }) => copyWith(
    title: title,
    stageCode: stageCode,
    value: value,
    customerId: customerId,
    customerName: customerName,
    product: product,
    expectedCloseAt: expectedCloseAt,
  );

  Opportunity copyWith({
    String? title,
    String? stageCode,
    String? pipelineCode,
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
      stageCode: stageCode ?? this.stageCode,
      pipelineCode: pipelineCode ?? this.pipelineCode,
      status: status,
      outcome: outcome,
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
      loadedMetadata: loadedMetadata,
    );
  }

  /// The metadata keys this app owns. `channel` stays the app's key for the
  /// source; the web reads it as a fallback for `source`.
  static Map<String, dynamic> _ownMetadata({
    required String? customerName,
    required String? product,
    required int? probability,
    required Channel source,
    required List<String> tags,
  }) => {
    'customer_name': ?customerName,
    'product': ?product,
    // Only a probability someone actually set. Writing the stage default
    // pins it: the deal would keep 10% after moving to "Báo giá".
    'probability': ?probability,
    'channel': source.slug,
    'tags': tags,
  };

  static bool _sameValue(Object? a, Object? b) =>
      a is List && b is List ? listEquals(a, b) : a == b;
}

/// Per-stage totals, computed server-side by `/sales-opportunities/summary`.
///
/// Server-side because summing a full pipeline client-side means fetching every
/// record — fine for a demo tenant, fatal for a real one.
class PipelineSummary {
  const PipelineSummary({this.byCode = const {}});

  /// The API sends `{total_count, value_by_stage: {stage: value},
  /// count_by_stage: {stage: count}}` (an empty map comes back as `[]`). The
  /// older per-key `{stage: {count, value}}` shape is still read as a fallback.
  ///
  /// EVERY code is kept — a tenant-defined stage (`da_mua`) is a real column.
  /// Legacy UPPERCASE codes add up onto their lowercase slug.
  factory PipelineSummary.fromJson(Map<String, dynamic> json) {
    final byCode = <String, StageTotal>{};
    void add(String rawCode, num? count, num? value) {
      final code = PipelineStage.canonicalCode(rawCode);
      final previous = byCode[code] ?? const StageTotal(count: 0, value: 0);
      byCode[code] = StageTotal(
        count: previous.count + (count?.toInt() ?? 0),
        value: previous.value + (value?.toDouble() ?? 0),
      );
    }

    final values = json['value_by_stage'];
    final counts = json['count_by_stage'];
    if (values is Map || values is List || counts is Map || counts is List) {
      final valueMap = values is Map ? values : const {};
      final countMap = counts is Map ? counts : const {};
      for (final key in {...valueMap.keys, ...countMap.keys}) {
        final value = valueMap[key];
        final count = countMap[key];
        add(
          key.toString(),
          count is num ? count : null,
          value is num ? value : null,
        );
      }
      return PipelineSummary(byCode: byCode);
    }

    for (final entry in json.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final row = value.cast<String, dynamic>();
      add(entry.key, row.intOr('count'), row.dbl('value') ?? row.dbl('total'));
    }
    return PipelineSummary(byCode: byCode);
  }

  final Map<String, StageTotal> byCode;

  StageTotal totalFor(String code) =>
      byCode[code] ?? const StageTotal(count: 0, value: 0);

  double openValue(PipelineDef pipeline) => pipeline.openStages.fold(
    0,
    (sum, stage) => sum + totalFor(stage.code).value,
  );

  int openCount(PipelineDef pipeline) => pipeline.openStages.fold(
    0,
    (sum, stage) => sum + totalFor(stage.code).count,
  );
}

class StageTotal {
  const StageTotal({required this.count, required this.value});

  final int count;
  final double value;
}
