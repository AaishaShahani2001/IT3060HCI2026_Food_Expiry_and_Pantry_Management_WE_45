import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedPantryService {
  SharedPantryService._();

  static final SharedPantryService instance = SharedPantryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateInviteCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    return List.generate(
      6,
          (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  Future<String> createPantry({
    required String pantryName,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create a pantry.');
    }

    final name = pantryName.trim();

    if (name.isEmpty) {
      throw Exception('Please enter a pantry name.');
    }

    final pantryRef = _firestore.collection('pantries').doc();
    final inviteCode = _generateInviteCode();

    final batch = _firestore.batch();

    batch.set(pantryRef, {
      'name': name,
      'type': 'shared',
      'inviteCode': inviteCode,
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      pantryRef.collection('members').doc(user.uid),
      {
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      _firestore.collection('users').doc(user.uid),
      {
        'pantryId': pantryRef.id,
        'pantryType': 'shared',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return pantryRef.id;
  }

  Future<String> joinPantry({
    required String inviteCode,
  }) async {
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

    final memberRef = pantryDoc.reference
        .collection('members')
        .doc(user.uid);

    final existingMember = await memberRef.get();

    if (existingMember.exists) {
      throw Exception('You are already a member of this pantry.');
    }

    final batch = _firestore.batch();

    batch.set(memberRef, {
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _firestore.collection('users').doc(user.uid),
      {
        'pantryId': pantryId,
        'pantryType': 'shared',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return pantryId;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPantry(
      String pantryId,
      ) async {
    return _firestore
        .collection('pantries')
        .doc(pantryId)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMembers(
      String pantryId,
      ) {
    return _firestore
        .collection('pantries')
        .doc(pantryId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots();
  }

  Future<void> leavePantry(String pantryId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final pantryRef =
    _firestore.collection('pantries').doc(pantryId);

    final pantryDoc = await pantryRef.get();

    if (!pantryDoc.exists) {
      throw Exception('Pantry not found.');
    }

    final data = pantryDoc.data();

    if (data?['ownerId'] == user.uid) {
      throw Exception(
        'The pantry owner cannot leave the pantry.',
      );
    }

    final batch = _firestore.batch();

    batch.delete(
      pantryRef.collection('members').doc(user.uid),
    );

    batch.set(
      _firestore.collection('users').doc(user.uid),
      {
        'pantryId': FieldValue.delete(),
        'pantryType': 'personal',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}