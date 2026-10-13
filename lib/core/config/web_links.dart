import 'env.dart';

/// Liên kết mở trên web (`omni-flow`), khớp route của web:
///
/// - việc: `/projects/my-work?task=<id>` (`_app.projects.my-work.tsx`; web
///   dựng y hệt ở `taskDeepLink`);
/// - kế hoạch: `/projects/<id>` (`_app.projects.$projectId.tsx`, bảng kế
///   hoạch).
///
/// Gốc lấy từ [Env.webBaseUrl]. Không phải route API, nên không xét
/// capability hay quyền ghi: ai mở được việc / bảng thì chép được.
abstract final class WebLinks {
  static String task(String taskId) =>
      '${Env.webBaseUrl}/projects/my-work?task=${Uri.encodeComponent(taskId)}';

  static String plan(String planId) =>
      '${Env.webBaseUrl}/projects/${Uri.encodeComponent(planId)}';
}
