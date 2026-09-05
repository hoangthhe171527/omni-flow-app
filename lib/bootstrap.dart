import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/omni_app.dart';
import 'core/module/module_registry.dart';
import 'core/module/omni_module.dart';
import 'core/storage/preferences_store.dart';
import 'modules/auth/auth_module.dart';
import 'modules/auth/data/auth_api.dart';
import 'modules/channels/channels_module.dart';
import 'modules/customers/customers_module.dart';
import 'modules/inbox/inbox_module.dart';
import 'modules/notifications/notifications_module.dart';
import 'modules/opportunities/opportunities_module.dart';
import 'modules/settings/settings_module.dart';
import 'modules/tasks/tasks_module.dart';
import 'modules/team/team_module.dart';
import 'security/session/auth_gateway.dart';

/// Every module in the app, in navigation order.
///
/// This list is the *only* place features are wired together. Adding one is a
/// single line here plus its own folder — no shell edit, no router edit, no
/// central permission map, and nothing to remember in a second file.
const List<OmniModule> appModules = [
  AuthModule(),
  InboxModule(),
  TasksModule(),
  CustomersModule(),
  OpportunitiesModule(),
  TeamModule(),
  ChannelsModule(),
  NotificationsModule(),
  SettingsModule(),
];

Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // `.env` is optional — `--dart-define` covers CI and release builds.
  }

  // Vietnamese date formatting is used on every list row.
  await initializeDateFormatting('vi_VN');

  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      modulesProvider.overrideWithValue(appModules),
      // Dependency inversion: `security` declares the gateway, `modules/auth`
      // implements it, and they meet here.
      authGatewayProvider.overrideWith((ref) => ref.watch(authApiProvider)),
    ],
    child: const OmniApp(),
  );
}
