import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Do not await Firebase here — it blocks the first frame and causes
  runApp(const ProviderScope(child: FreshTrackApp()));
}
