import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/utils/media_url.dart';

/// Coverage hoãn lại của audit run-1: ảnh/video/sticker trong tin TỰ TẢI khi
/// bong bóng hiện. Cùng lớp lỗi với xem trước link: URL đính kèm đi qua agent
/// bridge nguyên văn (`AgentBridgeConnector` chuyển `{url,type,name}`), và mọi
/// widget ảnh/video lấy URL qua [resolveMediaUrl]. URL trỏ vào mạng nội bộ của
/// máy nhân viên (hay scheme không phải web) phải thành rỗng — các widget đã
/// coi URL rỗng là "không tải được".
void main() {
  for (final url in [
    'http://127.0.0.1:8080/x.jpg',
    'http://localhost./x.jpg',
    'http://192.168.1.10/cam.jpg',
    'http://2130706433/x.jpg',
    'http://127.1/x.jpg',
    'http://169.254.169.254/latest/meta-data/x.jpg',
    'http://[::1]/x.jpg',
    'http://router/x.jpg',
    'http://user:pass@cdn.example/x.jpg',
    'file:///etc/passwd',
    'ftp://cdn.example/x.jpg',
  ]) {
    test('chặn $url', () => expect(resolveMediaUrl(url), ''));
  }

  test('CDN công khai giữ nguyên', () {
    const url = 'https://scontent.xx.fbcdn.net/v/t1/abc.jpg?oh=1';
    expect(resolveMediaUrl(url), url);
  });

  test('host của chính API được tải (máy dev dùng IP LAN)', () {
    final api = Uri.parse(AppConfig.apiBaseUrl);
    final url = api.replace(path: '/avatars/a.jpg').toString();
    expect(resolveMediaUrl(url), url);
  });

  test('đường media nội bộ vẫn dựng lại về API như cũ', () {
    expect(
      resolveMediaUrl('http://10.0.2.2/storage/inbox/t-1/x.jpg'),
      startsWith(AppConfig.apiBaseUrl),
    );
  });
}
