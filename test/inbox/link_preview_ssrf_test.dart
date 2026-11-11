import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_link_preview.dart';

/// Lỗi bảo mật (audit run-1, `inbox-link-preview-ispreviewsafe-bypass`).
///
/// Khách chat gửi một tin có link; bong bóng tự dựng thẻ xem trước và máy
/// nhân viên tự GET link đó — không cần bấm. Bộ lọc cũ chỉ nhận ra IPv4 bốn
/// phần (`127.0.0.1`) cùng `localhost`/`.local`, nên `localhost.`, `[::1]`,
/// `http://2130706433/`, `http://127.1/`, redirect từ host "công khai" về host
/// nội bộ, và `og:image` trỏ vào mạng nội bộ đều lọt: máy nhân viên thành công
/// cụ quét mạng LAN/loopback cho người ngoài.
void main() {
  group('máy chủ thật trên loopback — đếm request thật sự rời app', () {
    late HttpServer a;
    late HttpServer b;
    late List<String> hitsA;
    late List<String> hitsB;

    setUp(() async {
      HttpOverrides.global = null;
      hitsA = [];
      hitsB = [];
      b = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      b.listen((req) {
        hitsB.add(req.uri.toString());
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html></html>')
          ..close();
      });
      // Dual-stack: nhận cả `localhost.` (IPv4) lẫn `[::1]`.
      a = await HttpServer.bind(InternetAddress.anyIPv6, 0);
      a.listen((req) {
        hitsA.add(req.uri.toString());
        if (req.uri.path == '/redirect') {
          req.response
            ..statusCode = 302
            ..headers.set('location', 'http://127.0.0.1:${b.port}/secret')
            ..close();
          return;
        }
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<html><head>'
            '<meta property="og:title" content="Trang">'
            '<meta property="og:image" content="http://127.0.0.1:${b.port}/img">'
            '</head></html>',
          )
          ..close();
      });
    });

    tearDown(() async {
      await a.close(force: true);
      await b.close(force: true);
    });

    Dio client() => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
        responseType: ResponseType.plain,
      ),
    );

    test('localhost. (dấu chấm cuối) không được GET', () async {
      await fetchLinkMetadata('http://localhost.:${a.port}/', client: client());
      expect(hitsA, isEmpty);
    });

    test('IPv6 loopback [::1] không được GET', () async {
      await fetchLinkMetadata('http://[::1]:${a.port}/', client: client());
      expect(hitsA, isEmpty);
    });

    test('redirect về host nội bộ không được theo', () async {
      await fetchLinkMetadata(
        'http://localhost.:${a.port}/redirect',
        client: client(),
      );
      expect(hitsB, isEmpty);
    });

    test('og:image trỏ vào mạng nội bộ không được dùng', () async {
      final data = await fetchLinkMetadata(
        'http://localhost.:${a.port}/',
        client: client(),
      );
      expect(data.imageUrl ?? '', isEmpty);
    });
  });

  group('bộ chuyển giả — app có GỬI request hay không', () {
    // Trình phân giải của Windows không nhận `127.1`/`2130706433`, nhưng
    // getaddrinfo của Android/iOS/Linux (inet_aton) thì có: điều cần kiểm là
    // app có gửi đi hay không, việc phân giải là của hệ điều hành.
    for (final url in [
      'http://2130706433/',
      'http://127.1/',
      'http://0x7f.0.0.1/',
      'http://0177.0.0.1/',
      'http://0.0.0.0/',
      'http://10.1/',
      'http://169.254.169.254/latest/meta-data/',
      'http://metadata.google.internal/',
      'http://router/',
      'http://printer.lan/',
      'http://[fe80::1]/',
      'http://[::ffff:192.168.1.1]/',
      'http://[fd00::1]/',
    ]) {
      test(url, () async {
        final adapter = _RecordingAdapter();
        await fetchLinkMetadata(
          url,
          client: Dio()..httpClientAdapter = adapter,
        );
        expect(adapter.requests, isEmpty);
      });
    }
  });

  group('DNS và redirect (DNS giả)', () {
    // public.example → IP công khai; rebind.example → 127.0.0.1;
    // lan.example → 10.0.0.5.
    Future<List<List<int>>?> lookup(String host) async => switch (host) {
      'public.example' || 'cdn.example' => [
        [93, 184, 216, 34],
      ],
      'rebind.example' => [
        [93, 184, 216, 34],
        [127, 0, 0, 1],
      ],
      'lan.example' => [
        [10, 0, 0, 5],
      ],
      _ => null,
    };

    Future<(LinkPreviewData, _RecordingAdapter)> run(
      String url,
      Map<String, (int, Map<String, String>, String)> routes,
    ) async {
      final adapter = _RecordingAdapter(routes);
      final data = await fetchLinkMetadata(
        url,
        client: Dio()..httpClientAdapter = adapter,
        lookup: lookup,
        allowNetwork: true,
      );
      return (data, adapter);
    }

    test('tên miền phân giải ra IP nội bộ → không GET', () async {
      final (_, adapter) = await run('https://rebind.example/', {});
      expect(adapter.requests, isEmpty);
    });

    test('không phân giải được → không GET', () async {
      final (_, adapter) = await run('https://unknown.example/', {});
      expect(adapter.requests, isEmpty);
    });

    test('redirect công khai → nội bộ: dừng, không GET bước sau', () async {
      final (_, adapter) = await run('https://public.example/a', {
        'https://public.example/a': (
          302,
          {'location': 'http://lan.example/admin'},
          '',
        ),
      });
      expect(adapter.requests.map((u) => u.toString()), [
        'https://public.example/a',
      ]);
    });

    test('redirect công khai → công khai: theo, đọc metadata', () async {
      final (data, adapter) = await run('https://public.example/a', {
        'https://public.example/a': (
          301,
          {'location': 'https://cdn.example/b'},
          '',
        ),
        'https://cdn.example/b': (
          200,
          {},
          '<meta property="og:title" content="Bài viết">'
              '<meta property="og:image" content="/anh.png">',
        ),
      });
      expect(adapter.requests, hasLength(2));
      expect(data.title, 'Bài viết');
      expect(data.imageUrl, 'https://cdn.example/anh.png');
    });

    test('og:image tên miền trỏ vào LAN → bỏ ảnh', () async {
      final (data, _) = await run('https://public.example/', {
        'https://public.example/': (
          200,
          {},
          '<meta property="og:title" content="T">'
              '<meta property="og:image" content="http://lan.example/x.png">',
        ),
      });
      expect(data.title, 'T');
      expect(data.imageUrl, isNull);
    });

    test('og:image scheme lạ → bỏ ảnh', () async {
      final (data, _) = await run('https://public.example/', {
        'https://public.example/': (
          200,
          {},
          '<meta property="og:image" content="file:///etc/passwd">',
        ),
      });
      expect(data.imageUrl, isNull);
    });

    test('quá 3 bước redirect → dừng', () async {
      final (_, adapter) = await run('https://public.example/0', {
        for (var i = 0; i < 6; i++)
          'https://public.example/$i': (302, {'location': '/${i + 1}'}, ''),
      });
      expect(adapter.requests, hasLength(4));
    });

    test('web build: không tự tải gì', () async {
      final adapter = _RecordingAdapter();
      final data = await fetchLinkMetadata(
        'https://public.example/',
        client: Dio()..httpClientAdapter = adapter,
        lookup: lookup,
        allowNetwork: false,
      );
      expect(adapter.requests, isEmpty);
      expect(data.domain, 'public.example');
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter([this.routes = const {}]);

  final Map<String, (int, Map<String, String>, String)> routes;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final route = routes[options.uri.toString()];
    if (route == null) return ResponseBody.fromString('<html></html>', 200);
    final (status, headers, body) = route;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        for (final e in headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
