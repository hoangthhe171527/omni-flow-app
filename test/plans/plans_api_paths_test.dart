import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';

/// App gọi ĐÚNG địa chỉ nào.
///
/// Lỗ hổng mà bài này bịt: test hợp đồng đọc bản ghi từ FILE, nên nó chứng
/// minh app hiểu được hình dạng phản hồi — nhưng không hề chạm tới địa chỉ đã
/// gửi đi. `feed()` từng viết `'/feed'` thay vì `'/tasks/feed'`, gọi vào một
/// đường dẫn không tồn tại, và mọi bài kiểm vẫn xanh. Nó chỉ lộ ra khi mở app
/// thật lên và thấy màn hình báo "The route api/v1/feed could not be found."
///
/// Đây là lần thứ tư trong dự án này app đánh trượt một thứ API không phục vụ.
/// Ba lần trước là tên trường; lần này là đường dẫn.
void main() {
  late _RecordingAdapter adapter;
  late PlansApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    api = PlansApi(ApiClient(Dio()..httpClientAdapter = adapter));
  });

  String pathOf() => adapter.singleRequest.uri.path;

  test('feed gọi /tasks/feed', () async {
    await api.feed();

    expect(pathOf(), '/api/v1/tasks/feed');
  });

  test('feed mang theo limit', () async {
    await api.feed(limit: 12);

    expect(adapter.singleRequest.uri.queryParameters['limit'], '12');
  });

  test('kpi gọi /tasks/kpi', () async {
    await api.kpi();

    expect(pathOf(), '/api/v1/tasks/kpi');
  });

  test('kpi không kèm project_id khi tính cả xưởng', () async {
    // Thưởng theo TEAM chứ không theo từng dự án (§1), nên mặc định là
    // toàn tenant. Gửi kèm một project_id rỗng sẽ lọc mất gần hết.
    await api.kpi();

    expect(
      adapter.singleRequest.uri.queryParameters.containsKey('project_id'),
      isFalse,
    );
  });

  test('kpi kèm project_id khi có', () async {
    await api.kpi(planId: 'p1');

    expect(adapter.singleRequest.uri.queryParameters['project_id'], 'p1');
  });

  test('plan gọi /projects/{id}', () async {
    await api.plan('p1');

    expect(pathOf(), '/api/v1/projects/p1');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  RequestOptions get singleRequest {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    // `data` phải là mảng cho feed và object cho phần còn lại; trả về mảng
    // rỗng thì `response.object` vẫn đọc được như map rỗng.
    return ResponseBody.fromString(
      '{"success":true,"data":[]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
