const { readFileSync } = require('node:fs');
const path = require('node:path');
const { describe, before, after, beforeEach, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-expiry-alerts';
const rules = readFileSync(
  path.join(__dirname, '../../firestore.rules'),
  'utf8',
);

function alertData(userId, itemId, extra = {}) {
  return {
    userId,
    itemId,
    itemName: 'Milk',
    status: 'active',
    priority: 'medium',
    message: 'Milk expiry reminder',
    isRead: false,
    ...extra,
  };
}

describe('expiry_alerts security rules', () => {
  /** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: { rules },
    });
  });

  after(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  function db(uid) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  it('lets user A create their own expiry alert', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userA', 'itemX'),
      ),
    );
  });

  it('rejects an alert whose userId is another user', async () => {
    await assertFails(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userB', 'itemX'),
      ),
    );
    await assertFails(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userB_itemX'),
        alertData('userB', 'itemX'),
      ),
    );
  });

  it('lets user A read their own alert and blocks user B', async () => {
    const alert = doc(db('userA'), 'expiry_alerts', 'userA_itemX');
    await assertSucceeds(setDoc(alert, alertData('userA', 'itemX')));

    await assertSucceeds(getDoc(doc(db('userA'), 'expiry_alerts', 'userA_itemX')));
    await assertSucceeds(
      getDocs(
        query(
          collection(db('userA'), 'expiry_alerts'),
          where('userId', '==', 'userA'),
        ),
      ),
    );

    await assertFails(getDoc(doc(db('userB'), 'expiry_alerts', 'userA_itemX')));
    await assertFails(
      getDocs(
        query(
          collection(db('userB'), 'expiry_alerts'),
          where('userId', '==', 'userA'),
        ),
      ),
    );
  });

  it('lets user A update their own alert without changing userId', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userA', 'itemX'),
      ),
    );

    await assertSucceeds(
      updateDoc(doc(db('userA'), 'expiry_alerts', 'userA_itemX'), {
        isRead: true,
        userId: 'userA',
      }),
    );
    await assertFails(
      updateDoc(doc(db('userA'), 'expiry_alerts', 'userA_itemX'), {
        userId: 'userB',
      }),
    );
  });

  it('stops user B from updating user A alert', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userA', 'itemX'),
      ),
    );
    await assertFails(
      updateDoc(doc(db('userB'), 'expiry_alerts', 'userA_itemX'), {
        message: 'changed by B',
      }),
    );
  });

  it('lets user A delete their own alert and blocks user B', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userA', 'itemX'),
      ),
    );

    await assertFails(
      deleteDoc(doc(db('userB'), 'expiry_alerts', 'userA_itemX')),
    );
    await assertSucceeds(
      deleteDoc(doc(db('userA'), 'expiry_alerts', 'userA_itemX')),
    );
  });

  it('blocks unauthenticated create, read, update, and delete', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_itemX'),
        alertData('userA', 'itemX'),
      ),
    );
    const anon = testEnv.unauthenticatedContext().firestore();
    const alert = doc(anon, 'expiry_alerts', 'userA_itemX');

    await assertFails(getDoc(alert));
    await assertFails(updateDoc(alert, { isRead: true }));
    await assertFails(deleteDoc(alert));
    await assertFails(
      setDoc(
        doc(anon, 'expiry_alerts', 'userA_itemY'),
        alertData('userA', 'itemY'),
      ),
    );
  });

  it('keeps two users alerts for the same shared pantry item isolated', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('userA'), 'expiry_alerts', 'userA_sharedItem'),
        alertData('userA', 'sharedItem', { message: 'A reminder' }),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(db('userB'), 'expiry_alerts', 'userB_sharedItem'),
        alertData('userB', 'sharedItem', { message: 'B reminder' }),
      ),
    );

    await assertSucceeds(
      updateDoc(doc(db('userA'), 'expiry_alerts', 'userA_sharedItem'), {
        message: 'A updated',
        userId: 'userA',
      }),
    );

    const bobAfterUpdate = await getDoc(
      doc(db('userB'), 'expiry_alerts', 'userB_sharedItem'),
    );
    assert.equal(bobAfterUpdate.data().message, 'B reminder');

    await assertSucceeds(
      deleteDoc(doc(db('userA'), 'expiry_alerts', 'userA_sharedItem')),
    );
    const bobAfterDelete = await getDoc(
      doc(db('userB'), 'expiry_alerts', 'userB_sharedItem'),
    );
    assert.equal(bobAfterDelete.exists(), true);
    assert.equal(bobAfterDelete.data().message, 'B reminder');
    await assertFails(
      getDoc(doc(db('userB'), 'expiry_alerts', 'userA_sharedItem')),
    );
  });

  it('still lets a signed-in user write outside expiry_alerts', async () => {
    await assertSucceeds(
      setDoc(doc(db('userA'), 'rules_probe', 'doc1'), { ok: true }),
    );
    await assertFails(
      setDoc(
        doc(testEnv.unauthenticatedContext().firestore(), 'rules_probe', 'doc2'),
        { ok: true },
      ),
    );
  });
});
