/// Barrel for the shared UI vocabulary. A module imports this one file and gets
/// every primitive it is allowed to use; anything it needs beyond this belongs
/// either in the module itself or, if a second module needs it too, here.
library;

export 'brand_anchor.dart';
export 'omni_app_bar.dart';
export 'omni_avatar.dart';
export 'omni_backdrop.dart';
export 'omni_brand.dart';
export 'omni_card.dart';
export 'omni_collapsible_card.dart';
export 'omni_dashed_circle.dart';
export 'omni_inputs.dart';
export 'omni_status_chip.dart';
export 'omni_pills.dart';
export 'omni_progress_ring.dart';
export 'omni_segmented.dart';
export 'omni_splash.dart';
export 'omni_states.dart';
export 'omni_tabs.dart';
export 'omni_task_chip.dart';
export 'omni_top_bar.dart';

/// Lớp nền tảng đi kèm barrel này: module gọi showOmniConfirm mà không phải
/// biết iOS hay Android, và cũng không được phép biết — xem
/// test/architecture/platform_boundary_test.dart.
export '../platform/omni_dialogs.dart';
