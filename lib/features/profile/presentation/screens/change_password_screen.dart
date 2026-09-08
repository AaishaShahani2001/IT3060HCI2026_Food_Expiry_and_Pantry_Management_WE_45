import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController =
  TextEditingController();

  final _newPasswordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  static const primaryGreen = Color(0xFF2E6B4E);
  static const darkGreen = Color(0xFF1F4D38);
  static const lightGreen = Color(0xFFEAF4EE);
  static const textDark = Color(0xFF1F2933);
  static const textGrey = Color(0xFF6B7280);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Your session has expired. Please log in again.',
      );
      return;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      _showMessage(
        'Unable to find your account email.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Re-authenticate the user with the current password.
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update to the new password.
      await user.updatePassword(
        _newPasswordController.text,
      );

      if (!mounted) return;

      _showMessage(
        'Password changed successfully.',
        isSuccess: true,
      );

      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      context.pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Your current password is incorrect.';
          break;

        case 'weak-password':
          message =
          'Your new password is too weak.';
          break;

        case 'requires-recent-login':
          message =
          'Please log in again before changing your password.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your connection.';
          break;

        default:
          message =
              e.message ??
                  'Unable to change your password.';
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool isSuccess = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isSuccess ? primaryGreen : const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onVisibilityPressed,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: textGrey,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
      ),
      prefixIcon: const Icon(
        Icons.lock_outline_rounded,
        color: primaryGreen,
      ),
      suffixIcon: IconButton(
        onPressed: onVisibilityPressed,
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: textGrey,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE1E5E3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE1E5E3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD64545),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFD64545),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your current password';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a new password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    if (value == _currentPasswordController.text) {
      return 'New password must be different';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your new password';
    }

    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isLoading
              ? null
              : () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: darkGreen,
          ),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD5E7DC),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        color: primaryGreen,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep your account secure',
                              style: TextStyle(
                                color: darkGreen,
                                fontSize: 15,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Enter your current password and choose a new password for your PantryPal account.',
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Current password',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  _currentPasswordController,
                  obscureText:
                  _obscureCurrentPassword,
                  enabled: !_isLoading,
                  validator:
                  _validateCurrentPassword,
                  decoration: _inputDecoration(
                    label: 'Current password',
                    hint: 'Enter current password',
                    obscureText:
                    _obscureCurrentPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _obscureCurrentPassword =
                        !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'New password',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  _newPasswordController,
                  obscureText: _obscureNewPassword,
                  enabled: !_isLoading,
                  validator: _validateNewPassword,
                  decoration: _inputDecoration(
                    label: 'New password',
                    hint: 'Enter new password',
                    obscureText:
                    _obscureNewPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _obscureNewPassword =
                        !_obscureNewPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 10),

                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Use at least 6 characters.',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Confirm new password',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  _confirmPasswordController,
                  obscureText:
                  _obscureConfirmPassword,
                  enabled: !_isLoading,
                  validator:
                  _validateConfirmPassword,
                  decoration: _inputDecoration(
                    label: 'Confirm new password',
                    hint: 'Re-enter new password',
                    obscureText:
                    _obscureConfirmPassword,
                    onVisibilityPressed: () {
                      setState(() {
                        _obscureConfirmPassword =
                        !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                    _isLoading
                        ? null
                        : _changePassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryGreen,
                      disabledBackgroundColor:
                      const Color(0xFFB8C9BF),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w700,
                      ),
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