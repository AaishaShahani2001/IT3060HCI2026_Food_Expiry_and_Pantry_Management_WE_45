import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteField,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'freshtrack-security-rules-test';
const rulesPath = new URL('../firestore.rules', import.meta.url);
let testEnv;

const asUser = (uid) => testEnv.authenticatedContext(uid).firestore();
const signedOut = () => testEnv.unauthenticatedContext().firestore();

async function seed(entries) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(
      entries.map(([path, data]) => setDoc(doc(db, path), data)),
    );
  });
}

async function seedHousehold(pantryId = 'family-one') {
  await seed([
    [
      `pantries/${pantryId}`,
      { name: 'Family', type: 'family', inviteCode: 'JOIN123', ownerId: 'alice' },
    ],
    [
      `pantries/${pantryId}/members/alice`,
      { uid: 'alice', role: 'owner', name: 'Alice' },
    ],
    [
      `pantries/${pantryId}/members/bob`,
      { uid: 'bob', role: 'member', name: 'Bob' },
    ],
    [
      'pantryInvites/JOIN123',
      {
        pantryId,
        pantryType: 'family',
        ownerId: 'alice',
        createdAt: 'seeded',
      },
    ],
  ]);
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile(rulesPath, 'utf8') },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe('authentication and personal data', () => {
  test('signed-out users cannot access protected data', async () => {
    await seed([['users/alice', { displayName: 'Alice' }]]);
    const db = signedOut();
    await assertFails(getDoc(doc(db, 'users/alice')));
    await assertFails(setDoc(doc(db, 'users/alice/pantryItems/milk'), { qty: 1 }));
    await assertFails(getDoc(doc(db, 'expiry_alerts/alert-one')));
  });

  test('a user owns their profile and personal feature subcollections', async () => {
    const db = asUser('alice');
    await assertSucceeds(setDoc(doc(db, 'users/alice'), { displayName: 'Alice' }));
    for (const name of ['pantryItems', 'shopping_items', 'waste_records']) {
      const reference = doc(db, `users/alice/${name}/entry`);
      await assertSucceeds(setDoc(reference, { value: 1 }));
      await assertSucceeds(getDoc(reference));
      await assertSucceeds(updateDoc(reference, { value: 2 }));
      await assertSucceeds(deleteDoc(reference));
    }
  });

  test('Account A cannot access any Account B personal data', async () => {
    await seed([
      ['users/bob', { displayName: 'Bob' }],
      ['users/bob/pantryItems/item', { value: 1 }],
      ['users/bob/shopping_items/item', { value: 1 }],
      ['users/bob/waste_records/item', { value: 1 }],
      ['users/bob/notifications/item', { userId: 'bob' }],
      ['users/bob/notificationMeta/stock', { value: 1 }],
    ]);
    const db = asUser('alice');
    const paths = [
      'users/bob',
      'users/bob/pantryItems/item',
      'users/bob/shopping_items/item',
      'users/bob/waste_records/item',
      'users/bob/notifications/item',
      'users/bob/notificationMeta/stock',
    ];
    for (const path of paths) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { userId: 'alice' }));
    }
  });
});

