import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_service.dart';

enum PantryType {
  personal,
  family,
  shared,
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.onSignup,
    this.onLogin,
  });

  final void Function({
  required String name,
  required String email,
  required String password,
  required PantryType pantryType,
  })? onSignup;

  final VoidCallback? onLogin;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  PantryType pantryType = PantryType.personal;

  bool hidePassword = true;
  bool hideConfirm = true;
  bool agree = false;
  bool loading = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms and Privacy Policy.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
    });

    try {
      await AuthService.instance.signUp(
        name: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
        pantryType: pantryType.name,
      );

      if (!mounted) return;

      widget.onSignup?.call(
        name: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
        pantryType: pantryType,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
          'An account already exists with this email address.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message =
          'Your password is too weak. Please choose a stronger password.';
          break;

        case 'operation-not-allowed':
          message =
          'Email/password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        case 'too-many-requests':
          message =
          'Too many attempts. Please try again later.';
          break;

        default:
          message =
              e.message ?? 'Unable to create your account.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save your profile: '
                '${e.message ?? 'Please try again.'}',
          ),
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
          loading = false;
        });
      }
    }
  }

  void _openLogin() {
    if (widget.onLogin != null) {
      widget.onLogin!();
      return;
    }

    context.go(AppRoutes.login);
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
                      const SizedBox(height: 28),

                      // ------------------------------------------------
                      // BRANDING
                      // ------------------------------------------------

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
                            const SizedBox(height: 16),
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
                              'Create your pantry and start reducing waste.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 34),

                      // ------------------------------------------------
                      // TITLE
                      // ------------------------------------------------

                      const Text(
                        'Create your account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Set up your PantryPal account to manage your food efficiently.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: textGrey,
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ------------------------------------------------
                      // FORM
                      // ------------------------------------------------

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            // NAME
                            const Text(
                              'Full name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: name,
                              textInputAction:
                              TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.name,
                              ],
                              decoration: _inputDecoration(
                                hintText: 'Enter your name',
                                icon:
                                Icons.person_outline_rounded,
                                primaryGreen: primaryGreen,
                              ),
                              validator: (value) {
                                final valueText =
                                    value?.trim() ?? '';

                                if (valueText.isEmpty) {
                                  return 'Please enter your name';
                                }

                                if (valueText.length < 2) {
                                  return 'Name must be at least 2 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

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
                              controller: email,
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
                                final emailValue =
                                    value?.trim() ?? '';

                                if (emailValue.isEmpty) {
                                  return 'Please enter your email address';
                                }

                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(emailValue)) {
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
                              controller: password,
                              obscureText: hidePassword,
                              textInputAction:
                              TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              decoration: _inputDecoration(
                                hintText: 'Create a password',
                                icon:
                                Icons.lock_outline_rounded,
                                primaryGreen: primaryGreen,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      hidePassword =
                                      !hidePassword;
                                    });
                                  },
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons
                                        .visibility_off_outlined,
                                    color: textGrey,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please enter a password';
                                }

                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // CONFIRM PASSWORD
                            const Text(
                              'Confirm password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: confirm,
                              obscureText: hideConfirm,
                              textInputAction:
                              TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              decoration: _inputDecoration(
                                hintText: 'Re-enter your password',
                                icon:
                                Icons.lock_reset_outlined,
                                primaryGreen: primaryGreen,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: hideConfirm
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      hideConfirm =
                                      !hideConfirm;
                                    });
                                  },
                                  icon: Icon(
                                    hideConfirm
                                        ? Icons.visibility_outlined
                                        : Icons
                                        .visibility_off_outlined,
                                    color: textGrey,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please confirm your password';
                                }

                                if (value != password.text) {
                                  return 'Passwords do not match';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 26),

                            // ------------------------------------------------
                            // PANTRY TYPE
                            // ------------------------------------------------

                            const Text(
                              'Pantry type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              'Choose how you plan to use PantryPal.',
                              style: TextStyle(
                                fontSize: 13,
                                color: textGrey,
                              ),
                            ),

                            const SizedBox(height: 12),

                            _PantryOption(
                              title: 'Personal pantry',
                              subtitle:
                              'For managing your own food.',
                              icon: Icons.person_outline_rounded,
                              value: PantryType.personal,
                              groupValue: pantryType,
                              primaryGreen: primaryGreen,
                              onChanged: (value) {
                                setState(() {
                                  pantryType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 10),

                            _PantryOption(
                              title: 'Family pantry',
                              subtitle:
                              'Share and manage food with family.',
                              icon: Icons.family_restroom_rounded,
                              value: PantryType.family,
                              groupValue: pantryType,
                              primaryGreen: primaryGreen,
                              onChanged: (value) {
                                setState(() {
                                  pantryType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 10),

                            _PantryOption(
                              title: 'Shared pantry',
                              subtitle:
                              'For hostels, roommates, or groups.',
                              icon: Icons.groups_outlined,
                              value: PantryType.shared,
                              groupValue: pantryType,
                              primaryGreen: primaryGreen,
                              onChanged: (value) {
                                setState(() {
                                  pantryType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 20),

                            // ------------------------------------------------
                            // TERMS
                            // ------------------------------------------------

                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: agree,
                                  activeColor: primaryGreen,
                                  onChanged: loading
                                      ? null
                                      : (value) {
                                    setState(() {
                                      agree =
                                          value ?? false;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding:
                                    EdgeInsets.only(top: 12),
                                    child: Text(
                                      'I agree to the Terms of Service and Privacy Policy.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: textGrey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ------------------------------------------------
                            // CREATE ACCOUNT
                            // ------------------------------------------------

                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed:
                                loading ? null : _signup,
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
                                child: loading
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
                                  'Create Account',
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

                      const SizedBox(height: 26),

                      // ------------------------------------------------
                      // LOGIN LINK
                      // ------------------------------------------------

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(
                              fontSize: 14,
                              color: textGrey,
                            ),
                          ),
                          TextButton(
                            onPressed: loading
                                ? null
                                : _openLogin,
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Your pantry, organized for a less wasteful home.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: textGrey,
                        ),
                      ),

                      const SizedBox(height: 24),
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

// ================================================================
// PANTRY OPTION WIDGET
// ================================================================

class _PantryOption extends StatelessWidget {
  const _PantryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.primaryGreen,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PantryType value;
  final PantryType groupValue;
  final Color primaryGreen;
  final ValueChanged<PantryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEAF4EE)
              : const Color(0xFFF8F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? primaryGreen
                : const Color(0xFFE1E5E3),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white
                    : const Color(0xFFEFF2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected
                    ? primaryGreen
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2933),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Radio<PantryType>(
              value: value,
              groupValue: groupValue,
              activeColor: primaryGreen,
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}