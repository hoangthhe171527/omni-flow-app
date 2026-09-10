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

  test('feed gửi types và since', () async {
    await api.feed(types: kFeedCompletionTypes, days: 7);

    final query = adapter.singleRequest.uri.queryParameters;

    expect(query['types'], 'subtask_completed,piano_done,attachment_added');
    expect(query['since'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('attachment_added PHẢI nằm trong danh sách xin', () async {
    // Màn hình không vẽ `attachment_added` thành một loại riêng, nên rất dễ
    // bị coi là thừa và gỡ ra. Nhưng server cần chính những dòng đó để gộp ảnh
    // vào dòng việc xong (FeedPhotoMerge). Gỡ ra thì ảnh biến mất khỏi dòng
    // việc — không lỗi, không log, chỉ là những tấm ảnh không bao giờ hiện.
    expect(kFeedCompletionTypes, contains('attachment_added'));
  });

  test('feed đọc được cờ truncated', () async {
    adapter.body = '{"success":true,"data":[],"truncated":true}';

    final feed = await api.feed();

    expect(feed.truncated, isTrue);
  });

  test('thiếu truncated thì hiểu là chưa cắt', () async {
    // Một API cũ không gửi khoá này. Mặc định phải là "chưa cắt" — hiện một
    // lời cảnh báo cắt bớt trên một danh sách đầy đủ là nói dối theo chiều
    // ngược lại.
    final feed = await api.feed();

    expect(feed.truncated, isFalse);
  });

  test('feed không gửi types khi không xin loại nào', () async {
    // Rỗng nghĩa là "mọi loại" ở phía server. Gửi `types=` rỗng là gửi một bộ
    // lọc không khớp gì.
    await api.feed();

    expect(
      adapter.singleRequest.uri.queryParameters.containsKey('types'),
      isFalse,
    );
  });

  test('createTeam gửi member_ids khi có chọn người', () async {
    // API đã nhận `member_ids` từ lâu (CreateTeamRequest, và
    // MongoTeamRepository::create ghi nó vào org unit); app chỉ chưa bao giờ
    // gửi. Một trường server sẵn sàng nhận mà client không gửi là cùng họ với
    // những lỗi im lặng khác của dự án này, chỉ khác chiều.
    await api.createTeam(name: 'Tổ phục chế', memberIds: {'u-1', 'u-2'});

    final body = adapter.singleRequest.data as Map<String, dynamic>;

    expect(body['member_ids'], containsAll(<String>['u-1', 'u-2']));
  });

  test('createTeam KHÔNG gửi member_ids khi không chọn ai', () async {
    // Gửi một mảng RỖNG và không gửi gì là hai chuyện khác nhau với một API
    // dùng `array_key_exists`.
    await api.createTeam(name: 'Tổ phục chế');

    final body = adapter.singleRequest.data as Map<String, dynamic>;

    expect(body.containsKey('member_ids'), isFalse);
  });

  test('createPlan gửi cover khi có chọn nền', () async {
    await api.createPlan(name: 'Phục chế T10', cover: 'amber-2');

    final body = adapter.singleRequest.data as Map<String, dynamic>;

    expect(body['cover'], 'amber-2');
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

  /// Thân phản hồi. Đổi được để kiểm những khoá NGOÀI `data` — `truncated`
  /// nằm ở cấp gốc, và nếu app không đọc nó thì trần 200 việc lại quay về cắt
  /// im lặng.
  String body = '{"success":true,"data":[]}';

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
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