describe('shared household data and membership authority', () => {
  test('pantry creation requires an atomic owner membership', async () => {
    const db = asUser('alice');
    await assertFails(
      setDoc(doc(db, 'pantries/family-one'), {
        name: 'Family',
        type: 'family',
        inviteCode: 'JOIN123',
        ownerId: 'alice',
      }),
    );

    const batch = writeBatch(db);
    batch.set(doc(db, 'pantries/family-one'), {
      name: 'Family',
      type: 'family',
      ownerId: 'alice',
      createdAt: 'created',
    });
    batch.set(doc(db, 'pantryInvites/JOIN123'), {
      pantryId: 'family-one',
      pantryType: 'family',
      ownerId: 'alice',
      createdAt: 'created',
    });
    batch.set(doc(db, 'pantries/family-one/members/alice'), {
      uid: 'alice',
      role: 'owner',
      name: 'Alice',
      email: 'alice@example.com',
      joinedAt: 'created',
    });
    batch.set(doc(db, 'users/alice'), {
      pantryId: 'family-one',
      pantryType: 'family',
      updatedAt: 'created',
    });
    await assertSucceeds(batch.commit());
  });

  test('verified members can read the pantry and use shared feature data', async () => {
    await seedHousehold();
    const db = asUser('bob');
    await assertSucceeds(getDoc(doc(db, 'pantries/family-one')));
    await assertSucceeds(getDocs(collection(db, 'pantries/family-one/members')));
    for (const name of ['items', 'shopping_items', 'waste_records']) {
      const reference = doc(db, `pantries/family-one/${name}/entry`);
      await assertSucceeds(setDoc(reference, { value: 1 }));
      await assertSucceeds(getDoc(reference));
      await assertSucceeds(updateDoc(reference, { value: 2 }));
      await assertSucceeds(deleteDoc(reference));
    }
  });

  test('a user can recover only their own membership with the exact uid query', async () => {
    await seedHousehold();
    const db = asUser('alice');
    const membershipLookup = query(
      collectionGroup(db, 'members'),
      where('uid', '==', 'alice'),
    );

    const snapshot = await assertSucceeds(getDocs(membershipLookup));
    assert.equal(snapshot.size, 1);
    assert.equal(snapshot.docs[0].id, 'alice');
    assert.equal(snapshot.docs[0].data().uid, 'alice');
  });

  test('the app membership recovery query with limit returns only the caller', async () => {
    await seedHousehold();
    const db = asUser('alice');
    const membershipLookup = query(
      collectionGroup(db, 'members'),
      where('uid', '==', 'alice'),
      limit(1),
    );

    const snapshot = await assertSucceeds(getDocs(membershipLookup));
    assert.equal(snapshot.size, 1);
    assert.equal(snapshot.docs[0].data().uid, 'alice');
  });

  test('an unrelated user cannot query another user membership by uid', async () => {
    await seedHousehold();
    const db = asUser('charlie');
    const anotherUserMembership = query(
      collectionGroup(db, 'members'),
      where('uid', '==', 'alice'),
    );

    await assertFails(getDocs(anotherUserMembership));
  });

  test('an authenticated user cannot run an unconstrained membership query', async () => {
    await seedHousehold();
    const db = asUser('alice');

    await assertFails(getDocs(collectionGroup(db, 'members')));
  });

  test('unrelated Account C cannot access household data', async () => {
    await seedHousehold();
    await seed([
      ['pantries/family-one/items/item', { value: 1 }],
      ['pantries/family-one/shopping_items/item', { value: 1 }],
      ['pantries/family-one/waste_records/item', { value: 1 }],
    ]);
    const db = asUser('charlie');
    for (const path of [
      'pantries/family-one',
      'pantries/family-one/members/alice',
      'pantries/family-one/items/item',
      'pantries/family-one/shopping_items/item',
      'pantries/family-one/waste_records/item',
    ]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { value: 'unauthorized' }));
    }
  });

  test('normal members cannot promote themselves or overwrite the owner', async () => {
    await seedHousehold();
    const db = asUser('bob');
    await assertFails(
      updateDoc(doc(db, 'pantries/family-one/members/bob'), { role: 'owner' }),
    );
    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/alice'), {
        uid: 'bob',
        role: 'owner',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'pantries/family-one'), { ownerId: 'bob' }),
    );
  });

  test('a non-member cannot self-add to an arbitrary pantry', async () => {
    await seedHousehold();
    const db = asUser('charlie');
    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/charlie'), {
        uid: 'charlie',
        role: 'member',
        name: 'Charlie',
      }),
    );
  });

  test('a normal member can leave by deleting their own membership', async () => {
    await seedHousehold();
    await seed([
      [
        'users/bob',
        { pantryId: 'family-one', pantryType: 'family', updatedAt: 'seeded' },
      ],
    ]);
    const db = asUser('bob');

    const batch = writeBatch(db);
    batch.delete(doc(db, 'pantries/family-one/members/bob'));
    batch.set(
      doc(db, 'users/bob'),
      {
        pantryId: deleteField(),
        pantryType: 'personal',
        updatedAt: 'left',
      },
      { merge: true },
    );
    await assertSucceeds(batch.commit());
  });

  test('a normal member cannot delete another member', async () => {
    await seedHousehold();
    await seed([
      [
        'pantries/family-one/members/charlie',
        { uid: 'charlie', role: 'member', name: 'Charlie' },
      ],
    ]);
    const db = asUser('bob');

    await assertFails(
      deleteDoc(doc(db, 'pantries/family-one/members/charlie')),
    );
  });

  test('the owner cannot delete their own owner membership', async () => {
    await seedHousehold();
    const db = asUser('alice');

    await assertFails(
      deleteDoc(doc(db, 'pantries/family-one/members/alice')),
    );
  });

  test('even the owner cannot directly delete the pantry root', async () => {
    await seedHousehold();
    const db = asUser('alice');

    await assertFails(deleteDoc(doc(db, 'pantries/family-one')));
  });

  test('owner can add a member, while role and uid remain immutable', async () => {
    await seedHousehold();
    const ownerDb = asUser('alice');
    await assertSucceeds(
      setDoc(doc(ownerDb, 'pantries/family-one/members/charlie'), {
        uid: 'charlie',
        role: 'member',
        name: 'Charlie',
      }),
    );
    const memberDb = asUser('charlie');
    await assertSucceeds(
      updateDoc(doc(memberDb, 'pantries/family-one/members/charlie'), {
        name: 'Charlie Updated',
      }),
    );
    await assertFails(
      updateDoc(doc(memberDb, 'pantries/family-one/members/charlie'), {
        uid: 'mallory',
      }),
    );
  });

  test('strict member-only reads intentionally reject invite-code join queries', async () => {
    await seedHousehold();
    const db = asUser('charlie');
    const inviteLookup = query(
      collection(db, 'pantries'),
      where('inviteCode', '==', 'JOIN123'),
    );
    await assertFails(getDocs(inviteLookup));
  });
});

