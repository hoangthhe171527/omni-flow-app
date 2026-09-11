import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/settings/presentation/background_page.dart';

/// Màn chọn nền: lưới ô, chạm là đổi ngay, lỗi thì nói ra.
void main() {
  late _Stub stub;

  Widget host({String? current, bool fail = false}) {
    stub = _Stub(current, fail: fail);

    return ProviderScope(
      overrides: [backgroundProvider.overrideWith(() => stub)],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const BackgroundPage(),
      ),
    );
  }

  setUp(() {
    // Cỡ điện thoại, và CAO: cửa sổ test mặc định 800×600 làm mỗi ô rộng
    // 378dp → cao 580dp, chỉ hàng đầu được dựng và tám nhãn còn lại "không
    // tồn tại". Lưới thật cuộn được; ở đây cho nó đủ chỗ để thấy hết.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(400, 1800)
      ..devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('lưới có "Mặc định" + tám nền, đúng nhãn', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Mặc định'), findsOneWidget);
    for (final n in OmniBackdrops.names) {
      expect(find.text(OmniBackdrops.labelOf(n)!), findsOneWidget);
    }
  });

  testWidgets('chạm một ô là đổi ngay, không có nút Lưu', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('Gỗ óc chó'));
    await tester.pump();

    expect(stub.sets, ['walnut']);
    expect(find.text('Lưu'), findsNothing);
  });

  testWidgets('chạm "Mặc định" gửi null', (tester) async {
    await tester.pumpWidget(host(current: 'sea'));

    await tester.tap(find.text('Mặc định'));
    await tester.pump();

    expect(stub.sets, [null]);
  });

  testWidgets('ô đang chọn được đánh dấu selected', (tester) async {
    await tester.pumpWidget(host(current: 'sea'));

    final tile = tester.getSemantics(find.bySemanticsLabel('Biển'));
    expect(tile.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('lỗi mạng thì báo, không im', (tester) async {
    await tester.pumpWidget(host(fail: true));

    await tester.tap(find.text('Nỉ búa'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mất mạng rồi'), findsOneWidget);
  });
}

class _Stub extends BackgroundController {
  _Stub(this._initial, {this.fail = false});

  final String? _initial;
  final bool fail;
  final sets = <String?>[];

  @override
  String? build() => _initial;

  @override
  Future<void> set(String? name) async {
    if (fail) throw const NetworkException('Mất mạng rồi');
    sets.add(name);
    state = name;
  }
}
