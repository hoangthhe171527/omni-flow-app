import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/tokens/omni_covers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';

void main() {
  late _Recorder recorder;
  late PlansApi api;

  setUp(() {
    recorder = _Recorder();
    api = PlansApi(ApiClient(Dio()..httpClientAdapter = recorder));
  });

  test('updateTeam gọi PUT /teams/{id}, trim tên và đọc phản hồi', () async {
    final team = await api.updateTeam('team-1', name: '  Tổ hoàn thiện  ');

    expect(recorder.single.method, 'PUT');
    expect(recorder.single.uri.path, '/api/v1/teams/team-1');
    expect(recorder.single.data, {'name': 'Tổ hoàn thiện'});
    expect(team.id, 'team-1');
    expect(team.name, 'Tổ hoàn thiện');
  });

  test('updateTeam chặn tên chỉ có khoảng trắng trước khi gọi mạng', () async {
    await expectLater(
      api.updateTeam('team-1', name: '   '),
      throwsA(isA<ArgumentError>()),
    );
    expect(recorder.requests, isEmpty);
  });

  test('PlanPatch.cover chỉ nhận token nền cũ', () {
    expect(PlanPatch(cover: OmniCovers.names.last).toJson(), {
      'cover': OmniCovers.names.last,
    });
    expect(
      () => PlanPatch(cover: '/api/v1/projects/media/tenant/p1.webp'),
      throwsAssertionError,
    );
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  RequestOptions get single {
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
    final name = switch (options.data) {
      final Map<String, dynamic> body => body['name'],
      final String encoded =>
        (jsonDecode(encoded) as Map<String, dynamic>)['name'],
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'id': 'team-1', 'name': name ?? 'Team'},
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
