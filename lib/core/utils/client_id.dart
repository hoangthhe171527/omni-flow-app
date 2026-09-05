import 'dart:math';

/// Generates the idempotency key a write carries to the API.
///
/// The key is what lets a retry be recognised as the *same* attempt rather than
/// a new one. A send that times out on a flaky mobile network may well have
/// been accepted by the server; without a stable key the rep's "Gửi lại" tap
/// delivers the message to the customer a second time.
///
/// Requirements this has to meet, in order:
///
///  * **Unique across devices and installs.** Two reps composing at the same
///    millisecond must not collide — the server's unique index is scoped to the
///    conversation, and two people do share a thread.
///  * **Unique across app restarts.** A per-session counter (`local-0`,
///    `local-1`, …) restarts at zero every launch, so a queued message written
///    before a crash would collide with an unrelated one after it.
///  * **Short.** The API caps the key at 64 characters.
///
/// Time prefix + 96 secure-random bits meets all three, and sorts roughly by
/// creation time, which makes a log or a database scan readable.
String newClientId() {
  final random = Random.secure();
  final buffer = StringBuffer('cm-')
    ..write(DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36))
    ..write('-');
  for (var i = 0; i < 12; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
