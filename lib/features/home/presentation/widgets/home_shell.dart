import 'package:flutter/material.dart';

import 'home_bottom_nav.dart';

class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child, bottomNavigationBar: const HomeBottomNav());
  }
}
