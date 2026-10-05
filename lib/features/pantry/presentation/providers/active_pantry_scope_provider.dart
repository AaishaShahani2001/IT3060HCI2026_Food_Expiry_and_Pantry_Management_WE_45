import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pantry_scope.dart';

/// The pantry the signed-in user is currently using.
///
/// This follows `users/{uid}.pantryType` and, for a household pantry, the
/// name on `pantries/{pantryId}`. It is the same profile the pantry item
/// stream already uses to switch collections.
final activePantryScopeProvider = StreamProvider<PantryScope>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(const PantryScope.personal());
  }
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream.value(const PantryScope.personal());
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncExpand((snapshot) {
          final data = snapshot.data();
          final pantryType =
              (data?['pantryType'] as String?)?.trim().toLowerCase() ??
              'personal';
          final pantryId = (data?['pantryId'] as String?)?.trim();
          if (pantryType != 'family' && pantryType != 'shared') {
            return Stream.value(const PantryScope.personal());
          }
          if (pantryId == null || pantryId.isEmpty) {
            return Stream.value(const PantryScope.shared());
          }
          return FirebaseFirestore.instance
              .collection('pantries')
              .doc(pantryId)
              .snapshots()
              .map((pantry) {
                final name = pantry.data()?['name'];
                return PantryScope.shared(name is String ? name : null);
              });
        });
  });
});
