import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dummy current-user display name until Firebase Auth/Firestore is wired.
class CurrentUserNameNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return 'Alex';
  }
}

final currentUserNameProvider =
    AsyncNotifierProvider<CurrentUserNameNotifier, String>(
      CurrentUserNameNotifier.new,
    );
