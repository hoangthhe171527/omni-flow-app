import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';

/// Điểm QC, 0–5 sao (§4, §B3): hợp đồng gửi.
///
/// Phần giao diện (năm sao trong thẻ thông tin, chỉ người giao chấm, chạm lại
/// sao đang chọn là xoá) ở `task_detail_top_viec_moi_test.dart`.
void main() {
  test('gửi `rating` là SỐ, kể cả khi xoá điểm', () async {
    // 0 chứ không phải null: `UpdateTaskDTO::toAttributes` lọc bỏ đúng những
    // trường null, nên null sẽ lặng lẽ không xoá gì. Cùng cái bẫy đã gặp ở
    // `section_id` và `due_date`.
    final adapter = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));

    await api.setRating('t1', 0);

    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.uri.path, '/api/v1/tasks/t1');
    expect(adapter.requests.single.data, {'rating': 0});
  });

  test('điểm ngoài thang bị kẹp lại, không gửi lên nguyên trạng', () async {
    final adapter = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));

    await api.setRating('t1', 9);

    expect(adapter.requests.single.data, {'rating': 5});
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'id': 't1', 'title': 'x'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
