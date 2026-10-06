import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../domain/pantry_scope.dart';
import 'active_pantry_scope_provider.dart';

String pantryFirstItemHelpSawEmptyStorageKey(String uid, String scopeKey) =>
    'pantry_first_item_help.$uid.$scopeKey.saw_empty';

String pantryFirstItemHelpPromptedStorageKey(String uid, String scopeKey) =>
    'pantry_first_item_help.$uid.$scopeKey.prompted';

/// Kept separate for straightforward account-isolation tests.
final pantryHelpUidProvider = Provider<String?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return ref.watch(authStateProvider).asData?.value?.uid;
});

@immutable
class PantryFirstItemHelpIdentity {
  const PantryFirstItemHelpIdentity({
    required this.uid,
    required this.scopeKey,
  });

  final String uid;
  final String scopeKey;

  String get key => '$uid|$scopeKey';

  @override
  bool operator ==(Object other) =>
      other is PantryFirstItemHelpIdentity &&
      other.uid == uid &&
      other.scopeKey == scopeKey;

  @override
  int get hashCode => Object.hash(uid, scopeKey);
}

/// The authenticated user plus the exact Pantry whose one-time prompt is
/// being tracked. A shared pantry is unavailable until its Firestore id is
/// resolved; its display name is deliberately not used as an identity.
final pantryFirstItemHelpIdentityProvider =
    Provider<PantryFirstItemHelpIdentity?>((ref) {
      final uid = ref.watch(pantryHelpUidProvider);
      final scope = ref.watch(activePantryScopeProvider).asData?.value;
      if (uid == null || scope == null) return null;
      if (!scope.isShared) {
        return PantryFirstItemHelpIdentity(uid: uid, scopeKey: 'personal');
      }
      final pantryId = scope.pantryId?.trim();
      if (pantryId == null || pantryId.isEmpty) return null;
      return PantryFirstItemHelpIdentity(
        uid: uid,
        scopeKey: 'shared.${Uri.encodeComponent(pantryId)}',
      );
    });

@immutable
class PantryFirstItemHelpState {
  const PantryFirstItemHelpState({
    required this.identity,
    required this.sawEmptyPantry,
    required this.prompted,
  });

  const PantryFirstItemHelpState.unavailable()
    : identity = null,
      sawEmptyPantry = false,
      prompted = false;

  final PantryFirstItemHelpIdentity? identity;
  final bool sawEmptyPantry;
  final bool prompted;

  bool get shouldPrompt => identity != null && sawEmptyPantry && !prompted;

  PantryFirstItemHelpState copyWith({bool? sawEmptyPantry, bool? prompted}) =>
      PantryFirstItemHelpState(
        identity: identity,
        sawEmptyPantry: sawEmptyPantry ?? this.sawEmptyPantry,
        prompted: prompted ?? this.prompted,
      );
}

final pantryFirstItemHelpProvider =
    NotifierProvider<PantryFirstItemHelpNotifier, PantryFirstItemHelpState>(
      PantryFirstItemHelpNotifier.new,
    );

class PantryFirstItemHelpNotifier extends Notifier<PantryFirstItemHelpState> {
  @override
  PantryFirstItemHelpState build() {
    final identity = ref.watch(pantryFirstItemHelpIdentityProvider);
    if (identity == null) {
      return const PantryFirstItemHelpState.unavailable();
    }
    final preferences = ref.watch(sharedPreferencesProvider);
    return PantryFirstItemHelpState(
      identity: identity,
      sawEmptyPantry:
          preferences?.getBool(
            pantryFirstItemHelpSawEmptyStorageKey(
              identity.uid,
              identity.scopeKey,
            ),
          ) ??
          false,
      prompted:
          preferences?.getBool(
            pantryFirstItemHelpPromptedStorageKey(
              identity.uid,
              identity.scopeKey,
            ),
          ) ??
          false,
    );
  }

  /// Records that Add Item was opened from successfully loaded empty Pantry
  /// data. This is intentionally separate from transient stream empty values.
  void recordEmptyPantrySeen() {
    final identity = ref.read(pantryFirstItemHelpIdentityProvider);
    if (identity == null || identity != state.identity || state.prompted)
      return;
    if (!state.sawEmptyPantry) {
      state = state.copyWith(sawEmptyPantry: true);
    }
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          ?.setBool(
            pantryFirstItemHelpSawEmptyStorageKey(
              identity.uid,
              identity.scopeKey,
            ),
            true,
          ),
    );
  }

  /// Atomically claims the one-time prompt for the current user and Pantry.
  bool claimPrompt(PantryFirstItemHelpIdentity expectedIdentity) {
    final identity = ref.read(pantryFirstItemHelpIdentityProvider);
    if (identity == null ||
        identity != expectedIdentity ||
        identity != state.identity ||
        !state.sawEmptyPantry ||
        state.prompted) {
      return false;
    }
    state = state.copyWith(prompted: true);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          ?.setBool(
            pantryFirstItemHelpPromptedStorageKey(
              identity.uid,
              identity.scopeKey,
            ),
            true,
          ),
    );
    return true;
  }
}
