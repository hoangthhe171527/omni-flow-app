import 'module_route.dart';
import 'nav_destination.dart';

/// The contract every feature implements.
///
/// A module owns its routes, its navigation entries and its permission slugs.
/// Nothing outside it needs editing to add, remove or reorder a feature — and no
/// module may reach into another's `presentation/` layer. Where two features
/// genuinely share a screen (a customer card shown inside a chat), the owner
/// exposes it through its public barrel and the other imports that.
///
/// What this replaces: the previous mobile app had an `admin` "feature" that
/// pulled tabs out of inventory, sales and analytics, and a shell that branched
/// on a hard-coded role enum to decide which of them to show. Admin is not a
/// feature — it is a *permission level over* other features. Here each module
/// decides for itself what it exposes at each permission level, and the screens
/// that really are administrative (members, roles, audit) live in an
/// `administration` module of their own.
///
/// Declarations are unconditional: a module always returns everything it owns,
/// each item carrying its own `AccessRequirement`. Filtering happens once, in
/// the registry. That keeps a module from having to know the session, and keeps
/// the router's structure stable while the *visible* navigation changes with
/// permissions.
abstract class OmniModule {
  const OmniModule();

  /// Stable identifier, also the analytics/logging namespace.
  String get id;

  /// Human name — shown in diagnostics and the "Quyền của tôi" screen.
  String get title;

  /// Every permission slug this module gates on. Declared so the app can show a
  /// user exactly what they hold, and so a slug typo is findable in one place
  /// per module instead of in a 200-line global constants class.
  List<String> get permissions => const [];

  /// Screens this module owns.
  List<ModuleRoute> routes();

  /// Bottom-bar tabs this module offers.
  List<ModuleDestination> destinations() => const [];

  /// Entries for the "Thêm" screen.
  List<ModuleMenuEntry> menuEntries() => const [];
}
