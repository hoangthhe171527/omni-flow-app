import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/domain/task.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
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

final planTasksProvider = FutureProvider.family<List<Task>, String>((
  ref,
  planId,
) async {
  final page = await ref.watch(plansApiProvider).tasksInPlan(planId);

  return page.items;
});
