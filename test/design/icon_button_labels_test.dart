import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

/// Một nút chỉ có icon mà không có tên thì screen reader đọc ra con số hoặc
/// không đọc gì. Người dùng không biết nó làm gì cho tới khi bấm thử — mà bấm
/// thử một nút không rõ chức năng là thứ không ai muốn làm.
void main() {
  testWidgets('nút xoá ô tìm kiếm xướng được tên', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Nút xoá chỉ hiện khi ô đã có chữ.
          body: OmniSearchField(initialValue: 'kawai', onChanged: (_) {}),
        ),
      ),
    );
    await tester.pump();

    // Flutter đặt tooltip vào thuộc tính `tooltip` của node ngữ nghĩa, không
    // phải `label` — nên find.bySemanticsLabel không thấy nó, dù screen reader
    // vẫn đọc. Kiểm đúng thuộc tính mà nền tảng thật sự đọc.
    expect(
      tester.getSemantics(find.byType(IconButton)).tooltip,
      'Xoá nội dung tìm',
    );
    handle.dispose();
  });

  testWidgets('nút xoá chỉ xuất hiện khi ô có chữ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OmniSearchField(onChanged: (_) {})),
      ),
    );
    await tester.pump();

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('nút hiện/ẩn mật khẩu xướng cả trạng thái', (tester) async {
    // Không chỉ "nút mật khẩu": người dùng screen reader phải biết được mật
    // khẩu của mình đang hiển thị trên màn hình hay không, và cái duy nhất nói
    // điều đó là nhãn của nút này.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _PasswordProbe())),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(IconButton)).tooltip,
      'Hiện mật khẩu',
      reason: 'đang ẩn → nút mời hiện',
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(IconButton)).tooltip,
      'Ẩn mật khẩu',
      reason:
          'đang hiện → nút mời ẩn, và đó cũng là cách người dùng biết nó đang hiện',
    );
    handle.dispose();
  });
}

/// Bản rút gọn của khối mật khẩu trong login_page và more_page.
///
/// Hai màn thật đều cần đăng nhập hoặc phiên hợp lệ mới dựng được, nên test này
/// giữ đúng phần đang được kiểm — quy tắc nhãn phải nói cả trạng thái.
class _PasswordProbe extends StatefulWidget {
  @override
  State<_PasswordProbe> createState() => _PasswordProbeState();
}

class _PasswordProbeState extends State<_PasswordProbe> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: 'Mật khẩu',
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
