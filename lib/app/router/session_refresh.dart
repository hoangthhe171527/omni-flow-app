import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/session/session.dart';
import '../../security/session/session_controller.dart';

/// Re-runs the router's redirect when the session changes, without rebuilding
/// the router itself. Rebuilding it made the previous app flicker
/// login → home → login on every auth transition.
class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Ref ref) {
    _subscription = ref.listen<Session>(
      sessionProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  late final ProviderSubscription<Session> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final sessionRefreshProvider = Provider<SessionRefresh>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
