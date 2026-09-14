import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/shared_pantry_service.dart';

class SharedPantryMembersScreen extends StatefulWidget {
  final String pantryId;

  const SharedPantryMembersScreen({
    super.key,
    required this.pantryId,
  });

  @override
  State<SharedPantryMembersScreen> createState() =>
      _SharedPantryMembersScreenState();
}

class _SharedPantryMembersScreenState
    extends State<SharedPantryMembersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLeaving = false;

  DocumentSnapshot<Map<String, dynamic>>? _pantry;

  @override
  void initState() {
    super.initState();
    _loadPantry();
  }

  Future<void> _loadPantry() async {
    try {
      final pantry =
      await SharedPantryService.instance.getPantry(
        widget.pantryId,
      );

      if (!mounted) return;

      setState(() {
        _pantry = pantry;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _leavePantry() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final pantryData = _pantry?.data();

    if (pantryData?['ownerId'] == user.uid) {
      _showMessage(
        'The pantry owner cannot leave the pantry.',
      );
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave pantry?'),
          content: const Text(
            'Are you sure you want to leave this shared pantry? '
                'You will no longer be able to access its members or pantry items.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (shouldLeave != true) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await SharedPantryService.instance.leavePantry(
        widget.pantryId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You left the shared pantry.',
          ),
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _memberName(
      Map<String, dynamic> data,
      ) {
    final name = data['name'];

    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }

    final email = data['email'];

    if (email is String && email.trim().isNotEmpty) {
      return email.trim();
    }

    return 'Pantry member';
  }

  String _memberEmail(
      Map<String, dynamic> data,
      ) {
    final email = data['email'];

    if (email is String && email.trim().isNotEmpty) {
      return email.trim();
    }

    return '';
  }

  String _memberRole(
      Map<String, dynamic> data,
      ) {
    final role = data['role'];

    if (role is String && role.trim().isNotEmpty) {
      return role.trim();
    }

    return 'member';
  }

  Widget _memberAvatar({
    required String name,
    required bool isOwner,
  }) {
    const primaryGreen = Color(0xFF2E6B4E);
    const lightGreen = Color(0xFFEAF4EE);

    final firstLetter = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isOwner
            ? primaryGreen
            : lightGreen,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isOwner
                ? Colors.white
                : primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    const primaryGreen = Color(0xFF2E6B4E);

    final isOwner = role.toLowerCase() == 'owner';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isOwner
            ? const Color(0xFFEAF4EE)
            : const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOwner ? 'Owner' : 'Member',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isOwner
              ? primaryGreen
              : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildMemberCard(
      QueryDocumentSnapshot<Map<String, dynamic>> member,
      ) {
    const primaryGreen = Color(0xFF2E6B4E);
    const textDark = Color(0xFF1F2933);
    const textGrey = Color(0xFF6B7280);

    final data = member.data();

    final name = _memberName(data);
    final email = _memberEmail(data);
    final role = _memberRole(data);
    final isOwner = role.toLowerCase() == 'owner';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3E9E6),
        ),
      ),
      child: Row(
        children: [
          _memberAvatar(
            name: name,
            isOwner: isOwner,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                    ),
                    if (member.id ==
                        _auth.currentUser?.uid) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(You)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                _roleBadge(role),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: SharedPantryService.instance
          .getMembers(widget.pantryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 40,
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE3E9E6),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 42,
                  color: Color(0xFFD64545),
                ),
                SizedBox(height: 10),
                Text(
                  'Unable to load pantry members.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final members =
            snapshot.data?.docs ?? [];

        if (members.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE3E9E6),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 44,
                  color: Color(0xFF2E6B4E),
                ),
                SizedBox(height: 10),
                Text(
                  'No members yet.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2933),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share the invite code to add people to this pantry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: members
              .map(_buildMemberCard)
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E6B4E);
    const darkGreen = Color(0xFF1F4D38);
    const lightGreen = Color(0xFFEAF4EE);
    const textDark = Color(0xFF1F2933);
    const textGrey = Color(0xFF6B7280);

    final pantryData = _pantry?.data();

    final pantryName =
        pantryData?['name']?.toString() ??
            'Shared Pantry';

    final inviteCode =
        pantryData?['inviteCode']?.toString() ??
            '';

    final currentUser =
        _auth.currentUser;

    final isOwner =
        pantryData?['ownerId'] ==
            currentUser?.uid;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text(
          'Shared Pantry Members',
        ),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =====================================================
            // PANTRY HEADER
            // =====================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius:
                BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 30,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shared Pantry',
                          style: TextStyle(
                            fontSize: 13,
                            color: textGrey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pantryName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight:
                            FontWeight.w800,
                            color: darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =====================================================
            // INVITE CODE
            // =====================================================

            const Text(
              'Invite members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Share this code with family or household members to let them join your pantry.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: textGrey,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: primaryGreen,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'PANTRY INVITE CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: textGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    inviteCode.isEmpty
                        ? '------'
                        : inviteCode,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // =====================================================
            // MEMBERS
            // =====================================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pantry members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                ),
                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream:
                  SharedPantryService
                      .instance
                      .getMembers(
                    widget.pantryId,
                  ),
                  builder:
                      (context, snapshot) {
                    final count =
                        snapshot.data?.docs.length ??
                            0;

                    return Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration:
                      BoxDecoration(
                        color: lightGreen,
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Text(
                        '$count ${count == 1 ? 'member' : 'members'}',
                        style:
                        const TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w700,
                          color: primaryGreen,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            _buildMembersList(),

            const SizedBox(height: 20),

            // =====================================================
            // OWNER INFORMATION
            // =====================================================

            if (isOwner)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      color: primaryGreen,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You are the owner of this pantry.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                          color: darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // =====================================================
            // LEAVE PANTRY
            // =====================================================

            if (!isOwner)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLeaving
                      ? null
                      : _leavePantry,
                  icon: _isLeaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.logout_rounded,
                  ),
                  label: Text(
                    _isLeaving
                        ? 'Leaving...'
                        : 'Leave Pantry',
                  ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(0xFFD64545),
                    side: const BorderSide(
                      color: Color(0xFFD64545),
                    ),
                    padding:
                    const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}