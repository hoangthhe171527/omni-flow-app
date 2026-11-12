import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/inventory_providers.dart';
import 'inventory_ui.dart';

/// Chỗ đưa cây vào xưởng: kế hoạch + nhóm việc (`null` = server chọn nhóm đầu).
typedef WorkshopTarget = ({String planId, String? sectionId});

/// "Đưa vào xưởng" (TNP_DON_HANG_THEO_CAY §6): tấm chọn kế hoạch → tấm chọn
/// nhóm việc. Kế hoạch chỉ có một nhóm thì không hỏi. Chưa có kế hoạch nào quản
/// lý được → báo và trả `null`; bỏ ngang ở tấm nào cũng trả `null`.
Future<WorkshopTarget?> pickWorkshopTarget(
  BuildContext context,
  WidgetRef ref,
) async {
  // Giữ provider tự huỷ sống trong lúc chờ (như `_pickLot`).
  final sub = ref.listenManual(workshopPlansProvider, (_, _) {});
  final List<WorkshopPlan> plans;
  try {
    plans = await ref.read(workshopPlansProvider.future);
  } finally {
    sub.close();
  }
  if (!context.mounted) return null;
  if (plans.isEmpty) {
    InvUi.toast(context, 'Chưa có kế hoạch đang chạy nào bạn quản lý được.');
    return null;
  }
  final r = await showInvOptions<String>(
    context: context,
    title: 'Chọn kế hoạch',
    options: [for (final p in plans) (p.id, p.name)],
  );
  final planId = r?.value;
  if (planId == null || !context.mounted) return null;
  final sections = plans.firstWhere((p) => p.id == planId).sections;
  if (sections.length < 2) {
    return (planId: planId, sectionId: sections.firstOrNull?.id);
  }
  final s = await showInvOptions<String>(
    context: context,
    title: 'Nhóm việc',
    options: [for (final x in sections) (x.id, x.name)],
    selected: sections.first.id,
  );
  final sectionId = s?.value;
  if (sectionId == null) return null;
  return (planId: planId, sectionId: sectionId);
}
