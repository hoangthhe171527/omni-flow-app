import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/plans/data/plan_cover_upload.dart';

void main() {
  test('URL proxy được gắn vào API hiện tại; token cũ dùng nền hệ thống', () {
    expect(resolveProjectCoverUrl(null), isNull);
    expect(resolveProjectCoverUrl('teal-1'), isNull);
    expect(resolveProjectCoverUrl('javascript:alert(1)'), isNull);
    expect(
      resolveProjectCoverUrl('/api/v1/projects/media/tenant/a.webp'),
      '${AppConfig.apiBaseUrl}/api/v1/projects/media/tenant/a.webp',
    );
    expect(
      resolveProjectCoverUrl(
        'http://api:8000/api/v1/projects/media/tenant/a.webp',
      ),
      '${AppConfig.apiBaseUrl}/api/v1/projects/media/tenant/a.webp',
    );
    expect(
      resolveProjectCoverUrl('https://cdn.example.com/a.webp'),
      'https://cdn.example.com/a.webp',
    );
  });

  test('upload/delete dùng đúng endpoint và trường multipart', () async {
    final client = _RecordingClient();
    final api = PlanCoverApi(client);

    final cover = await api.upload('p1', '/tmp/a.jpg');
    expect(cover, '/api/v1/projects/media/tenant/a.jpg');
    expect(client.uploadPath, '/projects/p1/cover');
    expect(client.field, 'cover');
    expect(client.filePath, '/tmp/a.jpg');

    await api.remove('p1');
    expect(client.deletePath, '/projects/p1/cover');
  });
}

class _RecordingClient extends ApiClient {
  _RecordingClient() : super(Dio());

  String? uploadPath;
  String? field;
  String? filePath;
  String? deletePath;

  @override
  Future<ApiEnvelope> upload(
    String path, {
    required String field,
    required String filePath,
    String? filename,
    Map<String, dynamic> fields = const {},
  }) async {
    uploadPath = path;
    this.field = field;
    this.filePath = filePath;
    return const ApiEnvelope({
      'success': true,
      'data': {'cover': '/api/v1/projects/media/tenant/a.jpg'},
    });
  }

  @override
  Future<ApiEnvelope> delete(String path, {Object? body}) async {
    deletePath = path;
    return const ApiEnvelope({'success': true, 'data': {}});
  }
}
