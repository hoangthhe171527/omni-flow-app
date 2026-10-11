import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/team/data/team_api.dart';
import 'package:omni_app/modules/team/team.dart';

class _GatedTeamApi extends TeamApi {
  _GatedTeamApi(this.gates) : super(ApiClient(Dio()));

  final List<Completer<List<TeamMember>>> gates;

  @override
  Future<List<TeamMember>> members({String? search}) {
    final gate = Completer<List<TeamMember>>();
    gates.add(gate);
    return gate.future;
  }
}

/// Cờ "danh bạ đã nạp" (tên người thả cảm xúc trong hội thoại) theo tenant.
void main() {
  late List<Completer<List<TeamMember>>> gates;
  late ProviderContainer container;

  setUp(() {
    gates = [];
    container = ProviderContainer(
      overrides: [
        // Như bản thật: client (và mọi API) dựng MỚI khi đổi tenant.
        teamApiProvider.overrideWith((ref) {
          ref.watch(activeTenantIdProvider);
          return _GatedTeamApi(gates);
        }),
      ],
    );
    container.read(activeTenantIdProvider.notifier).state = 't1';
    addTearDown(container.dispose);
  });

  test('nạp xong → bật; đổi tenant → tắt lại', () async {
    container.listen(teamDirectoryProvider, (_, _) {});
    gates.last.complete(const []);
    await container.read(teamDirectoryProvider.future);
    expect(container.read(teamDirectoryLoadedProvider), isTrue);

    container.read(activeTenantIdProvider.notifier).state = 't2';
    expect(container.read(teamDirectoryLoadedProvider), isFalse);
  });

  test(
    'lượt nạp của tenant CŨ về sau khi đã đổi tenant → không bật cờ',
    () async {
      container.listen(teamDirectoryProvider, (_, _) {});
      final stale = gates.last;

      container.read(activeTenantIdProvider.notifier).state = 't2';
      container.read(teamDirectoryProvider); // dựng lại cho t2 (đang chờ)
      stale.complete(const []);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(teamDirectoryLoadedProvider), isFalse);

      gates.last.complete(const []);
      await container.read(teamDirectoryProvider.future);
      expect(container.read(teamDirectoryLoadedProvider), isTrue);
    },
  );
}
