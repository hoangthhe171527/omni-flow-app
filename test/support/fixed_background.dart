import 'package:omni_app/modules/settings/application/appearance_providers.dart';

/// Nền cố định cho test dựng màn chat / bảng dự án.
///
/// `backgroundProvider` thật đọc phiên và SharedPreferences — hai thứ một bài
/// kiểm màn hình không có. Không override là `sharedPreferencesProvider must
/// be overridden` ngay lúc dựng `SurfaceBackdrop`.
class FixedBackground extends BackgroundController {
  FixedBackground([this.value]);

  final String? value;

  @override
  String? build() => value;

  @override
  Future<void> set(String? name) async => state = name;
}
