import 'package:flutter/material.dart';

import '../../data/shared_pantry_service.dart';

class SharedPantryScreen extends StatefulWidget {
  const SharedPantryScreen({super.key});

  @override
  State<SharedPantryScreen> createState() => _SharedPantryScreenState();
}

class _SharedPantryScreenState extends State<SharedPantryScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();

  final _pantryNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;

  String? _createdPantryId;
  String? _inviteCode;

  @override
  void dispose() {
    _pantryNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createPantry() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final pantryId =
      await SharedPantryService.instance.createPantry(
        pantryName: _pantryNameController.text,
      );

      final pantry = await SharedPantryService.instance.getPantry(
        pantryId,
      );

      final data = pantry.data();

      if (!mounted) return;

      setState(() {
        _createdPantryId = pantryId;
        _inviteCode = data?['inviteCode']?.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared pantry created successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _joinPantry() async {
    if (!_joinFormKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    try {
      await SharedPantryService.instance.joinPantry(
        inviteCode: _inviteCodeController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You joined the shared pantry successfully.'),
        ),
      );

      _inviteCodeController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
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
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('Shared Pantry'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 40,
                    color: primaryGreen,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Share your pantry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: darkGreen,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create a shared pantry for your family, hostel, or household.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: textGrey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Create a Shared Pantry',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 12),

            Form(
              key: _createFormKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE3E9E6),
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _pantryNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Pantry name',
                        hintText: 'e.g. Family Pantry',
                        prefixIcon: const Icon(
                          Icons.kitchen_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter a pantry name.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                        _isCreating ? null : _createPantry,
                        icon: _isCreating
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.add_home_rounded,
                        ),
                        label: Text(
                          _isCreating
                              ? 'Creating...'
                              : 'Create Pantry',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_createdPantryId != null &&
                _inviteCode != null) ...[
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryGreen,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pantry Created 🎉',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Share this invite code with your family or household members.',
                      style: TextStyle(
                        fontSize: 13,
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _inviteCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textGrey,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Join a Shared Pantry',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 12),

            Form(
              key: _joinFormKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE3E9E6),
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _inviteCodeController,
                      textCapitalization:
                      TextCapitalization.characters,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Invite code',
                        hintText: 'Enter 6-character code',
                        prefixIcon: const Icon(
                          Icons.key_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter an invite code.';
                        }

                        if (value.trim().length != 6) {
                          return 'Invite code must be 6 characters.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                        _isJoining ? null : _joinPantry,
                        icon: _isJoining
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.group_add_rounded,
                        ),
                        label: Text(
                          _isJoining
                              ? 'Joining...'
                              : 'Join Pantry',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(
                            color: primaryGreen,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}