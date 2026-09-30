import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navigationDelay = Duration(milliseconds: 2500);
  static const _logoAsset = 'assets/images/HCI_LOGO.png';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  static bool get _isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();

    if (!_isFlutterTest) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Firebase init failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _navigationDelay - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted) return;
    context.go(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? FreshPalette.darkPageBackground
          : FreshPalette.pageBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    FreshPalette.darkPageBackground,
                    FreshPalette.darkAccentSurface,
                    FreshPalette.darkPageBackground,
                  ]
                : const [
                    FreshPalette.pageBackground,
                    FreshPalette.accentSurface,
                    FreshPalette.pageBackground,
                  ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoWidth = math.min(
                  constraints.maxWidth * 0.9,
                  math.min(constraints.maxHeight * 0.62, 440.0),
                );

                return Align(
                  alignment: const Alignment(0, 0.08),
                  child: Image.asset(
                    _logoAsset,
                    width: logoWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'PantryPal',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
