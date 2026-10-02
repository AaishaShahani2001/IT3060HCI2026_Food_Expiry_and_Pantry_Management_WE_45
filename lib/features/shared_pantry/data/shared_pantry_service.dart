import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class ActivePantryContext {
  const ActivePantryContext({
    required this.pantryType,
    required this.pantryId,
  });

  final String pantryType;
  final String? pantryId;
}
class SharedPantryService {
  SharedPantryService._();

  static final SharedPantryService instance = SharedPantryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ------------------------------------------------------------
  // GENERATE INVITE CODE
  // ------------------------------------------------------------

  String _generateInviteCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final random = Random();

    return List.generate(
      6,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  // ------------------------------------------------------------
  // CREATE PANTRY
  // ------------------------------------------------------------

  Future<String> createPantry({required String pantryName}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create a pantry.');
    }

    final name = pantryName.trim();

    if (name.isEmpty) {
      throw Exception('Please enter a pantry name.');
    }

    // Get the pantry type selected and saved from Profile.
    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();

    final pantryType =
        (userData?['pantryType'] as String?)
            ?.trim()
            .toLowerCase() ??
            'personal';

    if (pantryType != 'family' &&
        pantryType != 'shared') {
      throw Exception(
        'Please select Family or Hostel / Shared Pantry '
            'in your Profile before creating a shared pantry.',
      );
    }

    // Check whether the user already belongs
    // to a pantry.
    final existingMemberships = await _firestore
        .collectionGroup('members')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existingMemberships.docs.isNotEmpty) {
      throw Exception(
        'You are already a member of a pantry. '
        'Leave your current pantry before creating a new one.',
      );
    }

    final pantryRef = _firestore.collection('pantries').doc();

    final inviteCode = _generateInviteCode();

    final batch = _firestore.batch();

    // Create pantry
    batch.set(
      pantryRef,
      {
        'name': name,
        'type': pantryType,
        'inviteCode': inviteCode,
        'ownerId': user.uid,
        'createdAt':
        FieldValue.serverTimestamp(),
      },
    );

    // Add creator as owner
    batch.set(pantryRef.collection('members').doc(user.uid), {
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Link user to pantry
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid),
      {
        'pantryId': pantryRef.id,
        'pantryType': pantryType,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return pantryRef.id;
  }

  // ------------------------------------------------------------
  // JOIN PANTRY
  // ------------------------------------------------------------

  Future<String> joinPantry({required String inviteCode}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to join a pantry.');
    }

    final code = inviteCode.trim().toUpperCase();

    if (code.isEmpty) {
      throw Exception('Please enter an invite code.');
    }

    final query = await _firestore
        .collection('pantries')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code.');
    }

    final pantryDoc = query.docs.first;

    final pantryId = pantryDoc.id;

    final pantryData = pantryDoc.data();

    final pantryType =
        (pantryData['type'] as String?)
            ?.trim()
            .toLowerCase() ??
            'shared';

    if (pantryType != 'family' &&
        pantryType != 'shared') {
      throw Exception(
        'This pantry has an invalid pantry type.',
      );
    }

