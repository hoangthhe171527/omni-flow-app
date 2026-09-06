import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/application/tasks_providers.dart';
import '../data/plans_api.dart';
import '../domain/feed_entry.dart';
import '../domain/plan.dart';
import '../domain/workshop_kpi.dart';
import '../domain/team.dart';

/// Một team cùng các kế hoạch của nó, đã ghép sẵn để vẽ một khối trên màn.
class TeamWithPlans {
  const TeamWithPlans({required this.team, required this.plans});

  final Team team;
  final List<Plan> plans;
}

/// Cây Teams cho màn danh sách.
///
/// Gọi hai lần rồi ghép ở client thay vì thêm một endpoint gộp: hai danh sách
/// này nhỏ (một xưởng có một team và hai kế hoạch), và endpoint gộp sẽ là một
/// hình dạng thứ ba phải giữ đồng bộ với hai cái đã có.
final teamsWithPlansProvider = FutureProvider<List<TeamWithPlans>>((ref) async {
  final api = ref.watch(plansApiProvider);
  final (teams, plans) = await (api.teams(), api.plans()).wait;

  final byTeam = <String, List<Plan>>{};
  for (final plan in plans) {
    byTeam.putIfAbsent(plan.teamId ?? '', () => []).add(plan);
  }

  final grouped = [
    for (final team in teams)
      TeamWithPlans(team: team, plans: byTeam[team.id] ?? const []),
  ];

  // Kế hoạch chưa thuộc team nào — tức là MỌI kế hoạch tạo trước tầng Team.
  // Chúng đi vào một khối riêng ở cuối chứ không bị bỏ qua: giấu chúng nghĩa
  // là công việc đang chạy biến mất khỏi app.
  final orphans = byTeam[''] ?? const <Plan>[];
  if (orphans.isNotEmpty) {
    grouped.add(
      TeamWithPlans(
        team: const Team(id: '', name: 'Chưa thuộc team nào'),
        plans: orphans,
      ),
    );
  }

  return grouped;
});

final planProvider = FutureProvider.family<Plan, String>(
  (ref, id) => ref.watch(plansApiProvider).plan(id),
);

/// Mọi việc trong một kế hoạch — hết các trang, không chỉ trang đầu.
///
/// Theo dõi [taskRealtimeSignalProvider]: hai người cùng mở bảng, một người
/// chuyển công đoạn, và người kia phải thấy. Không có dòng này thì bảng đứng
/// yên cho tới khi ai đó kéo để tải lại — và trên một bảng, "đứng yên" đọc
/// giống hệt "không có gì thay đổi".
final planTasksProvider = FutureProvider.family<PlanTasks, String>((
  ref,
  planId,
) {
  ref.watch(taskRealtimeSignalProvider);

  return loadAllTasksInPlan(ref.watch(plansApiProvider), planId);
});

/// Số cây xong tháng này và mốc thưởng kế tiếp.
///
/// Tách khỏi [workshopFeedProvider]: hai lượt gọi mạng độc lập, và KPI phải
/// quét nhật ký cả tháng trong khi dòng hoạt động chỉ lấy vài chục dòng mới
/// nhất. Buộc chúng vào nhau là để cái chậm giữ cái nhanh lại.
final workshopKpiProvider = FutureProvider<WorkshopKpi>((ref) {
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).kpi();
});

/// Chuyện gì vừa xảy ra ở xưởng.
final workshopFeedProvider = FutureProvider<List<FeedEntry>>((ref) {
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).feed();
});
