import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/api_client.dart';

/// Đổi không gian làm việc phải làm bẩn MỌI cache dữ liệu.
///
/// Vài provider giữ dữ liệu cả phiên (nhân viên, kênh, tổng quan cơ hội). Nếu
/// ApiClient không đổi theo tenant, chúng trả dữ liệu công ty cũ sau khi người
/// dùng bấm "Đổi" — một lỗi rò dữ liệu, không phải số liệu cũ.
void main() {
  test('đổi tenant thì có ApiClient mới, và provider phụ thuộc chạy lại', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var builds = 0;
    final cached = Provider<ApiClient>((ref) {
      builds++;
      return ref.watch(apiClientProvider);
    });

    container.read(activeTenantIdProvider.notifier).state = 'tenant-a';
    final first = container.read(cached);

    container.read(activeTenantIdProvider.notifier).state = 'tenant-b';
    final second = container.read(cached);

    expect(identical(first, second), isFalse);
    expect(builds, 2);
  });

  test('cùng tenant thì giữ nguyên, không tải lại vô cớ', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(activeTenantIdProvider.notifier).state = 'tenant-a';
    final first = container.read(apiClientProvider);
    container.read(activeTenantIdProvider.notifier).state = 'tenant-a';

    expect(identical(first, container.read(apiClientProvider)), isTrue);
  });
}
