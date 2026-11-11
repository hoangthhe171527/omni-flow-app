import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_path.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';

import '../support/fake_http_adapter.dart';

/// Lỗi bảo mật (audit run-1, `route-path-param-unencoded-into-api-path`).
///
/// Trên bản web, link `/#/inbox/..%2F..%2Ftasks%2F1%2Fclaim%23` khớp route
/// `/inbox/:id`; go_router giải mã tham số thành `../../tasks/1/claim#`, rồi
/// `ThreadPage` tự gọi `markRead` khi mở. Id không mã hoá ghép thẳng vào
/// đường, Dio gộp `..` và cắt ở `#` — request thành `POST /api/v1/tasks/1/claim`
/// bằng phiên của nạn nhân.
void main() {
  late FakeAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = FakeAdapter(200, envelope(const {}));
    client = ApiClient(Dio()..httpClientAdapter = adapter);
  });

  group('id từ route không đổi được đường API', () {
    test(
      'markRead với id có ../ và # không thành POST /tasks/1/claim',
      () async {
        try {
          await InboxApi(client).markRead('../../tasks/1/claim#');
        } on AppException {
          // Bị chặn trước khi gửi cũng là kết quả đúng.
        }

        for (final request in adapter.requests) {
          expect(request.uri.path, isNot('/api/v1/tasks/1/claim'));
          expect(request.uri.path, startsWith('/api/v1/inbox/conversations/'));
          expect(request.uri.path, endsWith('/read'));
        }
      },
    );

    test('markRead với id có ? không cắt mất phần /read', () async {
      try {
        await InboxApi(client).markRead('../../tasks/1/claim?x=');
      } on AppException {
        // Bị chặn trước khi gửi cũng là kết quả đúng.
      }

      for (final request in adapter.requests) {
        expect(request.uri.path, isNot('/api/v1/tasks/1/claim'));
        expect(request.uri.path, endsWith('/read'));
      }
    });

    test('id có / được mã hoá thành MỘT đoạn đường', () async {
      await NotificationsApi(client).markRead('a/b');

      expect(
        adapter.requests.single.uri.path,
        '/api/v1/notifications/a%2Fb/mark-read',
      );
    });

    test('claim và xem khách với id lạ cũng mã hoá', () async {
      try {
        await TasksApi(client).claim('../../inbox/conversations/c1/convert');
      } on AppException {
        // Bị chặn trước khi gửi cũng là kết quả đúng.
      }
      try {
        await CustomersApi(client).get('../../tasks/9');
      } on AppException {
        // Bị chặn trước khi gửi cũng là kết quả đúng.
      }

      for (final request in adapter.requests) {
        expect(request.uri.path, isNot(contains('/convert')));
        expect(request.uri.path, isNot('/api/v1/tasks/9'));
      }
    });

    test('id thật (ObjectId) giữ nguyên', () async {
      await InboxApi(client).markRead('665f1c2ab4e5d1a2b3c4d5e6');

      expect(
        adapter.requests.single.uri.path,
        '/api/v1/inbox/conversations/665f1c2ab4e5d1a2b3c4d5e6/read',
      );
    });
  });

  group('pathSegment', () {
    test('mã hoá ký tự đặc biệt, giữ : và @', () {
      expect(pathSegment('abc123'), 'abc123');
      expect(pathSegment('a/b'), 'a%2Fb');
      expect(pathSegment('a#b?c'), 'a%23b%3Fc');
      expect(pathSegment('a b'), 'a%20b');
      expect(pathSegment('zalo:123@x'), 'zalo:123@x');
    });

    test('từ chối đoạn rỗng, . và ..', () {
      for (final bad in ['', '.', '..']) {
        expect(() => pathSegment(bad), throwsA(isA<AppException>()));
      }
    });
  });

  group('ApiClient chặn dot-segment', () {
    for (final path in [
      '/inbox/conversations/../../tasks/1/claim',
      '/inbox/conversations/%2e%2e/%2E%2E/tasks/1/claim',
      '/inbox/conversations/.%2e/tasks',
      '/inbox/conversations/..%2F..%2Ftasks%2F1%2Fclaim/read',
      '/inbox/./x',
    ]) {
      test(path, () async {
        await expectLater(client.post(path), throwsA(isA<AppException>()));
        expect(adapter.requests, isEmpty);
      });
    }

    test('đường bình thường vẫn đi', () async {
      await client.get('/inbox/conversations/c1.v2/messages');
      expect(
        adapter.requests.single.uri.path,
        '/api/v1/inbox/conversations/c1.v2/messages',
      );
    });
  });
}