describe('pantry invite authorization and join proof', () => {
  test('a signed-in non-member can get an exact invite document', async () => {
    await seedHousehold();
    const snapshot = await assertSucceeds(
      getDoc(doc(asUser('charlie'), 'pantryInvites/JOIN123')),
    );

    assert.equal(snapshot.data().pantryId, 'family-one');
  });

  test('a signed-out user cannot get an exact invite document', async () => {
    await seedHousehold();

    await assertFails(
      getDoc(doc(signedOut(), 'pantryInvites/JOIN123')),
    );
  });

  test('a signed-in user cannot enumerate pantry invites', async () => {
    await seedHousehold();

    await assertFails(
      getDocs(collection(asUser('alice'), 'pantryInvites')),
    );
  });

  test('a legitimate invited user can create their own member record', async () => {
    await seedHousehold();
    const db = asUser('charlie');
    const inviteSnapshot = await assertSucceeds(
      getDoc(doc(db, 'pantryInvites/JOIN123')),
    );
    const pantryId = inviteSnapshot.data().pantryId;

    const batch = writeBatch(db);
    batch.set(doc(db, `pantries/${pantryId}/members/charlie`), {
      uid: 'charlie',
      name: 'Charlie',
      email: 'charlie@example.com',
      role: 'member',
      inviteCode: inviteSnapshot.id,
      joinedAt: 'joined',
    });
    batch.set(
      doc(db, 'users/charlie'),
      {
        pantryId,
        pantryType: inviteSnapshot.data().pantryType,
        updatedAt: 'joined',
      },
      { merge: true },
    );

    await assertSucceeds(batch.commit());
  });

  test('a fake invite code cannot authorize self-membership', async () => {
    await seedHousehold();
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/charlie'), {
        uid: 'charlie',
        role: 'member',
        inviteCode: 'FAKE99',
      }),
    );
  });

  test('an invite for one pantry cannot authorize joining another pantry', async () => {
    await seedHousehold();
    await seed([
      [
        'pantries/family-two',
        { name: 'Other Family', type: 'family', ownerId: 'dana' },
      ],
      [
        'pantries/family-two/members/dana',
        { uid: 'dana', role: 'owner', name: 'Dana' },
      ],
    ]);
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantries/family-two/members/charlie'), {
        uid: 'charlie',
        role: 'member',
        inviteCode: 'JOIN123',
      }),
    );
  });

  test('an invited user cannot create an owner membership', async () => {
    await seedHousehold();
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/charlie'), {
        uid: 'charlie',
        role: 'owner',
        inviteCode: 'JOIN123',
      }),
    );
  });

  test('an invited user cannot create membership for another uid', async () => {
    await seedHousehold();
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/mallory'), {
        uid: 'mallory',
        role: 'member',
        inviteCode: 'JOIN123',
      }),
    );
  });

  test('an invite cannot be used to overwrite the owner membership', async () => {
    await seedHousehold();
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantries/family-one/members/alice'), {
        uid: 'charlie',
        role: 'member',
        inviteCode: 'JOIN123',
      }),
    );
  });

  test('owner and member invite retrieval queries match the app query shapes', async () => {
    await seedHousehold();
    const ownerQuery = query(
      collection(asUser('alice'), 'pantryInvites'),
      where('pantryId', '==', 'family-one'),
      where('ownerId', '==', 'alice'),
      limit(1),
    );
    const memberQuery = query(
      collection(asUser('bob'), 'pantryInvites'),
      where('pantryId', '==', 'family-one'),
      limit(1),
    );

    const ownerResults = await assertSucceeds(getDocs(ownerQuery));
    const memberResults = await assertSucceeds(getDocs(memberQuery));
    assert.equal(ownerResults.docs[0].id, 'JOIN123');
    assert.equal(memberResults.docs[0].id, 'JOIN123');
  });

  test('an unrelated user cannot query another pantry invite', async () => {
    await seedHousehold();
    const inviteLookup = query(
      collection(asUser('charlie'), 'pantryInvites'),
      where('pantryId', '==', 'family-one'),
      limit(1),
    );

    await assertFails(getDocs(inviteLookup));
  });

  test('an unrelated user cannot create, update, or delete pantry invites', async () => {
    await seedHousehold();
    const db = asUser('charlie');

    await assertFails(
      setDoc(doc(db, 'pantryInvites/NEW123'), {
        pantryId: 'family-one',
        pantryType: 'family',
        ownerId: 'charlie',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'pantryInvites/JOIN123'), { ownerId: 'charlie' }),
    );
    await assertFails(deleteDoc(doc(db, 'pantryInvites/JOIN123')));
  });
});

