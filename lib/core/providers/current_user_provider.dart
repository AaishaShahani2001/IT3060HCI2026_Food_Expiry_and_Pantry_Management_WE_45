import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentUserNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return '';
    }

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (document.exists) {
      final data = document.data();

      final name = data?['name'];

      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    // Fallback to Firebase Auth display name
    final displayName = user.displayName;

    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    return '';
  }
}

final currentUserNameProvider =
AsyncNotifierProvider<CurrentUserNameNotifier, String>(
  CurrentUserNameNotifier.new,
);