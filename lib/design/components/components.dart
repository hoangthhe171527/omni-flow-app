/// Barrel for the shared UI vocabulary. A module imports this one file and gets
/// every primitive it is allowed to use; anything it needs beyond this belongs
/// either in the module itself or, if a second module needs it too, here.
library;

export 'omni_avatar.dart';
export 'omni_card.dart';
export 'omni_inputs.dart';
export 'omni_pills.dart';
export 'omni_states.dart';
