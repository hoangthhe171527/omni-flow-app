import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/auth/data/auth_api.dart';
import 'package:omni_app/security/session/api_capabilities.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Hợp đồng `GET /auth/context` → `data.api_capabilities` (`omni-flow-api`
/// `App\Support\ApiCapabilities::ALL`, commit 0123621f trên
/// `feat/viec-moi-api`): danh sách chuỗi. Khoá THIẾU = API cũ = không có khả
/// năng nào (ngược với `features`, nơi thiếu = bật).
void main() {
  const me =
      '{"success":true,"data":{"user":{"id":"u1",'
      '"full_name":"Lan","email":"l@x"}}}';

  Future<Session> load(String contextData) => AuthApi(
    ApiClient(
      Dio()
        ..httpClientAdapter = _RoutedAdapter({
          '/auth/me': me,
          '/auth/context': '{"success":true,"data":$contextData}',
        }),
    ),
  ).loadContext();

  test('đọc data.api_capabilities; tên có trong danh sách mới là có', () async {
    final s = await load(
      '{"tenant":{"id":"t1","name":"X"},"permissions":[],'
      '"api_capabilities":["tasks.pin","tasks.copy",7,null]}',
    );

    expect(s.apiCapabilities, {'tasks.pin', 'tasks.copy'});
    expect(s.apiSupports(ApiCapability.taskPin), isTrue);
    expect(s.apiSupports(ApiCapability.taskCopy), isTrue);
    expect(s.apiSupports(ApiCapability.taskLock), isFalse);
  });

  test('API cũ (không có khoá) → mọi khả năng tắt', () async {
    final s = await load('{"tenant":{"id":"t1","name":"X"},"permissions":[]}');

    expect(s.apiCapabilities, isEmpty);
    for (final name in _all) {
      expect(s.apiSupports(name), isFalse, reason: name);
    }
  });

  test(
    'tên hằng khớp ĐÚNG 14 khoá app dùng (tập con của ApiCapabilities::ALL)',
    () {
      expect(_all.toSet(), {
        'tasks.pin',
        'tasks.lock',
        'tasks.follow',
        'tasks.assigned_by',
        'tasks.completed_at',
        'projects.favorite',
        'projects.transfer_owner',
        'system_options.task_labels',
        'tasks.copy',
        'tasks.reminders',
        'tasks.checklist_move',
        'tasks.subtask_fields',
        'tasks.comment_attachments',
        'tasks.copy_options',
      });
    },
  );

  test('copyWith giữ api_capabilities', () {
    const s = Session(
      status: SessionStatus.authenticated,
      apiCapabilities: {'tasks.pin'},
    );
    expect(s.copyWith().apiSupports('tasks.pin'), isTrue);
    expect(
      s.copyWith(apiCapabilities: const {}).apiSupports('tasks.pin'),
      isFalse,
    );
  });

  test('apiSupportsProvider đọc từ phiên', () {
    final c = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            apiCapabilities: {'tasks.reminders'},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(apiSupportsProvider(ApiCapability.taskReminders)), isTrue);
    expect(c.read(apiSupportsProvider(ApiCapability.taskCopy)), isFalse);
  });
}

const _all = [
  ApiCapability.taskPin,
  ApiCapability.taskLock,
  ApiCapability.taskFollow,
  ApiCapability.taskAssignedBy,
  ApiCapability.taskCompletedAt,
  ApiCapability.projectFavorite,
  ApiCapability.projectTransferOwner,
  ApiCapability.taskLabelsForReaders,
  ApiCapability.taskCopy,
  ApiCapability.taskReminders,
  ApiCapability.checklistMove,
  ApiCapability.subtaskFields,
  ApiCapability.commentAttachments,
  ApiCapability.taskCopyOptions,
];

class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter(this.routes);

  final Map<String, String> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = routes.keys.firstWhere(
      (path) => options.uri.path.endsWith(path),
      orElse: () => throw StateError('Không có route ${options.uri.path}'),
    );
    return ResponseBody.fromString(
      routes[key]!,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
