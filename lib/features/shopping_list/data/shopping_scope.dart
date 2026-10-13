enum ShoppingScopeKind { personal, shared }

class ShoppingScope {
  const ShoppingScope._({
    required this.kind,
    required this.actorUid,
    this.pantryId,
  });

  factory ShoppingScope.personal(String uid) {
    _validateSegment(uid, 'user');
    return ShoppingScope._(kind: ShoppingScopeKind.personal, actorUid: uid);
  }

  factory ShoppingScope.shared({
    required String actorUid,
    required String pantryId,
  }) {
    _validateSegment(actorUid, 'user');
    _validateSegment(pantryId, 'pantry');
    return ShoppingScope._(
      kind: ShoppingScopeKind.shared,
      actorUid: actorUid,
      pantryId: pantryId,
    );
  }

  final ShoppingScopeKind kind;
  final String actorUid;
  final String? pantryId;

  bool get isShared => kind == ShoppingScopeKind.shared;

  String get collectionPath => switch (kind) {
    ShoppingScopeKind.personal => 'users/$actorUid/shopping_items',
    ShoppingScopeKind.shared => 'pantries/$pantryId/shopping_items',
  };

  static void _validateSegment(String value, String label) {
    if (value.trim().isEmpty ||
        value.contains('/') ||
        value == '.' ||
        value == '..') {
      throw ArgumentError('A valid $label ID is required.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ShoppingScope &&
      other.kind == kind &&
      other.actorUid == actorUid &&
      other.pantryId == pantryId;

  @override
  int get hashCode => Object.hash(kind, actorUid, pantryId);

  @override
  String toString() => 'ShoppingScope($collectionPath, actor: $actorUid)';
}
