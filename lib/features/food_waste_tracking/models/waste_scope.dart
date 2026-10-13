enum WasteScopeKind { personal, shared }

class WasteScope {
  const WasteScope._({
    required this.kind,
    required this.actorUid,
    this.pantryId,
  });

  factory WasteScope.personal({required String actorUid}) {
    _validateSegment(actorUid, 'user');
    return WasteScope._(kind: WasteScopeKind.personal, actorUid: actorUid);
  }

  factory WasteScope.shared({
    required String actorUid,
    required String pantryId,
  }) {
    _validateSegment(actorUid, 'user');
    _validateSegment(pantryId, 'pantry');
    return WasteScope._(
      kind: WasteScopeKind.shared,
      actorUid: actorUid,
      pantryId: pantryId,
    );
  }

  final WasteScopeKind kind;
  final String actorUid;
  final String? pantryId;

  bool get isShared => kind == WasteScopeKind.shared;

  String get collectionPath => switch (kind) {
    WasteScopeKind.personal => 'users/$actorUid/waste_records',
    WasteScopeKind.shared => 'pantries/$pantryId/waste_records',
  };

  String get identity => switch (kind) {
    WasteScopeKind.personal => 'personal:$actorUid',
    WasteScopeKind.shared => 'shared:$actorUid:$pantryId',
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
      other is WasteScope &&
      other.kind == kind &&
      other.actorUid == actorUid &&
      other.pantryId == pantryId;

  @override
  int get hashCode => Object.hash(kind, actorUid, pantryId);

  @override
  String toString() => 'WasteScope($identity)';
}

class WasteScopeChangedException implements Exception {
  const WasteScopeChangedException();

  @override
  String toString() => 'The active pantry context changed.';
}
