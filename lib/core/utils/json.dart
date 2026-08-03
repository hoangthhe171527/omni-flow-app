/// Defensive readers for the API's schema-less Mongo documents. A conversation
/// document can legitimately be missing almost any field, so mappers read
/// through these instead of casting.
extension JsonMap on Map<String, dynamic> {
  String? str(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  String strOr(String key, String fallback) => str(key) ?? fallback;

  int intOr(String key, [int fallback = 0]) {
    final value = this[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  double? dbl(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  bool flag(String key, {bool fallback = false}) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
  }

  List<String> strList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty && e != 'null')
        .toList();
  }

  List<Map<String, dynamic>> mapList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Map<String, dynamic> child(String key) {
    final value = this[key];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  Map<String, int> countMap(String key) {
    final value = this[key];
    if (value is! Map) return const {};
    return value.map(
      (k, v) => MapEntry('$k', v is num ? v.toInt() : int.tryParse('$v') ?? 0),
    );
  }
}
