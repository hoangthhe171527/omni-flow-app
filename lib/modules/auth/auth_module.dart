import '../../core/module/module_route.dart';
import '../../core/module/omni_module.dart';
import 'presentation/login_page.dart';
import 'presentation/workspace_page.dart';

/// Sign-in and workspace selection. Contributes no tab and no menu entry: the
/// session state decides when these screens appear, not navigation.
class AuthModule extends OmniModule {
  const AuthModule();

  static const login = 'auth.login';
  static const workspace = 'auth.workspace';

  static const loginPath = '/login';
  static const workspacePath = '/workspace';

  @override
  String get id => 'auth';

  @override
  String get title => 'Đăng nhập';

  @override
  List<ModuleRoute> routes() => [
        ModuleRoute(
          path: loginPath,
          name: login,
          builder: (_, _) => const LoginPage(),
        ),
        ModuleRoute(
          path: workspacePath,
          name: workspace,
          builder: (_, _) => const WorkspacePage(),
        ),
      ];
}
