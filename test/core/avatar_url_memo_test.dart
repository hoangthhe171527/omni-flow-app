import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/utils/avatar_url.dart';

/// `resolveAvatarUrl` chạy trong `build` của mọi avatar trên màn — một danh
/// sách 30 việc với hai người mỗi việc là 60 lần parse URI, đọc cấu hình,
/// so chuỗi host, cho mỗi khung hình dựng lại. Kết quả thì không đổi: cùng
/// một URL luôn ra cùng một URL. Nhớ lại, có trần để không phình theo phiên.
void main() {
  setUp(resetAvatarUrlCache);

  test('cùng input hai lần → cùng kết quả, chuẩn hoá chạy MỘT lần', () {
    const url = 'http://localhost:8000/api/v1/inbox/avatar/a.jpg';

    final first = resolveAvatarUrl(url);
    final second = resolveAvatarUrl(url);

    expect(
      first,
      'https://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg',
    );
    expect(second, first);
    expect(avatarUrlResolveCount, 1);
  });

  test('kết quả qua bộ nhớ đệm bằng kết quả không qua', () {
    const urls = [
      'http://localhost:8000/api/v1/inbox/avatar/a.jpg',
      'http://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg?x=1',
      '/api/v1/inbox/avatar/a.jpg',
      'https://platform-lookaside.fbsbx.com/avatar.jpg',
      'http://minio/storage/avatars/a.jpg',
      'not a url at all',
    ];

    for (final url in urls) {
      expect(resolveAvatarUrl(url), resolveAvatarUrlUncached(url), reason: url);
    }
  });

  test('null và rỗng không chiếm chỗ, không đếm', () {
    expect(resolveAvatarUrl(null), isNull);
    expect(resolveAvatarUrl('   '), isNull);

    expect(avatarUrlResolveCount, 0);
    expect(avatarUrlCacheSize, 0);
  });

  test('có trần 512; cũ nhất bị đẩy ra, mới nhất còn', () {
    for (var i = 0; i < 600; i++) {
      resolveAvatarUrl('https://cdn.x/a/$i.png');
    }
    expect(avatarUrlCacheSize, 512);

    final before = avatarUrlResolveCount;
    // Cái đầu tiên đã ra khỏi đệm: phải chuẩn hoá lại.
    resolveAvatarUrl('https://cdn.x/a/0.png');
    expect(avatarUrlResolveCount, before + 1);
    // Cái mới nhất vẫn còn: không tốn thêm lần nào.
    resolveAvatarUrl('https://cdn.x/a/599.png');
    expect(avatarUrlResolveCount, before + 1);
  });
}
