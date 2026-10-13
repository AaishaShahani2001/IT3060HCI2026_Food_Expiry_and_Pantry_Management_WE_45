import 'package:flutter/material.dart';
import 'waste_tracker_screen.dart';

class WasteHistoryScreen extends StatelessWidget {
  const WasteHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => const WasteTrackerScreen(history: true);
}
