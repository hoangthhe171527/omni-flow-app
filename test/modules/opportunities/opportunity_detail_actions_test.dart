import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/presentation/opportunity_detail_page.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:dio/dio.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/team/data/team_api.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

/// Thanh hành động của chi tiết cơ hội theo trạng thái (Đợt 5, OPP-X2).
///
/// API từ chối (422) "Đánh dấu thắng" và đổi giai đoạn trên cơ hội đã HUỶ, nên
/// app không bày hai nút đó ra để người dùng bấm vào một lỗi. Cơ hội đã Thắng
/// hoặc Thua thì giống web: không còn "Đánh dấu thắng", nhưng vẫn đổi giai
/// đoạn được — đó là đường mở lại cơ hội.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeTeamApi teamApi;

  Widget host(
    String? status, {
    String stage = 'consulting',
    String? owner,
    List<TeamMember> members = const [],
  }) {
    return ProviderScope(
      overrides: [
        opportunityProvider('o1').overrideWith(
          (ref) async => Opportunity.fromJson({
            'id': 'o1',
            'title': 'Đàn KAWAI cho chị Lan',
            'opportunity_stage': stage,
            'opportunity_status': ?status,
            'expected_value': 10000000,
            'owner_user_id': ?owner,
          }),
        ),
        opportunityAccessProvider.overrideWithValue(
          const ResourceAccess(readScope: AccessScope.all, canUpdate: true),
        ),
        teamApiProvider.overrideWithValue(teamApi = _FakeTeamApi(members)),
        pipelineCatalogProvider.overrideWith(
          (ref) async => const PipelineCatalog(defaultCode: '', pipelines: []),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const OpportunityDetailPage(opportunityId: 'o1'),
      ),
    );
  }

  testWidgets('cơ hội đang mở: có cả hai nút', (tester) async {
    await tester.pumpWidget(host('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu thắng'), findsOneWidget);
    expect(find.text('Đổi giai đoạn'), findsOneWidget);
  });

  testWidgets('cơ hội đã huỷ: không còn Đánh dấu thắng lẫn Đổi giai đoạn', (
    tester,
  ) async {
    await tester.pumpWidget(host('CANCELLED'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu thắng'), findsNothing);
    expect(find.text('Đổi giai đoạn'), findsNothing);
  });

  testWidgets(
    'đã thắng / đã thua: ẩn Đánh dấu thắng, vẫn đổi giai đoạn (mở lại)',
    (tester) async {
      for (final (status, stage) in [('WON', 'won'), ('LOST', 'lost')]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(status, stage: stage));
        await tester.pumpAndSettle();

        expect(find.text('Đánh dấu thắng'), findsNothing, reason: status);
        expect(find.text('Đổi giai đoạn'), findsOneWidget, reason: status);
      }
    },
  );

  // Phụ trách là `owner_user_id`, tra tên trong danh bạ. `metadata.owner_name`
  // không ai ghi nên app luôn hiện "Chưa gán" (OPP-X7).
  testWidgets('phụ trách: tên tra theo owner_user_id', (tester) async {
    await tester.pumpWidget(
      host(
        'OPEN',
        owner: 'u1',
        members: const [
          TeamMember(membershipId: 'm1', userId: 'u1', name: 'Lan'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lan'), findsOneWidget);
    // Một cái tên — không kéo cả danh bạ (review I2).
    expect(teamApi.directoryLoads, 0);
    expect(find.text('Chưa gán'), findsNothing);
  });

  testWidgets('phụ trách không có trong danh bạ → "—", không phải Chưa gán', (
    tester,
  ) async {
    await tester.pumpWidget(host('OPEN', owner: 'u9'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa gán'), findsNothing);
  });

  testWidgets('chưa gán ai → Chưa gán', (tester) async {
    await tester.pumpWidget(host('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa gán'), findsOneWidget);
  });

  // Thắng tạo đơn; doanh thu chỉ tính khi ghi nhận thu tiền (APP-I13).
  testWidgets('hộp xác nhận Thắng nói tạo đơn, không nói tính doanh thu', (
    tester,
  ) async {
    await tester.pumpWidget(host('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đánh dấu thắng'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tạo đơn hàng'), findsOneWidget);
    expect(find.textContaining('tính vào doanh thu'), findsNothing);
  });
}

/// Tra tên theo id; đếm số lần bị kéo cả danh bạ.
class _FakeTeamApi extends TeamApi {
  _FakeTeamApi(this._members) : super(ApiClient(Dio()));

  final List<TeamMember> _members;
  int directoryLoads = 0;

  @override
  Future<List<TeamMember>> members({String? search}) async {
    directoryLoads++;
    return _members;
  }

  @override
  Future<String?> userName(String userId) async {
    for (final member in _members) {
      if (member.userId == userId) return member.name;
    }
    return null;
  }
}