describe('notifications and metadata', () => {
  test('notification owner can read/create/update but cannot hard delete', async () => {
    const db = asUser('alice');
    const reference = doc(db, 'users/alice/notifications/low-stock');
    await assertSucceeds(
      setDoc(reference, { userId: 'alice', title: 'Low stock', isRead: false }),
    );
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(updateDoc(reference, { isRead: true }));
    await assertFails(updateDoc(reference, { userId: 'bob' }));
    await assertFails(deleteDoc(reference));
  });

  test('notification userId and path owner must match the caller', async () => {
    const db = asUser('alice');
    await assertFails(
      setDoc(doc(db, 'users/alice/notifications/wrong-payload'), {
        userId: 'bob',
      }),
    );
    await assertFails(
      setDoc(doc(db, 'users/bob/notifications/wrong-path'), {
        userId: 'alice',
      }),
    );
  });

  test('notificationMeta is owner-only', async () => {
    const aliceDb = asUser('alice');
    const reference = doc(aliceDb, 'users/alice/notificationMeta/stock');
    await assertSucceeds(setDoc(reference, { armedItemIds: [] }));
    await assertSucceeds(getDoc(reference));
    await assertFails(getDoc(doc(asUser('bob'), reference.path)));
  });
});

describe('expiry alerts and document identity', () => {
  test('expiry alert ownership is enforced for create/read/update/delete', async () => {
    const aliceDb = asUser('alice');
    const reference = doc(aliceDb, 'expiry_alerts/alice_item-one');
    await assertSucceeds(
      setDoc(reference, { userId: 'alice', itemId: 'item-one', isRead: false }),
    );
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(updateDoc(reference, { isRead: true }));
    await assertFails(updateDoc(reference, { userId: 'bob' }));
    await assertFails(getDoc(doc(asUser('bob'), reference.path)));
    await assertFails(deleteDoc(doc(asUser('bob'), reference.path)));
    await assertSucceeds(deleteDoc(reference));
  });

  test('create rejects a payload owned by another user', async () => {
    await assertFails(
      setDoc(doc(asUser('alice'), 'expiry_alerts/wrong-owner'), {
        userId: 'bob',
      }),
    );
  });

  test('unscoped expiry IDs collide; user-scoped IDs remain independently writable', async () => {
    await seed([
      ['expiry_alerts/shared-item-id', { userId: 'alice', itemId: 'shared-item-id' }],
    ]);
    const bobDb = asUser('bob');

    // Bob's set targets Alice's existing document, so it is evaluated as an
    // update and denied. This is why alert IDs must include the user identity.
    await assertFails(
      setDoc(doc(bobDb, 'expiry_alerts/shared-item-id'), {
        userId: 'bob',
        itemId: 'shared-item-id',
      }),
    );
    await assertSucceeds(
      setDoc(doc(bobDb, 'expiry_alerts/bob_shared-item-id'), {
        userId: 'bob',
        itemId: 'shared-item-id',
      }),
    );
  });
});

test('signed-in and signed-out users are denied on unmatched paths', async () => {
  for (const db of [asUser('alice'), signedOut()]) {
    await assertFails(getDoc(doc(db, 'internal_private/example')));
    await assertFails(
      setDoc(doc(db, 'internal_private/example'), { value: true }),
    );
  }
});
