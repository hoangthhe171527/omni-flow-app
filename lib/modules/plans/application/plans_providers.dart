import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/application/tasks_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import '../domain/workshop_kpi.dart';
import '../domain/team.dart';

/// Một team cùng các dự án của nó, đã ghép sẵn để vẽ một khối trên màn.
class TeamWithPlans {
  const TeamWithPlans({required this.team, required this.plans});

  final Team team;
  final List<Plan> plans;
}

/// Cây Teams cho màn danh sách.
///
/// Gọi hai lần rồi ghép ở client thay vì thêm một endpoint gộp: hai danh sách
/// này nhỏ (một xưởng có một team và hai dự án), và endpoint gộp sẽ là một
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

  // Dự án có team mà team ĐÓ không nằm trong danh sách vừa tải.
  //
  // Đây từng là chỗ dự án biến mất: app tra tên team trong `GET /teams` còn web
  // tra trong `GET /org-units` — hai bảng khác nhau — nên mỗi dự án tạo ở bên
  // này rơi vào "chưa xếp team" ở bên kia. API giờ giải sẵn `team_name`,
  // nên dựng được đúng khối cho nó thay vì dồn vào rổ mồ côi.
  //
  // Vẫn còn lý do khác để rơi vào đây: team bị lưu trữ (danh sách mặc định giấu
  // team đã lưu trữ), hoặc danh sách team tải hỏng. Cả hai đều KHÔNG được làm dự
  // án biến mất.
  final known = {for (final team in teams) team.id};
  final extras = <String, TeamWithPlans>{};
  for (final entry in byTeam.entries) {
    if (entry.key.isEmpty || known.contains(entry.key)) continue;

    final name = entry.value
        .map((p) => p.teamName)
        .firstWhere((n) => (n ?? '').isNotEmpty, orElse: () => null);

    extras[entry.key] = TeamWithPlans(
      team: Team(id: entry.key, name: name ?? 'Team không còn tồn tại'),
      plans: entry.value,
    );
  }
  grouped.addAll(extras.values);

  // Dự án thật sự chưa xếp team. Chúng đi vào một khối riêng ở cuối chứ không
  // bị bỏ qua: giấu chúng nghĩa là công việc đang chạy biến mất khỏi app.
  final orphans = byTeam[''] ?? const <Plan>[];
  if (orphans.isNotEmpty) {
    grouped.add(
      TeamWithPlans(
        team: const Team(id: '', name: 'Chưa xếp team'),
        plans: orphans,
      ),
    );
  }

  return grouped;
});

final planProvider = FutureProvider.family<Plan, String>(
  (ref, id) => ref.watch(plansApiProvider).plan(id),
);

/// Quãng ân hạn trước khi bảng / KPI / dòng việc bị dọn sau khi rời màn.
///
/// Ba provider ấy theo dõi tín hiệu realtime — và KHÔNG autoDispose thì sau
/// khi đóng bảng, mỗi tick ở xưởng vẫn kéo theo một lượt tải lại toàn bộ việc
/// của dự án đó, cho một màn hình không ai còn nhìn. Mở mười bảng trong ngày
/// là mười lượt tải lại cho mỗi sự kiện.
///
/// Không autoDispose trần: quản đốc mở một cây đàn ra xem rồi quay lại bảng
/// trong vài giây, và bảng phải còn nguyên. Hai phút là đủ cho một lượt đi
/// về như thế, và đủ ngắn để không giữ mười bảng cả buổi.
const kBoardKeepAlive = Duration(minutes: 2);

extension on Ref<Object?> {
  /// Sống thêm [kBoardKeepAlive] sau khi người nghe cuối cùng rời đi.
  void lingerAfterLastListener() {
    final link = keepAlive();
    final timer = Timer(kBoardKeepAlive, link.close);
    // Đóng link CŨ mỗi lần rebuild, không chỉ huỷ timer: Riverpod không dọn
    // danh sách link khi rebuild, nên một link còn mở mà timer của nó đã bị
    // huỷ là một provider không bao giờ được dọn.
    onDispose(() {
      timer.cancel();
      link.close();
    });
  }
}

/// Mọi việc trong một dự án — hết các trang, không chỉ trang đầu.
///
/// Theo dõi [taskRealtimeSignalProvider]: hai người cùng mở bảng, một người
/// chuyển công đoạn, và người kia phải thấy. Không có dòng này thì bảng đứng
/// yên cho tới khi ai đó kéo để tải lại — và trên một bảng, "đứng yên" đọc
/// giống hệt "không có gì thay đổi".
///
/// autoDispose có ân hạn (xem [kBoardKeepAlive]): rời màn đủ lâu thì tín hiệu
/// realtime không còn kéo theo lượt tải lại nào cho bảng này nữa.
final planTasksProvider = FutureProvider.autoDispose.family<PlanTasks, String>((
  ref,
  planId,
) {
  ref.lingerAfterLastListener();
  ref.watch(taskRealtimeSignalProvider);

  return loadAllTasksInPlan(ref.watch(plansApiProvider), planId);
});

/// Số cây xong tháng này và mốc thưởng kế tiếp.
///
/// Tách khỏi [workshopFeedProvider]: hai lượt gọi mạng độc lập, và KPI phải
/// quét nhật ký cả tháng trong khi dòng hoạt động chỉ lấy vài chục dòng mới
/// nhất. Buộc chúng vào nhau là để cái chậm giữ cái nhanh lại.
final workshopKpiProvider = FutureProvider.autoDispose<WorkshopKpi>((ref) {
  ref.lingerAfterLastListener();
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).kpi(month: ref.watch(kpiMonthProvider));
});

/// Tháng đang xem trên thẻ KPI. Luôn là ngày 1 của tháng đó.
///
/// Cuối tháng chủ xưởng đọc con số để trao thưởng (§B4) — nhưng ngày mùng 1
/// thì con số đã về 0, và tháng vừa khép lại là thứ không còn xem được ở đâu
/// cả. API nhận `?month=` từ lâu; app thì chưa từng gửi.
///
/// Không autoDispose: quản đốc lùi về tháng trước, mở một cây đàn ra xem, rồi
/// quay lại — và tháng phải còn nguyên. Dọn nó đi là đưa họ về tháng này mà
/// không nói gì.
final kpiMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();

  return DateTime(now.year, now.month);
});

/// Số việc xong của tháng LIỀN TRƯỚC tháng đang xem — mốc so sánh cho thẻ KPI.
///
/// Provider riêng, không nhét vào [workshopKpiProvider]: lượt gọi này hỏng
/// thì thẻ chỉ mất một dòng "+6 so với tháng 8", chứ không được kéo cả con số
/// chính xuống theo. Không theo dõi tín hiệu realtime — một tháng đã khép
/// không đổi vì ai đó vừa tick một việc của tháng này.
final kpiPreviousDeliveredProvider = FutureProvider<int>((ref) async {
  final month = ref.watch(kpiMonthProvider);
  // `DateTime(y, 0)` tự lùi về tháng 12 năm trước.
  final previous = DateTime(month.year, month.month - 1);
  final kpi = await ref.watch(plansApiProvider).kpi(month: previous);

  return kpi.delivered;
});

/// Chuyện gì vừa xảy ra ở xưởng — chỉ những việc đã đánh dấu xong.
final workshopFeedProvider = FutureProvider.autoDispose<WorkshopFeed>((ref) {
  ref.lingerAfterLastListener();
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).feed(types: kFeedCompletionTypes);
});
