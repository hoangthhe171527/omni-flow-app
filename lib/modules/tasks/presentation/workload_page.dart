import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../team/team.dart';
import '../application/tasks_providers.dart';
import '../domain/task.dart';
import '../routes.dart';
import 'widgets/task_card.dart';

/// "Người này đang gánh bao nhiêu cây, và trễ cái nào."
///
/// Câu hỏi quản đốc hỏi nhiều nhất khi đứng giữa xưởng, và app chưa có chỗ
/// nào trả lời: "Việc của tôi" chỉ nói về người đang đăng nhập, còn bảng dự
/// án nói về cây đàn chứ không nói về người. Muốn biết Hằng Ni đang ôm mấy
/// việc thì phải mở từng cột, đọc từng thẻ, đếm trong đầu — và làm lại từ đầu
/// cho người tiếp theo.
///
/// Không phải bảng xếp hạng. §7 nói rõ xưởng không công khai số liệu cá nhân,
/// nên màn này mở từ danh sách nhân viên cho MỘT người, không có màn nào xếp
/// mọi người cạnh nhau theo số việc. Khác biệt không nằm ở dữ liệu — nó nằm ở
/// chỗ ai đọc được, và đọc ra cái gì.
class WorkloadPage extends ConsumerWidget {
  const WorkloadPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(teamMemberByIdProvider)[userId];
    final workload = ref.watch(workloadProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(member?.name ?? 'Tải việc'),
        // Vai trò dưới tên: "Hằng Ni · Thợ máy" nói đủ để biết vì sao hàng đợi
        // của người này trông như thế.
        bottom: member == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: OmniSpacing.lg,
                    bottom: OmniSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      member.roleLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(workloadProvider(userId)),
        child: OmniAsyncView(
          value: workload,
          onRetry: () => ref.invalidate(workloadProvider(userId)),
          data: (data) => _Load(data: data),
        ),
      ),
    );
  }
}

class _Load extends StatelessWidget {
  const _Load({required this.data});

  final Workload data;

  @override
  Widget build(BuildContext context) {
    // Trễ lên trước. Đây là màn hình để QUYẾT ĐỊNH — chuyển bớt việc cho ai,
    // hay để yên — và cái quyết định đó bắt đầu từ những cây đang trễ.
    final sorted = [...data.tasks]..sort(_lateFirst);

    return ListView.separated(
      // Luôn cuộn được, kể cả khi rỗng: RefreshIndicator ở trên cần một cử
      // chỉ kéo, và một danh sách rỗng không cuộn thì không kéo được.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.bottomSafe,
      ),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) return _Summary(data: data);

        final task = sorted[index - 1];

        return TaskCard(
          task: task,
          onTap: () => context.pushNamed(
            TaskRoutes.detail,
            pathParameters: {'id': task.id},
          ),
        );
      },
    );
  }

  /// Trễ trước, rồi tới hạn gần nhất, rồi việc chưa đặt hạn.
  ///
  /// Việc chưa đặt hạn xuống CUỐI chứ không lên đầu: ở xưởng phần lớn công
  /// đoạn không đặt hạn riêng, nên để chúng lên trước là chôn đúng phần cần
  /// đọc dưới phần bình thường.
  static int _lateFirst(Task a, Task b) {
    final da = a.dueDate;
    final db = b.dueDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;

    return da.compareTo(db);
  }
}

/// Hai con số, cả hai do server đếm.
class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final Workload data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (data.total == 0) {
      return const OmniEmptyState(
        icon: Icons.beach_access_outlined,
        title: 'Không có việc nào đang mở',
        message: 'Người này đang rảnh — hoặc vừa xong hết phần của mình.',
      );
    }

    return OmniCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(
                  value: data.total,
                  label: 'việc đang gánh',
                  color: scheme.primary,
                ),
              ),
              Container(width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: _Figure(
                  value: data.overdue,
                  label: 'quá hạn',
                  // Số 0 KHÔNG tô đỏ: một màu cảnh báo trên một con số không
                  // có gì đáng cảnh báo là cách người ta học được thói quen
                  // bỏ qua nó.
                  color: data.overdue > 0
                      ? OmniColors.dangerTextOf(context)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Danh sách bị cắt thì phải NÓI RA. Con số ở trên do server đếm và
          // luôn đúng; danh sách dưới nó thì chỉ có một trang. Không nói ra
          // thì hai thứ mâu thuẫn nhau ngay trên một màn hình, và người đọc
          // sẽ tin cái đếm được bằng mắt.
          if (data.total > data.tasks.length) ...[
            const SizedBox(height: OmniSpacing.md),
            Text(
              'Danh sách dưới đây đang hiện ${data.tasks.length} việc đầu.',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          '$value',
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: OmniType.tabular,
          ),
        ),
        Text(
          label,
          style: text.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
