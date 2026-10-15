import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/utils/avatar_url.dart';

void main() {
  test('rebases a localhost mirrored avatar onto the configured HTTPS API', () {
    expect(
      resolveAvatarUrl('http://localhost:8000/api/v1/inbox/avatar/a.jpg'),
      'https://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg',
    );
  });

  test('upgrades an avatar proxy URL using the API host to HTTPS', () {
    expect(
      resolveAvatarUrl(
        'http://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg?x=1',
      ),
      'https://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg?x=1',
    );
  });

  test('rebases a relative avatar proxy URL for Flutter NetworkImage', () {
    expect(
      resolveAvatarUrl('/api/v1/inbox/avatar/a.jpg'),
      'https://omni-api.app.sunriseieco.vn/api/v1/inbox/avatar/a.jpg',
    );
  });

  test('rebases the self-avatar route returned by auth', () {
    expect(
      resolveAvatarUrl('http://app:8000/api/v1/auth/avatar/me.jpg'),
      'https://omni-api.app.sunriseieco.vn/api/v1/auth/avatar/me.jpg',
    );
    expect(
      resolveAvatarUrl('/api/v1/auth/avatar/me.jpg'),
      'https://omni-api.app.sunriseieco.vn/api/v1/auth/avatar/me.jpg',
    );
  });

  test('keeps a platform CDN avatar unchanged', () {
    const url = 'https://platform-lookaside.fbsbx.com/avatar.jpg';
    expect(resolveAvatarUrl(url), url);
  });

  test('rebases legacy storage avatars through the public API proxy', () {
    expect(
      resolveAvatarUrl('http://minio/storage/avatars/a.jpg'),
      'https://omni-api.app.sunriseieco.vn/api/v1/auth/avatar/a.jpg',
    );
  });
}
