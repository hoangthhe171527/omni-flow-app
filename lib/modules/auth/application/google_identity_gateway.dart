import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Obtains a Google OpenID Connect ID token after a user-initiated sign-in.
abstract interface class GoogleIdentityGateway {
  /// Returns null when the account chooser is dismissed by the user.
  Future<String?> authenticate();
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final googleIdentityGatewayProvider = Provider<GoogleIdentityGateway>((ref) {
  throw UnimplementedError('googleIdentityGatewayProvider must be overridden');
});
