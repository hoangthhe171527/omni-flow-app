import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tenant id sent as `X-Tenant-Id` on every business request.
///
/// Kept here rather than on the session so the Dio interceptor can read it
/// without depending on the auth module (which would be a cycle: auth → network
/// → auth).
final activeTenantIdProvider = StateProvider<String?>((ref) => null);

/// Bumped by the Dio interceptor whenever the API answers 401 on a non-auth
/// endpoint. The session controller listens and ends the session, which makes
/// the router redirect to login. Same reason as above: no cycle.
final unauthorizedSignalProvider = StateProvider<int>((ref) => 0);
