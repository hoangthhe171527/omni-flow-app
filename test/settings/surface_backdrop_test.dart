import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/settings/presentation/widgets/surface_backdrop.dart';

/// Mảnh nối duy nhất giữa provider và widget vẽ: chat và bảng chỉ bọc thân
/// mình trong đây, không màn nào phải nhớ provider.
void main() {
  Widget host(String? name) => ProviderScope(
    overrides: [backgroundProvider.overrideWith(() => _Fixed(name))],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const SurfaceBackdrop(child: Text('x')),
    ),
  );

  testWidgets('đọc tên từ provider và đưa cho OmniBackdrop', (tester) async {
    await tester.pumpWidget(host('sea'));

    expect(tester.widget<OmniBackdrop>(find.byType(OmniBackdrop)).name, 'sea');
  });

  testWidgets('mặc định → OmniBackdrop nhận null (vẽ phẳng)', (tester) async {
    await tester.pumpWidget(host(null));

    expect(tester.widget<OmniBackdrop>(find.byType(OmniBackdrop)).name, isNull);
    expect(find.text('x'), findsOneWidget);
  });
}

class _Fixed extends BackgroundController {
  _Fixed(this._v);

  final String? _v;

  @override
  String? build() => _v;
}
