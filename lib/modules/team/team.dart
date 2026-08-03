/// Public surface of the team module.
///
/// Other modules (the inbox assign sheet, the CRM owner picker) import this
/// barrel and nothing else — never a file under `presentation/`. It is the only
/// sanctioned way one module reaches into another.
library;

export 'application/team_providers.dart';
export 'domain/team_member.dart';
export 'domain/team_permissions.dart';
