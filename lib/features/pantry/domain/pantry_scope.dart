/// Whether a pantry, or a notification created from it, is personal or shared.
///
/// `family` and `shared` are both shown as a shared household pantry. An
/// unknown or missing value is not treated as either one.
class PantryScope {
  const PantryScope.personal()
    : kind = 'personal',
      householdName = null,
      pantryId = null;

  const PantryScope.shared([this.householdName, this.pantryId])
    : kind = 'shared';

  /// `personal` or `shared`.
  final String kind;

  /// Household name from `pantries/{id}.name`, when the pantry has one.
  final String? householdName;

  /// Firestore pantry id for a shared household, when it is resolved.
  ///
  /// Presentation-only consumers can use this stable identity without
  /// deriving scope from the display name. Personal pantries do not have one.
  final String? pantryId;

  bool get isShared => kind == 'shared';

  /// Title shown on the Pantry header.
  String get headerTitle {
    if (!isShared) return 'My Pantry';
    final name = _name;
    return name ?? 'Home Pantry';
  }

  String get headerKind => isShared ? 'Shared' : 'Personal';

  String get headerLabel => '$headerTitle • $headerKind';

  /// Short prefix for a notification about an item in this pantry.
  String get notificationPrefix {
    if (!isShared) return 'My Pantry';
    return _name ?? 'Home';
  }

  String notificationTitle(String title) => '$notificationPrefix • $title';

  /// Small chip label. Uses the household name when one exists.
  String get badgeLabel {
    if (!isShared) return 'Personal';
    return _name ?? 'Shared';
  }

  String? get _name {
    final name = householdName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  /// Reads a stored notification scope. Returns null when it was never saved
  /// or the value is not one this app understands.
  static PantryScope? tryParse(String? kind, String? name) {
    switch (kind) {
      case 'personal':
        return const PantryScope.personal();
      case 'shared':
      case 'family':
        return PantryScope.shared(name);
      default:
        return null;
    }
  }

  /// Active pantry from the signed-in user's profile, matching the types
  /// already used to choose the pantry collection.
  static PantryScope fromProfile({
    required String pantryType,
    String? pantryName,
    String? pantryId,
  }) {
    final type = pantryType.trim().toLowerCase();
    if (type == 'family' || type == 'shared') {
      return PantryScope.shared(pantryName, pantryId);
    }
    return const PantryScope.personal();
  }
}
