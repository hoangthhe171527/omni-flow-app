import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session_controller.dart';
import 'google_identity_gateway.dart';

enum LoginMethod { password, google }

class LoginState {
  const LoginState({
    this.submittingMethod,
    this.error,
    this.fieldErrors = const {},
  });

  final LoginMethod? submittingMethod;
  final String? error;
  final Map<String, List<String>> fieldErrors;

  bool get submitting => submittingMethod != null;

  String? errorFor(String field) => fieldErrors[field]?.firstOrNull;
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<bool> submit({required String email, required String password}) async {
    state = const LoginState(submittingMethod: LoginMethod.password);
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

  Future<bool> submitWithGoogle() async {
    state = const LoginState(submittingMethod: LoginMethod.google);
    try {
      final credential = await ref
          .read(googleIdentityGatewayProvider)
          .authenticate();
      if (credential == null) {
        state = const LoginState();
        return false;
      }
      await ref
          .read(sessionControllerProvider.notifier)
          .loginWithGoogle(credential);
      state = const LoginState();
      return true;
    } on GoogleIdentityException catch (error) {
      state = LoginState(error: error.message);
      return false;
    } on UnauthorizedException {
      state = const LoginState(
        error:
            'Không thể đăng nhập bằng Google. Liên hệ quản trị viên nếu bạn cần được cấp quyền.',
      );
      return false;
    } on AppException catch (error) {
      state = LoginState(error: error.message);
      return false;
    } catch (_) {
      state = const LoginState(
        error: 'Không thể đăng nhập bằng Google. Vui lòng thử lại.',
      );
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
