/// omnicrm-pro-api answers every endpoint with the same envelope:
/// `{ success, data, pagination?, message? }`.
class ApiEnvelope {
  const ApiEnvelope(this.raw);

  final Map<String, dynamic> raw;

  bool get success => raw['success'] == true;

  String? get message => raw['message'] as String?;

  dynamic get data => raw['data'];

  Map<String, dynamic> get object {
    final value = raw['data'];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  List<Map<String, dynamic>> get list {
    final value = raw['data'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  ApiPagination? get pagination {
    final value = raw['pagination'];
    if (value is! Map) return null;
    return ApiPagination.fromJson(value.cast<String, dynamic>());
  }

  /// Cursor pagination — used only by the chat thread (`/inbox/.../messages`).
  CursorPage? get cursor {
    final value = raw['pagination'];
    if (value is! Map || !value.containsKey('has_more')) return null;
    return CursorPage.fromJson(value.cast<String, dynamic>());
  }
}

class ApiPagination {
  const ApiPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory ApiPagination.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
    return ApiPagination(
      currentPage: asInt(json['current_page'], 1),
      lastPage: asInt(json['last_page'], 1),
      perPage: asInt(json['per_page'], 0),
      total: asInt(json['total'], 0),
    );
  }

  const ApiPagination.empty()
    : currentPage = 1,
      lastPage = 1,
      perPage = 0,
      total = 0;

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  int get nextPage => currentPage + 1;
}

class CursorPage {
  const CursorPage({
    required this.perPage,
    required this.hasMore,
    required this.nextBefore,
  });

  factory CursorPage.fromJson(Map<String, dynamic> json) => CursorPage(
    perPage: (json['per_page'] as num?)?.toInt() ?? 0,
    hasMore: json['has_more'] == true,
    nextBefore: json['next_before'] as String?,
  );

  const CursorPage.empty() : perPage = 0, hasMore = false, nextBefore = null;

  final int perPage;
  final bool hasMore;
  final String? nextBefore;
}

/// A page of already-mapped domain models.
class Paged<T> {
  const Paged({required this.items, required this.pagination});

  const Paged.empty()
    : items = const [],
      pagination = const ApiPagination.empty();

  final List<T> items;
  final ApiPagination pagination;

  bool get hasMore => pagination.hasMore;
}