    // Check whether user already belongs
    // to any pantry.
    final existingMemberships = await _firestore
        .collectionGroup('members')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existingMemberships.docs.isNotEmpty) {
      throw Exception(
        'You are already a member of a pantry. '
        'Leave your current pantry before joining another one.',
      );
    }

    final memberRef = pantryDoc.reference.collection('members').doc(user.uid);

    final batch = _firestore.batch();

    // Add user as member
    batch.set(memberRef, {
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Link user to pantry
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid),
      {
        'pantryId': pantryId,
        'pantryType': pantryType,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return pantryId;
  }

  // ------------------------------------------------------------
  // GET CURRENT USER'S PANTRY
  // ------------------------------------------------------------

  Future<DocumentSnapshot<Map<String, dynamic>>> getCurrentUserPantry() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    // First check the users document.
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    final userData = userDoc.data();

    final pantryId = userData?['pantryId'];

    if (pantryId is String && pantryId.isNotEmpty) {
      final pantryDoc = await _firestore
          .collection('pantries')
          .doc(pantryId)
          .get();

      if (pantryDoc.exists) {
        return pantryDoc;
      }
    }

    // Fallback: search membership records.
    final memberships = await _firestore
        .collectionGroup('members')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (memberships.docs.isEmpty) {
      throw Exception('NO_PANTRY');
    }

    final memberDoc = memberships.docs.first;

    final pantryReference = memberDoc.reference.parent.parent;

    if (pantryReference == null) {
      throw Exception('Pantry not found.');
    }

    final pantryDoc = await pantryReference.get();

    if (!pantryDoc.exists) {
      throw Exception('Pantry not found.');
    }

    return pantryDoc;
  }

  // ------------------------------------------------------------
  // GET PANTRY
  // ------------------------------------------------------------

  Future<DocumentSnapshot<Map<String, dynamic>>> getPantry(
    String pantryId,
  ) async {
    return _firestore.collection('pantries').doc(pantryId).get();
  }

  // ------------------------------------------------------------
  // GET MEMBERS
  // ------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> getMembers(String pantryId) {
    return _firestore
        .collection('pantries')
        .doc(pantryId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots();
  }

  // ------------------------------------------------------------
  // LEAVE PANTRY
  // ------------------------------------------------------------

  Future<void> leavePantry(String pantryId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final pantryRef = _firestore.collection('pantries').doc(pantryId);

    final pantryDoc = await pantryRef.get();

    if (!pantryDoc.exists) {
      throw Exception('Pantry not found.');
    }

    final data = pantryDoc.data();

    // Owner cannot leave.
    if (data?['ownerId'] == user.uid) {
      throw Exception('The pantry owner cannot leave the pantry.');
    }

    final batch = _firestore.batch();

    // Remove membership.
    batch.delete(pantryRef.collection('members').doc(user.uid));

    // Reset user's pantry information.
    batch.set(_firestore.collection('users').doc(user.uid), {
      'pantryId': FieldValue.delete(),
      'pantryType': 'personal',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ------------------------------------------------------------
  // GET ACTIVE PANTRY TYPE
  // ------------------------------------------------------------

  Future<String> getCurrentPantryType() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final pantryType = data?['pantryType'];

    if (pantryType is String && pantryType.trim().isNotEmpty) {
      return pantryType.trim().toLowerCase();
    }

    return 'personal';
  }

  // ------------------------------------------------------------
  // GET ACTIVE PANTRY ID
  // ------------------------------------------------------------

  Future<String?> getCurrentPantryId() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final pantryId = data?['pantryId'];

    if (pantryId is String && pantryId.trim().isNotEmpty) {
      return pantryId.trim();
    }

    return null;
  }

  // ------------------------------------------------------------
  // GET ACTIVE PANTRY CONTEXT
  // ------------------------------------------------------------

  Future<ActivePantryContext> getActivePantryContext() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    final pantryType =
        (data?['pantryType'] as String?)
            ?.trim()
            .toLowerCase() ??
            'personal';

    String? pantryId =
    (data?['pantryId'] as String?)?.trim();

    // ----------------------------------------------------------
    // PERSONAL PANTRY
    // ----------------------------------------------------------

    if (pantryType == 'personal') {
      return const ActivePantryContext(
        pantryType: 'personal',
        pantryId: null,
      );
    }

    // ----------------------------------------------------------
    // FAMILY / SHARED PANTRY
    // ----------------------------------------------------------

    if (pantryType == 'family' || pantryType == 'shared') {
      // If pantryId is already saved, use it.
      if (pantryId != null && pantryId.isNotEmpty) {
        return ActivePantryContext(
          pantryType: pantryType,
          pantryId: pantryId,
        );
      }

      // --------------------------------------------------------
      // FALLBACK:
      // The user may already be a member of a pantry, but the
      // pantryId was removed when switching to Personal.
      // Recover the existing pantry from membership records.
      // --------------------------------------------------------

      final memberships = await _firestore
          .collectionGroup('members')
          .where(
        'uid',
        isEqualTo: user.uid,
      )
          .limit(1)
          .get();

      if (memberships.docs.isNotEmpty) {
        final memberDoc = memberships.docs.first;

        final pantryReference =
            memberDoc.reference.parent.parent;

        if (pantryReference != null) {
          final pantryDoc =
          await pantryReference.get();

          if (pantryDoc.exists) {
            // Restore the pantryId in the user's profile.
            pantryId = pantryDoc.id;

            await _firestore
                .collection('users')
                .doc(user.uid)
                .set(
              {
                'pantryId': pantryId,
                'pantryType': pantryType,
                'updatedAt':
                FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            return ActivePantryContext(
              pantryType: pantryType,
              pantryId: pantryId,
            );
          }
        }
      }

      // No existing pantry membership was found.
      throw Exception(
        'No shared pantry is linked to this account. '
            'Create or join a shared pantry first.',
      );
    }

    // ----------------------------------------------------------
    // UNKNOWN PANTRY TYPE
    // ----------------------------------------------------------

    throw Exception(
      'Invalid pantry type: $pantryType',
    );
  }
}
