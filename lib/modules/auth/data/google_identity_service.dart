import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/env.dart';
import '../application/google_identity_gateway.dart';

class GoogleIdentityService implements GoogleIdentityGateway {
  GoogleIdentityService({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  Future<void>? _initialization;

  @override
  Future<String?> authenticate() async {
    try {
      await (_initialization ??= _signIn.initialize(
        clientId: Env.googleSsoApplicationClientId,
        serverClientId: Env.googleSsoServerClientId,
      ));

      if (!_signIn.supportsAuthenticate()) {
        throw const GoogleIdentityException(
          'Thiết bị này chưa hỗ trợ đăng nhập Google.',
        );
      }

      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleIdentityException(
          'Google không trả về mã xác thực. Vui lòng thử lại.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw GoogleIdentityException(_messageFor(error.code));
    } on GoogleIdentityException {
      rethrow;
    } catch (_) {
      throw const GoogleIdentityException(
        'Không thể mở đăng nhập Google. Vui lòng thử lại.',
      );
    }
  }

  String _messageFor(GoogleSignInExceptionCode code) {
    if (code == GoogleSignInExceptionCode.clientConfigurationError ||
        code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Đăng nhập Google chưa được cấu hình đúng trên thiết bị này.';
    }
    if (code == GoogleSignInExceptionCode.uiUnavailable) {
      return 'Không thể mở cửa sổ đăng nhập Google. Vui lòng thử lại.';
    }
    return 'Không thể đăng nhập bằng Google. Vui lòng thử lại.';
  }
}

final googleIdentityServiceProvider = Provider<GoogleIdentityService>((ref) {
  return GoogleIdentityService();
});
