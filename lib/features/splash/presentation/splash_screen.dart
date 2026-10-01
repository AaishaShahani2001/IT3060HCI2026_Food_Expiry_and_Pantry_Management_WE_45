import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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

  // Background image WITHOUT logo
  static const _backgroundAsset =
      'assets/images/pantrypal_splash.png';

  // PantryPal logo
  static const _logoAsset =
      'assets/images/HCI_LOGO.png';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAEA),
        body: SizedBox.expand(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // =====================================================
                // BACKGROUND
                // =====================================================

                Image.asset(
                  _backgroundAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'PantryPal splash background',
                ),

                // =====================================================
                // PANTRYPAL LOGO
                // =====================================================

                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    child: Image.asset(
                      _logoAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'PantryPal',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}