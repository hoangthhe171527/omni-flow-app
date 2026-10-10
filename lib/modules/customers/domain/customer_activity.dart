import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

enum ActivityKind {
  message,
  call,
  order,
  task,
  note,
  other;

  /// `interaction_type` của `InteractionType` (omni-flow-api).
  static ActivityKind fromType(String? type) => switch (type) {
    'MESSAGE' || 'CHAT' || 'EMAIL' => ActivityKind.message,
    'CALL' || 'MEETING' => ActivityKind.call,
    'QUOTATION' => ActivityKind.order,
    'FOLLOW_UP' || 'ASSIGNMENT' => ActivityKind.task,
    'NOTE' => ActivityKind.note,
    _ => ActivityKind.other,
  };
}

/// Một dòng `GET /interaction-logs` (`InteractionLogDTO::toArray`).
class CustomerActivity {
  const CustomerActivity({
    required this.id,
    required this.kind,
    required this.text,
    this.at,
  });

  final String id;
  final ActivityKind kind;
  final String text;
  final DateTime? at;

  factory CustomerActivity.fromJson(Map<String, dynamic> json) {
    return CustomerActivity(
      id: json.strOr('id', ''),
      kind: ActivityKind.fromType(json.str('interaction_type')),
      text: json.strOr('content', ''),
      at:
          DateUtilsX.parse(json['interacted_at']) ??
          DateUtilsX.parse(json['created_at']),
    );
  }
}
