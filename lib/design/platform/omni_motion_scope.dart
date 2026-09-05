import 'package:flutter/material.dart';

import '../tokens/omni_motion.dart';

/// Thời lượng chuyển động ĐÃ TÍNH theo cài đặt trợ năng của người dùng.
typedef OmniMotionSpec = ({
  Duration fast,
  Duration base,
  Duration slow,
  bool enabled,
});

/// Đọc thang [OmniDuration] qua cài đặt "giảm chuyển động" của hệ điều hành.
///
/// iOS "Reduce Motion" và Android "Remove animations" đều tới đây qua
/// `MediaQuery.disableAnimationsOf`. Đây là cài đặt trợ năng thật, không phải
/// sở thích: có người bị chóng mặt và buồn nôn vì chuyển cảnh trượt, và hệ
/// điều hành đã hỏi họ rồi — app chỉ việc nghe.
///
/// Sắp tới app thêm một bảng công việc lướt ngang toàn màn hình, đúng loại
/// chuyển động gây khó chịu nhất. Tôn trọng cài đặt này TRƯỚC khi thêm nó,
/// chứ không phải sau.
abstract final class OmniMotion {
  static OmniMotionSpec of(BuildContext context) {
    final enabled = !MediaQuery.disableAnimationsOf(context);

    // Duration.zero chứ không phải một thời lượng ngắn hơn: "giảm" ở đây
    // nghĩa là bỏ hẳn phần di chuyển, không phải làm nó nhanh hơn. Một cú
    // trượt 60ms vẫn là một cú trượt.
    return (
      fast: enabled ? OmniDuration.fast : Duration.zero,
      base: enabled ? OmniDuration.base : Duration.zero,
      slow: enabled ? OmniDuration.slow : Duration.zero,
      enabled: enabled,
    );
  }

  /// Có được phép chạy chuyển động không. Dùng khi chỉ cần biết có/không.
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);
}

extension OmniPageControllerX on PageController {
  /// Nhảy hay trượt, tuỳ cài đặt của người dùng.
  ///
  /// `animateToPage` với `Duration.zero` ném lỗi trên một số đường curve, nên
  /// đây phải là hai nhánh chứ không phải một thời lượng bằng 0.
  Future<void> goTo(
    BuildContext context,
    int page, {
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!OmniMotion.enabled(context)) {
      jumpToPage(page);

      return Future<void>.value();
    }

    return animateToPage(page, duration: OmniDuration.base, curve: curve);
  }
}
