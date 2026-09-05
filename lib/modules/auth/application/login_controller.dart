import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';

class LoginState {
  const LoginState({
    this.submitting = false,
    this.error,
    this.fieldErrors = const {},
  });

  final bool submitting;
  final String? error;
  final Map<String, List<String>> fieldErrors;

  String? errorFor(String field) => fieldErrors[field]?.firstOrNull;
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<bool> submit({required String email, required String password}) async {
    state = const LoginState(submitting: true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: email, password: password);
      state = const LoginState();
      return true;
    } on ValidationException catch (error) {
      state = LoginState(error: error.message, fieldErrors: error.errors);
      return false;
    } on UnauthorizedException {
      state = const LoginState(error: 'Email hoặc mật khẩu không đúng.');
      return false;
    } on AppException catch (error) {
      state = LoginState(error: error.message);
      return false;
    }
  }
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);

/// Workspaces the signed-in user may enter — read by the picker screen.
final tenantOptionsProvider = FutureProvider<List<TenantOption>>((ref) {
  return ref.watch(authGatewayProvider).tenants();
});
