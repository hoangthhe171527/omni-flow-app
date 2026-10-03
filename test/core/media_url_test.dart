import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/utils/media_url.dart';

/// URL media của Hộp thư (APP-I1).
///
/// Từ Đợt 4 khoá media có tiền tố tenant: `/api/v1/inbox/media/<tenant>/<uuid>.jpg`.
/// Hàm cũ chỉ giữ TÊN TỆP cuối khi đổi host, nên mọi ảnh mới mất `<tenant>/`
/// và trả 404 — cả ảnh trong luồng chat lẫn ảnh app gửi đi cho khách.
void main() {
  final api = Uri.parse(AppConfig.apiBaseUrl);
  String at(String path) => api.replace(path: path).toString();

  test('URL tuyệt đối có tiền tố tenant giữ nguyên <tenant>/ khi đổi host', () {
    expect(
      resolveMediaUrl('https://api.khac.vn/api/v1/inbox/media/t-123/abc.jpg'),
      at('/api/v1/inbox/media/t-123/abc.jpg'),
    );
  });

  test('khoá cũ một tầng vẫn dựng đúng', () {
    expect(
      resolveMediaUrl('https://api.khac.vn/api/v1/inbox/media/abc.jpg'),
      at('/api/v1/inbox/media/abc.jpg'),
    );
    expect(
      resolveMediaUrl('http://10.0.2.2/storage/inbox/cu.jpg'),
      at('/api/v1/inbox/media/cu.jpg'),
    );
  });

  test('đường tương đối có tenant giữ nguyên', () {
    expect(
      resolveMediaUrl('/api/v1/inbox/media/t-1/x.png'),
      at('/api/v1/inbox/media/t-1/x.png'),
    );
  });

  test(
    'gọi hai lần cho cùng kết quả (bong bóng tạm vẽ qua resolve lần nữa)',
    () {
      final once = resolveMediaUrl(
        'https://api.khac.vn/api/v1/inbox/media/t-1/x.png',
      );
      expect(resolveMediaUrl(once), once);
    },
  );

  test('URL CDN công khai không đổi', () {
    const cdn = 'https://cdn.example.com/bucket/inbox/t-1/x.png';
    expect(resolveMediaUrl(cdn), cdn);
  });

  test('chặn ..', () {
    expect(
      resolveMediaUrl('https://h/api/v1/inbox/media/../../etc/passwd'),
      isNot(contains('..')),
    );
    expect(
      resolveMediaUrl('https://h/api/v1/inbox/media/t-1/../../x'),
      isNot(contains('..')),
    );
  });
}
