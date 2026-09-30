import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

String wasteErrorMessage(Object error, {String action = 'save'}) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Permission denied for waste records. Please contact the team.';
  }
  if (error is StateError) {
    return 'Your account or records changed. Please reopen Waste Tracker.';
  }
  return 'Unable to $action waste records. Please try again.';
}

void showWasteError(
  BuildContext context,
  Object error, {
  String action = 'save',
}) {
  debugPrint('Waste Tracker $action error: $error');
  showWasteMessage(context, wasteErrorMessage(error, action: action));
}

void showWasteMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        duration: const Duration(seconds: 4),
      ),
    );
}
