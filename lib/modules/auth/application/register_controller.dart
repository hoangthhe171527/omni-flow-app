import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../security/session/session_controller.dart';
import '../data/auth_onboarding_api.dart';

class RegisterState {
  const RegisterState({
    this.submitting = false,
    this.error,
    this.fieldErrors = const {},
  });

  final bool submitting;
  final String? error;
  final Map<String, List<String>> fieldErrors;

  String? errorFor(String field) => fieldErrors[field]?.firstOrNull;
}

class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  /// Tạo workspace rồi vào thẳng app. Trả `true` khi đã có phiên.
  Future<bool> submit({
    required String fullName,
    required String email,
    required String companyName,
    required String password,
  }) async {
    if (state.submitting) return false;
    state = const RegisterState(submitting: true);
    try {
      await ref
          .read(authOnboardingApiProvider)
          .register(
            fullName: fullName,
            email: email,
            companyName: companyName,
            password: password,
          );
    } on ValidationException catch (error) {
      state = RegisterState(error: error.message, fieldErrors: error.errors);
      return false;
    } on AppException catch (error) {
      state = RegisterState(error: error.message);
      return false;
    }

    try {
      // Tài khoản đã tạo; đăng nhập bằng đường thường để phiên, workspace và
      // router đi đúng một cửa. Router đưa người dùng vào app khi phiên sẵn
      // sàng.
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: email, password: password);
      state = const RegisterState();
      return true;
    } on AppException {
      state = const RegisterState(
        error: 'Đã tạo tài khoản nhưng chưa đăng nhập được. Hãy đăng nhập lại.',
      );
      return false;
    }
  }
}

final registerControllerProvider =
    NotifierProvider<RegisterController, RegisterState>(RegisterController.new);
