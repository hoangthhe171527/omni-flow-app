import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';

/// Shown only while the session is being restored from storage — a fraction of
/// a second in practice. It exists so the router never has to guess where to
/// send a user whose auth state isn't known yet.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: OmniColors.primary,
          ),
        ),
      ),
    );
  }
}
