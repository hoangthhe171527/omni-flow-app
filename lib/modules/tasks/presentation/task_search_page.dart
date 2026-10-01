import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/tasks_providers.dart';
import '../routes.dart';
import 'widgets/task_card.dart';

/// Khoảng lặng trước khi gõ trở thành một lượt gọi mạng.
///
/// 350ms là quãng nghỉ tự nhiên giữa hai chữ. Ngắn hơn thì mỗi ký tự là một
/// lượt đi mạng xưởng; dài hơn thì kết quả tới sau khi người ta đã ngẩng lên.
const kTaskSearchDebounce = Duration(milliseconds: 350);

/// "Cây SN 471302 đang ở đâu."
///
/// Ở xưởng người ta gọi cây đàn bằng số máy, không bằng tên dự án hay tên
/// cột. Khách gọi điện hỏi cây của họ, và câu trả lời nằm rải trong bảy cột
/// của hai dự án — app trước đây không có đường nào tới nó ngoài việc lướt
/// từng cột.
///
/// Server so khớp trên `title`, `customer_name`, `name` và `code`, nên một số
/// máy nằm trong tiêu đề ("SCHWESTER No.53 — SN 471302") tìm ra được, và tên
/// khách cũng vậy.
///
/// Không giới hạn cho quản đốc: người đi tìm một cây đàn thường KHÔNG phải
/// người đang giữ nó — đó chính là lý do họ phải tìm. §3 nói xưởng chạy kiểu
/// pull, và một người thợ không tra được cây mình sắp nhận thì không nhận
/// được.
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key});

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Nút xoá xuất hiện ngay từ ký tự đầu, không chờ hết quãng lặng: nó nói
    // về ô nhập, không nói về kết quả.
    setState(() {});
    _timer?.cancel();
    _timer = Timer(kTaskSearchDebounce, () {
      // Widget có thể đã rời cây trong lúc chờ — người dùng bấm quay lại ngay
      // sau khi gõ chữ cuối là chuyện thường.
      if (!mounted) return;
      ref.read(taskSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(taskSearchQueryProvider).trim();
    final results = ref.watch(taskSearchProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        // Luôn là màn đẩy vào; nếu mở thẳng (không có nút quay lại) thì ô
        // tìm vẫn cách mép 16.
        titleSpacing: (ModalRoute.of(context)?.canPop ?? false) ? 0 : 16,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        // Ô tìm là khối xám bo 12 như thiết kế, nút xoá nằm TRONG ô.
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            // Enter là "tìm NGAY", không phải chờ hết quãng lặng: người đã bấm
            // xong thì không có gì để chờ nữa.
            onSubmitted: (value) {
              _timer?.cancel();
              ref.read(taskSearchQueryProvider.notifier).state = value;
            },
            style: OmniType.input.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: _searchBorder,
              enabledBorder: _searchBorder,
              focusedBorder: _searchBorder,
              hintText: 'Tên cây đàn, số máy, tên khách',
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá',
                      onPressed: () {
                        _timer?.cancel();
                        _controller.clear();
                        ref.read(taskSearchQueryProvider.notifier).state = '';
                        setState(() {});
                      },
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: OmniIconSize.sm,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: query.isEmpty
          ? const OmniEmptyState(
              icon: Icons.search_rounded,
              title: 'Tìm một cây đàn',
              message:
                  'Gõ số máy, tên cây đàn hoặc tên khách. Tìm trong cả việc '
                  'đã xong — một cây đã bàn giao vẫn phải tra lại được.',
            )
          : OmniAsyncView(
              value: results,
              onRetry: () => ref.invalidate(taskSearchProvider),
              isEmpty: (list) => list.isEmpty,
              empty: OmniEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không có kết quả cho "$query"',
                message:
                    'Thử một phần của số máy thay vì cả chuỗi — tìm theo đoạn '
                    'khớp, nên "4713" cũng ra.',
              ),
              data: (list) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  OmniSpacing.xs,
                  OmniSpacing.lg,
                  OmniSpacing.bottomSafe,
                ),
                itemCount: list.length + 1,
                separatorBuilder: (_, index) => SizedBox(
                  height: index == 0 ? OmniSpacing.sm : OmniSpacing.md,
                ),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                      child: Text(
                        '${list.length} kết quả · tìm cả việc đã xong',
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final task = list[i - 1];
                  return TaskCard(
                    task: task,
                    highlight: query,
                    onTap: () => context.pushNamed(
                      TaskRoutes.detail,
                      pathParameters: {'id': task.id},
                    ),
                  );
                },
              ),
            ),
    );
  }
}

const _searchBorder = OutlineInputBorder(
  borderRadius: OmniRadius.mdAll,
  borderSide: BorderSide.none,
);
