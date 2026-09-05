import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/realtime/realtime_client.dart';
import '../core/theme/theme_mode_controller.dart';
import '../design/theme/omni_theme.dart';
import '../modules/inbox/inbox_module.dart';
import '../modules/notifications/application/push_notifications.dart';
import '../modules/tasks/tasks_module.dart';
import '../security/session/session_controller.dart';
import '../security/session/session.dart';
import 'router/app_router.dart';

class OmniApp extends ConsumerStatefulWidget {
  const OmniApp({super.key});

  @override
  ConsumerState<OmniApp> createState() => _OmniAppState();
}

class _OmniAppState extends ConsumerState<OmniApp> with WidgetsBindingObserver {
  late final ProviderSubscription<Session> _sessionListener;
  late final void Function() _unregisterPreLogout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushNotificationsProvider);
    _unregisterPreLogout = ref
        .read(sessionPreLogoutProvider)
        .register(push.stop);
    _sessionListener = ref.listenManual<Session>(sessionProvider, (_, session) {
      if (session.isAuthenticated) {
        unawaited(push.start());
        _openPushIntent(ref.read(pushIntentProvider));
      } else {
        unawaited(push.stop());
        // The realtime socket was authorized with the ending session's token,
        // and its channels belong to that tenant. Leaving it open would carry
        // one workspace's message stream into the next sign-in — including a
        // tenant switch, which is a session change like any other.
        unawaited(ref.read(realtimeClientProvider).disconnect());
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unregisterPreLogout();
    _sessionListener.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !ref.read(sessionProvider).isAuthenticated) {
      return;
    }
    unawaited(ref.read(pushNotificationsProvider).ensureRegistered());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PushIntent?>(pushIntentProvider, (_, intent) {
      _openPushIntent(intent);
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: OmniTheme.light,
      darkTheme: OmniTheme.dark,
      // Was pinned to light, so a phone in dark mode got one glaring white app
      // — worst of all on the messaging screens, which sit next to Zalo.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Pin text scaling to a sane band: the inbox row packs a name, a source
        // pill, a preview and a time into one line, and it breaks apart past
        // ~1.3x. Clamping keeps large-font accessibility usable rather than
        // ignoring it.
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  void _openPushIntent(PushIntent? intent) {
    if (intent == null || !ref.read(sessionProvider).isAuthenticated) return;
    ref.read(pushIntentProvider.notifier).state = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = switch (intent.target) {
        PushTarget.conversation => InboxModule.thread,
        PushTarget.task => TasksModule.detail,
      };
      ref
          .read(routerProvider)
          .pushNamed(route, pathParameters: {'id': intent.id});
    });
  }
}
