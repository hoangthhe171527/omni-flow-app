import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Một request đã được giải mã cho handler demo.
class DemoRequest {
  DemoRequest({
    required this.method,
    required this.path,
    required this.params,
    required this.query,
    required this.body,
  });

  /// `GET`, `POST`, … (chữ hoa).
  final String method;

  /// Đường dẫn sau `/api/v1`, ví dụ `/customers/c-1`.
  final String path;

  /// Tham số lấy từ mẫu `{id}` của route.
  final Map<String, String> params;

  final Map<String, dynamic> query;

  /// JSON đã giải mã (Map/List), hoặc `Map` các trường chữ nếu là multipart,
  /// hoặc null.
  final Object? body;

  Map<String, dynamic> get json =>
      body is Map ? Map<String, dynamic>.from(body as Map) : const {};

  String? q(String key) {
    final v = query[key];
    if (v == null) return null;
    final s = v is List ? (v.isEmpty ? '' : '${v.first}') : '$v';
    return s.isEmpty ? null : s;
  }

  int qInt(String key, int fallback) => int.tryParse(q(key) ?? '') ?? fallback;
}

/// Kết quả handler: mã HTTP + thân JSON.
class DemoResponse {
  const DemoResponse(this.status, [this.json]);

  final int status;
  final Object? json;
}

/// `{success: true, data: …}` (+ `pagination` nếu có).
DemoResponse ok(Object? data, {Map<String, dynamic>? pagination}) =>
    DemoResponse(200, {
      'success': true,
      'data': data,
      'pagination': ?pagination,
    });

DemoResponse created(Object? data) =>
    DemoResponse(201, {'success': true, 'data': data});

const DemoResponse noContent = DemoResponse(204);

DemoResponse notFound([String message = 'Không tìm thấy.']) =>
    DemoResponse(404, {'success': false, 'message': message});

DemoResponse unprocessable(String message) =>
    DemoResponse(422, {'success': false, 'message': message});

/// Cắt trang kiểu `page`/`per_page` và trả envelope có `pagination` giống API.
DemoResponse paged(
  DemoRequest req,
  List<Map<String, dynamic>> items, {
  int defaultPerPage = 20,
}) {
  final perPage = req.qInt('per_page', defaultPerPage).clamp(1, 200);
  final page = req.qInt('page', 1).clamp(1, 100000);
  final total = items.length;
  final lastPage = total == 0 ? 1 : ((total - 1) ~/ perPage) + 1;
  final start = (page - 1) * perPage;
  final slice = start >= total
      ? <Map<String, dynamic>>[]
      : items.sublist(start, (start + perPage).clamp(0, total));
  return ok(
    slice,
    pagination: {
      'current_page': page,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
      'has_more': page < lastPage,
    },
  );
}

typedef DemoHandler = FutureOr<DemoResponse> Function(DemoRequest req);

class _Route {
  _Route(this.method, String pattern, this.handler)
    : segments = pattern.split('/').where((s) => s.isNotEmpty).toList();

  final String method;
  final List<String> segments;
  final DemoHandler handler;

  Map<String, String>? match(List<String> path) {
    if (path.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.startsWith('{') && s.endsWith('}')) {
        params[s.substring(1, s.length - 1)] = Uri.decodeComponent(path[i]);
      } else if (s != path[i]) {
        return null;
      }
    }
    return params;
  }
}

/// Bảng route của máy chủ demo. Mẫu là đường dẫn sau `/api/v1`, đoạn `{tên}`
/// khớp một đoạn bất kỳ: `/customers/{id}`.
class DemoRoutes {
  final List<_Route> _routes = [];

  void get(String pattern, DemoHandler h) => _add('GET', pattern, h);
  void post(String pattern, DemoHandler h) => _add('POST', pattern, h);
  void put(String pattern, DemoHandler h) => _add('PUT', pattern, h);
  void patch(String pattern, DemoHandler h) => _add('PATCH', pattern, h);
  void delete(String pattern, DemoHandler h) => _add('DELETE', pattern, h);

  void _add(String method, String pattern, DemoHandler h) =>
      _routes.add(_Route(method, pattern, h));

  Future<DemoResponse> handle(DemoRequest req) async {
    final segs = req.path.split('/').where((s) => s.isNotEmpty).toList();
    for (final route in _routes) {
      if (route.method != req.method) continue;
      final params = route.match(segs);
      if (params == null) continue;
      return route.handler(
        DemoRequest(
          method: req.method,
          path: req.path,
          params: params,
          query: req.query,
          body: req.body,
        ),
      );
    }
    // Chưa có dữ liệu mẫu cho đường này: đọc thì trả rỗng, ghi thì giả như
    // thành công — bản demo không được hiện lỗi máy chủ cho người kiểm thử.
    if (kDebugMode) {
      debugPrint('[demo] chưa có route: ${req.method} ${req.path}');
    }
    return req.method == 'GET'
        ? ok(const <Object>[])
        : ok(const <String, Object>{});
  }
}

/// Dio adapter thay mạng thật bằng [DemoRoutes] trong bộ nhớ.
class DemoApiAdapter implements HttpClientAdapter {
  DemoApiAdapter(
    this.routes, {
    this.prefix = '/api/v1',
    this.latency = const Duration(milliseconds: 180),
  });

  final DemoRoutes routes;
  final String prefix;
  final Duration latency;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    var path = options.uri.path;
    final at = path.indexOf(prefix);
    if (at >= 0) path = path.substring(at + prefix.length);

    final response = await routes.handle(
      DemoRequest(
        method: options.method.toUpperCase(),
        path: path,
        params: const {},
        query: options.uri.queryParametersAll.map(
          (k, v) => MapEntry(
            k.endsWith('[]') ? k.substring(0, k.length - 2) : k,
            v.length == 1 && !k.endsWith('[]') ? v.first : v,
          ),
        ),
        body: _decodeBody(options.data),
      ),
    );

    final bytes = response.json == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(jsonEncode(response.json)));
    return ResponseBody.fromBytes(
      bytes,
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Object? _decodeBody(Object? data) {
    if (data == null) return null;
    if (data is FormData) {
      return {
        for (final f in data.fields) f.key: f.value,
        for (final f in data.files) f.key: f.value.filename ?? 'tep',
      };
    }
    if (data is Map || data is List) return data;
    if (data is String) {
      try {
        return jsonDecode(data);
      } on FormatException {
        return data;
      }
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}
