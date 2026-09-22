import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_routes.dart';
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

  bool _isLoadingPantry = true;
  bool _isCreating = false;
  bool _isJoining = false;
  bool _isLeaving = false;

  DocumentSnapshot<Map<String, dynamic>>? _currentPantry;

  final _pantryService = SharedPantryService.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrentPantry();
  }

  @override
  void dispose() {
    _pantryNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD EXISTING PANTRY
  // ============================================================

  Future<void> _loadCurrentPantry() async {
    if (mounted) {
      setState(() {
        _isLoadingPantry = true;
      });
    }

    try {
      final pantry = await _pantryService.getCurrentUserPantry();

      if (!mounted) return;

      setState(() {
        _currentPantry = pantry;
        _isLoadingPantry = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _currentPantry = null;
        _isLoadingPantry = false;
      });
    }
  }

  // ============================================================
  // CREATE PANTRY
  // ============================================================

  Future<void> _createPantry() async {
    if (!_createFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final pantryId = await _pantryService.createPantry(
        pantryName: _pantryNameController.text.trim(),
      );

      if (!mounted) return;

      _pantryNameController.clear();

      await _loadCurrentPantry();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared pantry created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.push(
        '${AppRoutes.sharedPantryMembers}?pantryId=$pantryId',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
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

  // ============================================================
  // JOIN PANTRY
  // ============================================================

  Future<void> _joinPantry() async {
    if (!_joinFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final pantryId = await _pantryService.joinPantry(
        inviteCode: _inviteCodeController.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      _inviteCodeController.clear();

      await _loadCurrentPantry();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined shared pantry successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      context.push(
        '${AppRoutes.sharedPantryMembers}?pantryId=$pantryId',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
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

  // ============================================================
  // COPY INVITE CODE
  // ============================================================

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(
      ClipboardData(text: inviteCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // SHARE INVITE CODE
  // ============================================================

  Future<void> _shareInviteCode(
      String pantryName,
      String inviteCode,
      ) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
        'Join my PantryPal shared pantry!\n\n'
            'Pantry: $pantryName\n'
            'Invite Code: $inviteCode\n\n'
            'Open PantryPal and use this code to join.',
        subject: 'Join my PantryPal Shared Pantry',
      ),
    );
  }

  // ============================================================
  // LEAVE PANTRY
  // ============================================================

  Future<void> _leavePantry(String pantryId) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Leave Shared Pantry?',
          ),
          content: const Text(
            'You will no longer have access to this shared pantry. '
                'You can join another pantry later using an invite code.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              child: const Text('Leave Pantry'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) {
      return;
    }

    setState(() {
      _isLeaving = true;
    });

    try {
      await _pantryService.leavePantry(pantryId);

      if (!mounted) return;

      setState(() {
        _currentPantry = null;
        _isLeaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You left the shared pantry.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLeaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const darkForest = Color(0xFF174A3A);
    const forest = Color(0xFF2E6B4E);
    const mediumForest = Color(0xFF5B8F73);

    const paleGreen = Color(0xFFEAF4EE);
    const softGreen = Color(0xFFF3F8F5);

    const background = Color(0xFFF5F7F2);
    const textDark = Color(0xFF17201B);
    const textGrey = Color(0xFF6B7280);
    const border = Color(0xFFDCE6E0);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          color: textDark,
        ),
        title: const Text(
          'Shared Pantry',
          style: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoadingPantry
            ? const Center(
          child: CircularProgressIndicator(
            color: forest,
          ),
        )
            : RefreshIndicator(
          color: forest,
          onRefresh: _loadCurrentPantry,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              6,
              18,
              36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // HERO
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEAF4EE),
                        Color(0xFFDCEEE3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Color(0xFFD5E7DC),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: darkForest.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: darkForest,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share your pantry',
                              style: TextStyle(
                                color: darkForest,
                                fontSize: 20,
                                fontWeight:
                                FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Manage groceries together with your family, roommates, or household.',
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // EXISTING PANTRY
                // ==================================================

                if (_currentPantry != null)
                  _buildExistingPantryCard(
                    pantry: _currentPantry!,
                    darkForest: darkForest,
                    forest: forest,
                    paleGreen: paleGreen,
                    textDark: textDark,
                    textGrey: textGrey,
                    border: border,
                  )
                else ...[
                  // ==================================================
                  // CREATE PANTRY
                  // ==================================================

                  const Text(
                    'Create a Shared Pantry',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Start a pantry and invite your household members.',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(22),
                      border: Border.all(
                        color: border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.035,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _createFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller:
                            _pantryNameController,
                            textCapitalization:
                            TextCapitalization.words,
                            decoration: _inputDecoration(
                              label: 'Pantry name',
                              hint: 'e.g. Family Pantry',
                              icon: Icons.kitchen_rounded,
                              darkForest: darkForest,
                              paleGreen: paleGreen,
                              softGreen: softGreen,
                              border: border,
                              forest: forest,
                              textGrey: textGrey,
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
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _isCreating
                                  ? null
                                  : _createPantry,
                              icon: _isCreating
                                  ? const SizedBox(
                                width: 19,
                                height: 19,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons.add_home_rounded,
                                size: 20,
                              ),
                              label: Text(
                                _isCreating
                                    ? 'Creating Pantry...'
                                    : 'Create Pantry',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                darkForest,
                                foregroundColor:
                                Colors.white,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    15,
                                  ),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 27),

                  // ==================================================
                  // OR
                  // ==================================================

                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: border,
                        ),
                      ),
                      Container(
                        margin:
                        const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: paleGreen,
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'OR',
                          style: TextStyle(
                            color: forest,
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: border,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 27),

                  // ==================================================
                  // JOIN PANTRY
                  // ==================================================

                  const Text(
                    'Join a Shared Pantry',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Use the invite code provided by your pantry owner.',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(22),
                      border: Border.all(
                        color: border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.035,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _joinFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller:
                            _inviteCodeController,
                            textCapitalization:
                            TextCapitalization.characters,
                            maxLength: 6,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 17,
                              fontWeight:
                              FontWeight.w800,
                              letterSpacing: 3,
                            ),
                            decoration:
                            _inputDecoration(
                              label: 'Invite code',
                              hint: 'ABC123',
                              icon: Icons.key_rounded,
                              darkForest: darkForest,
                              paleGreen: paleGreen,
                              softGreen: softGreen,
                              border: border,
                              forest: forest,
                              textGrey: textGrey,
                            ).copyWith(
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
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isJoining
                                  ? null
                                  : _joinPantry,
                              icon: _isJoining
                                  ? const SizedBox(
                                width: 19,
                                height: 19,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: forest,
                                ),
                              )
                                  : const Icon(
                                Icons
                                    .group_add_rounded,
                                size: 20,
                              ),
                              label: Text(
                                _isJoining
                                    ? 'Joining Pantry...'
                                    : 'Join Pantry',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),
                              style:
                              OutlinedButton.styleFrom(
                                foregroundColor:
                                darkForest,
                                side:
                                const BorderSide(
                                  color: forest,
                                  width: 1.3,
                                ),
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildInfoCard(
                    darkForest: darkForest,
                    forest: forest,
                    paleGreen: paleGreen,
                  ),
                ],

                const SizedBox(height: 22),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.eco_rounded,
                        size: 15,
                        color: mediumForest,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Plan together. Waste less.',
                        style: TextStyle(
                          color: mediumForest,
                          fontSize: 11.5,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING PANTRY CARD
  // ============================================================

  Widget _buildExistingPantryCard({
    required DocumentSnapshot<Map<String, dynamic>> pantry,
    required Color darkForest,
    required Color forest,
    required Color paleGreen,
    required Color textDark,
    required Color textGrey,
    required Color border,
  }) {
    final data = pantry.data() ?? {};

    final pantryName = data['name']?.toString() ?? 'Shared Pantry';
    final inviteCode = data['inviteCode']?.toString() ?? '';
    final ownerId = data['ownerId']?.toString() ?? '';
    final currentUserId = _pantryService.currentUserId;

    final isOwner = ownerId.isNotEmpty && ownerId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Shared Pantry',
          style: TextStyle(
            color: textDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your shared groceries and household members.',
          style: TextStyle(
            color: textGrey,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.home_work_rounded,
                      color: darkForest,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pantryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: forest),
                            const SizedBox(width: 6),
                            Text(
                              isOwner
                                  ? 'You manage this pantry'
                                  : 'You are a pantry member',
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOwner ? 'OWNER' : 'MEMBER',
                      style: TextStyle(
                        color: darkForest,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'INVITE CODE',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        inviteCode.isEmpty ? '------' : inviteCode,
                        style: TextStyle(
                          color: darkForest,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: inviteCode.isEmpty
                                ? null
                                : () => _copyInviteCode(inviteCode),
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: const Text(
                              'Copy Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: forest,
                              side: BorderSide(color: forest, width: 1.1),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: inviteCode.isEmpty
                                ? null
                                : () => _shareInviteCode(
                              pantryName,
                              inviteCode,
                            ),
                            icon: const Icon(
                              Icons.ios_share_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Share Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: darkForest,
                              side: BorderSide(
                                color: darkForest,
                                width: 1.1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this code with household members so they can join this pantry.',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: paleGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: darkForest,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pantry Members',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'People sharing this pantry',
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _pantryService.getMembers(pantry.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: forest,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Loading members...',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F4),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFE8C5C1),
                        ),
                      ),
                      child: const Text(
                        'Unable to load pantry members.',
                        style: TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }

                  final members = snapshot.data?.docs ?? [];

                  if (members.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: textGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'No members found.',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final visibleMembers = members.take(4).toList();

                  return Column(
                    children: [
                      ...visibleMembers.map((memberDoc) {
                        final memberData = memberDoc.data();
                        final memberName =
                        memberData['name']?.toString().trim().isNotEmpty == true
                            ? memberData['name'].toString().trim()
                            : 'Pantry Member';
                        final memberEmail =
                            memberData['email']?.toString().trim() ?? '';
                        final role =
                            memberData['role']?.toString().toLowerCase() ?? 'member';
                        final memberIsOwner = role == 'owner';
                        final memberUid = memberData['uid']?.toString() ?? '';
                        final isCurrentUser =
                            memberUid.isNotEmpty && memberUid == currentUserId;

                        final initials = memberName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((part) => part.isNotEmpty)
                            .take(2)
                            .map((part) => part[0].toUpperCase())
                            .join();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAF8),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: paleGreen,
                                child: Text(
                                  initials.isEmpty ? '?' : initials,
                                  style: TextStyle(
                                    color: darkForest,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            memberName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: textDark,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentUser)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: paleGreen,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'YOU',
                                              style: TextStyle(
                                                color: darkForest,
                                                fontSize: 7,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (memberEmail.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        memberEmail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: memberIsOwner ? paleGreen : Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: memberIsOwner ? paleGreen : border,
                                  ),
                                ),
                                child: Text(
                                  memberIsOwner ? 'OWNER' : 'MEMBER',
                                  style: TextStyle(
                                    color: memberIsOwner ? darkForest : textGrey,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (members.length > 4) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+ ${members.length - 4} more member(s)',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: FilledButton.icon(
                  onPressed: () {
                    context.push(
                      '${AppRoutes.sharedPantryMembers}?pantryId=${pantry.id}',
                    );
                  },
                  icon: const Icon(Icons.groups_rounded, size: 19),
                  label: const Text(
                    'View All Pantry Members',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: darkForest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isOwner)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: paleGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: forest,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are the pantry owner. You can manage your shared pantry and members.',
                          style: TextStyle(
                            color: darkForest,
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isLeaving
                        ? null
                        : () => _leavePantry(pantry.id),
                    icon: _isLeaving
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      _isLeaving ? 'Leaving Pantry...' : 'Leave Pantry',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(
                        color: Color(0xFFE5B7B3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard({
    required Color darkForest,
    required Color forest,
    required Color paleGreen,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: paleGreen.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD5E8DC),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: forest,
              size: 17,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Each shared pantry has a unique 6-character invite code. '
                  'Share it only with the people you want to add.',
              style: TextStyle(
                color: darkForest,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required Color darkForest,
    required Color paleGreen,
    required Color softGreen,
    required Color border,
    required Color forest,
    required Color textGrey,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Padding(
        padding: const EdgeInsets.all(9),
        child: Container(
          decoration: BoxDecoration(
            color: paleGreen,
            borderRadius:
            BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: darkForest,
            size: 19,
          ),
        ),
      ),

      filled: true,
      fillColor: softGreen,

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),

      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: BorderSide(
          color: border,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: BorderSide(
          color: border,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: BorderSide(
          color: forest,
          width: 1.5,
        ),
      ),

      labelStyle: TextStyle(
        color: textGrey,
      ),
    );
  }
}