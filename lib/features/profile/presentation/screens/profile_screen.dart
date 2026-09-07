import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _preferencesController = TextEditingController();
  final _allergiesController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _email = '';
  String _pantryType = 'personal';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _preferencesController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  // ================================================================
  // LOAD PROFILE
  // ================================================================

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = document.data();

      if (data != null) {
        _nameController.text =
            (data['name'] as String?) ??
                user.displayName ??
                '';

        _email = (data['email'] as String?) ??
            user.email ??
            '';

        _pantryType =
            (data['pantryType'] as String?) ??
                'personal';

        _preferencesController.text =
            _convertToText(data['foodPreferences']);

        _allergiesController.text =
            _convertToText(data['allergies']);
      } else {
        _nameController.text =
            user.displayName ?? '';

        _email = user.email ?? '';
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Unable to load your profile.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _convertToText(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is List) {
      return value.join(', ');
    }

    return value.toString();
  }

  // ================================================================
  // SAVE PROFILE
  // ================================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You are not logged in.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();

      final preferences = _parseItems(
        _preferencesController.text,
      );

      final allergies = _parseItems(
        _allergiesController.text,
      );

      await user.updateDisplayName(name);

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name': name,
          'email': user.email ?? _email,
          'pantryType': _pantryType,
          'foodPreferences': preferences,
          'allergies': allergies,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _showMessage(
        'Profile updated successfully.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Unable to save your profile.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _parseItems(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // ================================================================
  // MESSAGE
  // ================================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================================================================
  // PANTRY TYPE LABEL
  // ================================================================

  String _pantryTypeLabel(String value) {
    switch (value) {
      case 'family':
        return 'Family';

      case 'shared':
      case 'hostel':
        return 'Hostel / Shared';

      case 'personal':
      default:
        return 'Personal';
    }
  }

  IconData _pantryTypeIcon(String value) {
    switch (value) {
      case 'family':
        return Icons.family_restroom_rounded;

      case 'shared':
      case 'hostel':
        return Icons.groups_outlined;

      case 'personal':
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E6B4E);
    const darkGreen = Color(0xFF1F4D38);
    const lightGreen = Color(0xFFEAF4EE);
    const textDark = Color(0xFF1F2933);
    const textGrey = Color(0xFF6B7280);

    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: textDark,
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // PROFILE HEADER
              // ==================================================

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE3E9E6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 34,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isEmpty
                                ? 'PantryPal User'
                                : _nameController.text,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? _email,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // PERSONAL INFORMATION
              // ==================================================

              const Text(
                'Personal information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkGreen,
                ),
              ),

              const SizedBox(height: 14),

              _sectionCard(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel(
                      'Full name',
                      textDark,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textInputAction:
                      TextInputAction.next,
                      decoration: _inputDecoration(
                        hintText: 'Enter your name',
                        icon:
                        Icons.person_outline_rounded,
                        primaryGreen: primaryGreen,
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                      validator: (value) {
                        final name =
                            value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Please enter your name';
                        }

                        if (name.length < 2) {
                          return 'Name must be at least 2 characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    _fieldLabel(
                      'Email address',
                      textDark,
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      initialValue: user?.email ?? _email,
                      readOnly: true,
                      decoration: _inputDecoration(
                        hintText:
                        'Your email address',
                        icon: Icons.email_outlined,
                        primaryGreen: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // PANTRY TYPE
              // ==================================================

              const Text(
                'Pantry type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkGreen,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Choose how you manage your pantry.',
                style: TextStyle(
                  fontSize: 13,
                  color: textGrey,
                ),
              ),

              const SizedBox(height: 14),

              _pantryOption(
                title: 'Personal',
                subtitle:
                'Only you manage the pantry.',
                value: 'personal',
                primaryGreen: primaryGreen,
              ),

              const SizedBox(height: 10),

              _pantryOption(
                title: 'Family',
                subtitle:
                'Manage food with your family.',
                value: 'family',
                primaryGreen: primaryGreen,
              ),

              const SizedBox(height: 10),

              _pantryOption(
                title: 'Hostel / Shared',
                subtitle:
                'Share the pantry with roommates or a group.',
                value: 'shared',
                primaryGreen: primaryGreen,
              ),

              const SizedBox(height: 24),

              // ==================================================
              // FOOD PREFERENCES
              // ==================================================

              const Text(
                'Food preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkGreen,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Enter foods or preferences separated by commas.',
                style: TextStyle(
                  fontSize: 13,
                  color: textGrey,
                ),
              ),

              const SizedBox(height: 14),

              _sectionCard(
                child: TextFormField(
                  controller:
                  _preferencesController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hintText:
                    'e.g. vegetarian, rice, vegetables',
                    icon:
                    Icons.favorite_border_rounded,
                    primaryGreen: primaryGreen,
                  ).copyWith(
                    alignLabelWithHint: true,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // ALLERGIES
              // ==================================================

              const Text(
                'Food allergies',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkGreen,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Add any ingredients you want to avoid.',
                style: TextStyle(
                  fontSize: 13,
                  color: textGrey,
                ),
              ),

              const SizedBox(height: 14),

              _sectionCard(
                child: TextFormField(
                  controller:
                  _allergiesController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    hintText:
                    'e.g. peanuts, milk, shellfish',
                    icon:
                    Icons.warning_amber_rounded,
                    primaryGreen: primaryGreen,
                  ).copyWith(
                    alignLabelWithHint: true,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                  _isSaving ? null : _saveProfile,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    primaryGreen.withValues(
                      alpha: 0.5,
                    ),
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
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
                      : const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.save_outlined,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Save changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // PANTRY INFO
              // ==================================================

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: primaryGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your profile preferences will be used later to provide more relevant pantry and recipe suggestions.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // PANTRY OPTION
  // ================================================================

  Widget _pantryOption({
    required String title,
    required String subtitle,
    required String value,
    required Color primaryGreen,
  }) {
    final selected = _pantryType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isSaving
          ? null
          : () {
        setState(() {
          _pantryType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEAF4EE)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                    : const Color(0xFFF1F3F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _pantryTypeIcon(value),
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
            Radio<String>(
              value: value,
              groupValue: _pantryType,
              activeColor: primaryGreen,
              onChanged: _isSaving
                  ? null
                  : (newValue) {
                if (newValue == null) return;

                setState(() {
                  _pantryType = newValue;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SECTION CARD
  // ================================================================

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3E9E6),
        ),
      ),
      child: child,
    );
  }

  // ================================================================
  // FIELD LABEL
  // ================================================================

  Widget _fieldLabel(
      String text,
      Color color,
      ) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
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