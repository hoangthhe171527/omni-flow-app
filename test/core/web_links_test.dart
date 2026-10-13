import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/env.dart';
import 'package:omni_app/core/config/web_links.dart';

/// URL web gốc (`WEB_BASE_URL`) và liên kết khớp route web `omni-flow`:
/// việc mở ở `/projects/my-work?task=<id>` (`_app.projects.my-work.tsx`), kế
/// hoạch ở `/projects/<id>` (`_app.projects.$projectId.tsx`).
void main() {
  tearDown(() {
    dotenv.testLoad(fileInput: '');
  });

  test('không có .env: dùng URL web mặc định', () {
    expect(Env.defaultWebBaseUrl, 'https://omni.app.sunriseieco.vn');
    dotenv.testLoad(fileInput: '');
    expect(Env.webBaseUrl, 'https://omni.app.sunriseieco.vn');
  });

  test('.env ghi đè, bỏ "/" cuối', () {
    dotenv.testLoad(fileInput: 'WEB_BASE_URL=https://web.example.vn/\n');
    expect(Env.webBaseUrl, 'https://web.example.vn');
  });

  test('.env để trống: về mặc định web, không lẫn sang URL API', () {
    dotenv.testLoad(fileInput: 'WEB_BASE_URL=   \n');
    expect(Env.webBaseUrl, Env.defaultWebBaseUrl);
  });

  test('liên kết việc khớp route web my-work, mã hoá id', () {
    dotenv.testLoad(fileInput: '');
    expect(
      WebLinks.task('t1'),
      'https://omni.app.sunriseieco.vn/projects/my-work?task=t1',
    );
    expect(
      WebLinks.task('a b&c'),
      'https://omni.app.sunriseieco.vn/projects/my-work?task=a%20b%26c',
    );
  });

  test('liên kết kế hoạch khớp route web /projects/<id>', () {
    dotenv.testLoad(fileInput: 'WEB_BASE_URL=https://web.example.vn\n');
    expect(WebLinks.plan('p1'), 'https://web.example.vn/projects/p1');
    expect(WebLinks.plan('a/b'), 'https://web.example.vn/projects/a%2Fb');
  });
}
