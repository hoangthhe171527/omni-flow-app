import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/nav/account_extras_slot.dart';
import '../core/lifecycle/background_policy.dart';
import '../core/realtime/realtime_client.dart';
import '../core/theme/theme_mode_controller.dart';
import '../design/components/components.dart';
import '../design/theme/omni_theme.dart';
import '../modules/customers/application/customers_providers.dart';
import '../modules/inbox/inbox_routes.dart';
import '../modules/notifications/application/notifications_providers.dart';
import '../modules/notifications/application/push_notifications.dart';
import '../modules/notifications/routes.dart';
import '../modules/opportunities/application/opportunities_providers.dart';
import '../modules/plans/application/plans_providers.dart';
import '../modules/settings/presentation/widgets/account_menu_button.dart';
import '../modules/tasks/application/tasks_providers.dart';
import '../modules/tasks/tasks_module.dart';
import '../modules/team/application/team_providers.dart';
import '../security/session/session_controller.dart';
import '../security/session/session.dart';
import 'perf/performance_scope_host.dart';
import 'router/app_router.dart';
import 'shell/directory_page.dart' show AppSettingsSections;
import 'shell/launch_splash.dart';

Widget _accountExtras(BuildContext context) => const AppSettingsSections();

class OmniApp extends ConsumerStatefulWidget {
  const OmniApp({super.key});

  @override
  ConsumerState<OmniApp> createState() => _OmniAppState();
}

class _OmniAppState extends ConsumerState<OmniApp> with WidgetsBindingObserver {
  late final ProviderSubscription<Session> _sessionListener;
  late final void Function() _unregisterPreLogout;
  late final BackgroundPolicy _background;

  @override
  void initState() {
    super.initState();
    _background = BackgroundPolicy(
      onSettled: _onLongBackground,
      onResumed: _onResumed,
    );
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
    _background.dispose();
    _unregisterPreLogout();
    _sessionListener.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _background.onState(state);

  @override
  void didHaveMemoryPressure() {
    // Hệ điều hành sắp giết app: xả cache ảnh đã giải mã (tải lại được từ đĩa).
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  /// Ở nền quá 60 giây: tạm ngắt socket (giữ kênh/listener). Tin lúc nền đã có
  /// push; giữ socket sống chỉ tốn pin và dữ liệu.
  void _onLongBackground() {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    unawaited(ref.read(realtimeClientProvider).pause());
  }

  void _onResumed(bool afterLongBackground) {
    if (!ref.read(sessionProvider).isAuthenticated) return;

    // Nối lại là no-op khi socket còn sống; cũng là cách đưa socket đã tạm ngắt
    // về trạng thái cũ.
    unawaited(ref.read(realtimeClientProvider).connect());
    // Quay lại sau vài giây (kéo thanh thông báo, hộp thoại quyền...) thì không
    // có gì để làm mới.
    if (!afterLongBackground) return;

    unawaited(ref.read(pushNotificationsProvider).ensureRegistered());

    // Socket có thể đã chết LẶNG trong lúc app ở nền: proxy hết hạn chờ, nhà
    // mạng cắt kết nối dài, máy ngủ. Màn hình lúc ấy hiện dữ liệu cũ mà trông y
    // hệt dữ liệu mới — trên dòng việc, "đứng yên" đọc giống hệt "chưa ai làm
    // gì". Nên nối lại VÀ buộc một lượt tải lại, không tin vào socket.
    ref.read(taskRealtimeSignalProvider.notifier).bump();
    ref.read(planRealtimeSignalProvider.notifier).bump();
    ref.read(customerRealtimeSignalProvider.notifier).bump();
    ref.read(opportunityRealtimeSignalProvider.notifier).bump();
    ref.read(teamRealtimeSignalProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PushIntent?>(pushIntentProvider, (_, intent) {
      _openPushIntent(intent);
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: OmniTheme.light(),
      darkTheme: OmniTheme.dark(),
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
          // Cắm nút tài khoản MỘT lần, ở trên mọi route. Từ đây, màn nào dựng
          // `OmniAppBar` cũng có nút ở góc phải mà không phải nhớ gì — xem
          // docblock của `OmniAccountSlot` về lý do là chỗ cắm chứ không phải
          // một import thẳng từ design lên module.
          child: AccountExtrasSlot(
            // Khung ứng dụng: Cài đặt ứng dụng + Trợ giúp ở cuối Tài khoản.
            builder: _accountExtras,
            child: OmniAccountSlot(
              builder: (_) => const AccountMenuButton(),
              tileBuilder: (_) => const AccountMenuButton(tile: true),
              // Chuông của OmniTopBar: số chưa đọc và đích đến đều thuộc về
              // module thông báo, nên cắm ở đây thay vì import ngược từ design.
              child: OmniTopBarSlot(
                unreadOf: (ref) =>
                    ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
                // Chuông mở thẳng trang Thông báo (người dùng 2026-11-08): "Đọc
                // hết" đã ở trang đó, Cài đặt thông báo nằm trong "Tất cả".
                onBell: (context, _) =>
                    GoRouter.of(context).pushNamed(NotificationRoutes.centre),
                // Bậc hiệu năng (làm mờ đầy đủ / giảm / tối giản) cho cả app,
                // tự hạ khi đo thấy giật — rà soát hiệu năng 08/11/2026.
                child: PerformanceScopeHost(
                  // Hiệu ứng mở app phủ lên router, không nằm trong nó — xem
                  // docblock của LaunchSplash về lý do không làm chậm điều hướng.
                  child: LaunchSplash(child: child ?? const SizedBox.shrink()),
                ),
              ),
            ),
          ),
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
        PushTarget.conversation => InboxRoutes.thread,
        PushTarget.task => TasksModule.detail,
      };
      ref
          .read(routerProvider)
          .pushNamed(route, pathParameters: {'id': intent.id});
    });
  }
}
