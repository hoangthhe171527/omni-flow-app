import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/channels_module.dart';
import 'package:omni_app/modules/channels/domain/channel_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Màn kết nối kênh phải xuất hiện đúng theo quyền, và không bao giờ chiếm tab.
///
/// Nó là màn thao tác một lần rồi thôi. Cho nó một tab là lấy chỗ của màn dùng
/// hàng ngày; giấu nó khỏi người có quyền là khiến họ tưởng app thiếu chức năng.
ProviderContainer _containerFor(Set<String> permissions) {
  return ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(appModules),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy(permissions),
        ),
      ),
    ],
  );
}

List<String> _menuLabels(ProviderContainer container) => container
    .read(directoryGroupsProvider)
    .values
    .expand((entries) => entries)
    .map((entry) => entry.label)
    .toList();

void main() {
  test('người có channels.read thấy mục Kênh kết nối', () {
    final container = _containerFor({ChannelPermissions.read});
    addTearDown(container.dispose);

    expect(_menuLabels(container), contains('Kênh kết nối'));
  });

  test('nhân viên chỉ có channels.read.own vẫn vào được', () {
    final container = _containerFor({ChannelPermissions.readOwn});
    addTearDown(container.dispose);

    expect(_menuLabels(container), contains('Kênh kết nối'));
  });

  test('không có quyền kênh thì không thấy mục nào', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    expect(_menuLabels(container), isNot(contains('Kênh kết nối')));
  });

  test('mục này nằm trong nhóm Hộp thư để dễ tìm từ mobile', () {
    final container = _containerFor({ChannelPermissions.read});
    addTearDown(container.dispose);

    final group =
        container.read(directoryGroupsProvider)[NavArea.communication] ?? [];
    expect(group.map((e) => e.label), contains('Kênh kết nối'));
  });

  test('kênh không chiếm tab dưới', () {
    final container = _containerFor(ChannelPermissions.all.toSet());
    addTearDown(container.dispose);

    final labels = container
        .read(primaryNavEntriesProvider)
        .map((e) => e.label);
    expect(labels, isNot(contains('Kênh kết nối')));
  });

  test('mục Kênh kết nối mang huy hiệu lỗi kênh, giọng cảnh báo', () {
    final entry = const ChannelsModule().navEntries().single;

    expect(entry.badge, same(channelErrorCountProvider));
    expect(entry.badgeTone, NavBadgeTone.alert);
  });
}
