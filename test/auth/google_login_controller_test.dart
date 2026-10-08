import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/auth/application/google_identity_gateway.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  test(
    'successful Google sign-in forwards the ID token to the session',
    () async {
      final session = _RecordingSessionController();
      final container = ProviderContainer(
        overrides: [
          googleIdentityGatewayProvider.overrideWithValue(
            const _FakeGoogleIdentity('google-id-token'),
          ),
          sessionControllerProvider.overrideWith(() => session),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(loginControllerProvider.notifier)
          .submitWithGoogle();

      expect(result, isTrue);
      expect(session.credential, 'google-id-token');
      expect(container.read(loginControllerProvider).error, isNull);
    },
  );

  test('closing the Google account chooser is silent', () async {
    final session = _RecordingSessionController();
    final container = ProviderContainer(
      overrides: [
        googleIdentityGatewayProvider.overrideWithValue(
          const _FakeGoogleIdentity(null),
        ),
        sessionControllerProvider.overrideWith(() => session),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(loginControllerProvider.notifier)
        .submitWithGoogle();

    expect(result, isFalse);
    expect(session.credential, isNull);
    expect(container.read(loginControllerProvider).error, isNull);
  });

  test('native Google configuration error is shown to the user', () async {
    final container = ProviderContainer(
      overrides: [
        googleIdentityGatewayProvider.overrideWithValue(
          const _FailingGoogleIdentity(),
        ),
        sessionControllerProvider.overrideWith(_RecordingSessionController.new),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(loginControllerProvider.notifier)
        .submitWithGoogle();

    expect(result, isFalse);
    expect(
      container.read(loginControllerProvider).error,
      'Đăng nhập Google chưa được cấu hình đúng.',
    );
  });
}

class _FakeGoogleIdentity implements GoogleIdentityGateway {
  const _FakeGoogleIdentity(this.credential);

  final String? credential;

  @override
  Future<String?> authenticate() async => credential;
}

class _FailingGoogleIdentity implements GoogleIdentityGateway {
  const _FailingGoogleIdentity();

  @override
  Future<String?> authenticate() async {
    throw const GoogleIdentityException(
      'Đăng nhập Google chưa được cấu hình đúng.',
    );
  }
}

class _RecordingSessionController extends SessionController {
  String? credential;

  @override
  Session build() => const Session.unauthenticated();

  @override
  Future<void> loginWithGoogle(String credential) async {
    this.credential = credential;
    state = const Session(status: SessionStatus.tenantPending);
  }
}
