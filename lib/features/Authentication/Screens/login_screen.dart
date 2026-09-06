import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onRegister,
    this.onForgotPassword,
  });

  final void Function(String email, String password)? onLogin;
  final VoidCallback? onRegister;
  final VoidCallback? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================================================================
  // LOGIN
  // ================================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    // Keep support for an externally supplied login callback.
    if (widget.onLogin != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        widget.onLogin!(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login successful!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message =
          'No account was found with this email address.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
          'Incorrect email or password. Please try again.';
          break;

        case 'user-disabled':
          message =
          'This account has been disabled.';
          break;

        case 'too-many-requests':
          message =
          'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        default:
          message =
              e.message ?? 'Unable to log in. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ================================================================
  // OPEN SIGNUP
  // ================================================================

  void _openSignup() {
    if (widget.onRegister != null) {
      widget.onRegister!();
      return;
    }

    context.push(AppRoutes.signup);
  }

  // ================================================================
  // FORGOT PASSWORD
  // ================================================================

  Future<void> _forgotPassword() async {
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your email address first.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid email address.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent. Check your inbox.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message =
          'No account was found with this email address.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        case 'too-many-requests':
          message =
          'Too many requests. Please try again later.';
          break;

        default:
          message =
              e.message ?? 'Unable to send the reset email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send password reset email.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E6B4E);
    const darkGreen = Color(0xFF1F4D38);
    const lightGreen = Color(0xFFEAF4EE);
    const textDark = Color(0xFF1F2933);
    const textGrey = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 16,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),

                      // ==================================================
                      // APP LOGO / BRANDING
                      // ==================================================

                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: lightGreen,
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.kitchen_rounded,
                                size: 38,
                                color: primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'PantryPal',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Manage your pantry. Reduce food waste.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 42),

                      // ==================================================
                      // WELCOME
                      // ==================================================

                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Sign in to continue managing your food and pantry.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: textGrey,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // LOGIN FORM
                      // ==================================================

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            // EMAIL
                            const Text(
                              'Email address',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _emailController,
                              keyboardType:
                              TextInputType.emailAddress,
                              textInputAction:
                              TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              decoration: _inputDecoration(
                                hintText: 'Enter your email',
                                icon: Icons.email_outlined,
                                primaryGreen: primaryGreen,
                              ),
                              validator: (value) {
                                final email =
                                    value?.trim() ?? '';

                                if (email.isEmpty) {
                                  return 'Please enter your email address';
                                }

                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)) {
                                  return 'Please enter a valid email address';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // PASSWORD
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction:
                              TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.password,
                              ],
                              onFieldSubmitted: (_) {
                                if (!_isLoading) {
                                  _login();
                                }
                              },
                              decoration: _inputDecoration(
                                hintText: 'Enter your password',
                                icon:
                                Icons.lock_outline_rounded,
                                primaryGreen: primaryGreen,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword =
                                      !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons
                                        .visibility_outlined
                                        : Icons
                                        .visibility_off_outlined,
                                    color: textGrey,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please enter your password';
                                }

                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 10),

                            // ==================================================
                            // FORGOT PASSWORD
                            // ==================================================

                            Align(
                              alignment:
                              Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                _isResettingPassword ||
                                    _isLoading
                                    ? null
                                    : _forgotPassword,
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                  primaryGreen,
                                  padding: EdgeInsets.zero,
                                ),
                                child:
                                _isResettingPassword
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ==================================================
                            // LOGIN BUTTON
                            // ==================================================

                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed:
                                _isLoading ? null : _login,
                                style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                  primaryGreen,
                                  foregroundColor:
                                  Colors.white,
                                  disabledBackgroundColor:
                                  primaryGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                  elevation: 0,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                    AlwaysStoppedAnimation<
                                        Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                    : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // DIVIDER
                      // ==================================================

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              'New to PantryPal?',
                              style: TextStyle(
                                fontSize: 13,
                                color: textGrey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // CREATE ACCOUNT
                      // ==================================================

                      OutlinedButton(
                        onPressed:
                        _isLoading ? null : _openSignup,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(
                            color: primaryGreen,
                            width: 1.2,
                          ),
                          minimumSize:
                          const Size.fromHeight(52),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ==================================================
                      // FOOTER
                      // ==================================================

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 24,
                        ),
                        child: Text(
                          'Your pantry, organized for a less wasteful home.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ================================================================
  // INPUT DECORATION
  // ================================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required Color primaryGreen,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F8F8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFE1E5E3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: primaryGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFD64545),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFD64545),
          width: 1.5,
        ),
      ),
    );
  }
}