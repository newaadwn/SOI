/**
 * Delete all content for a given user (server-side).
 * @param {object} params - params bundle
 * @param {import('firebase-admin/firestore').Firestore} params.db - Firestore
 * @param {import('firebase-admin/storage').Storage} params.storage - Storage
 * @param {any} params.supabase - Supabase client (optional)
 * @param {import('firebase-functions/logger')} params.logger - Logger
 * @param {import('firebase-admin/auth').Auth} [params.auth] - Admin Auth
 * @param {string} params.uid - Target user id
 */
module.exports.deleteUserData = async function({
  db,
  storage,
  supabase,
  logger,
  auth,
  uid,
}) {
  logger.info(`Starting server-side deletion for user ${uid}`);

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /**
   * Delete a batch of documents from a query.
   * @param {import('firebase-admin/firestore').Query} query - query
   * @param {number} [limit=450] - batch size
   * @return {Promise<number>} deleted count
   */
  async function deleteQueryBatch(query, limit = 450) {
    const snap = await query.limit(limit).get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return snap.docs.length;
  }

  /**
   * Run batched deletes until empty.
   * @param {function(): import('firebase-admin/firestore').Query} builder - fn
   * @param {number} [maxLoops=50] - max loops
   */
  async function deleteByBatches(builder, maxLoops = 50) {
    for (let i = 0; i < maxLoops; i++) {
      const count = await deleteQueryBatch(builder());
      if (count === 0) break;
      await sleep(50);
    }
  }

  /**
   * Try to delete Firebase Storage object from a download URL.
   * @param {string} url - download URL
   * @return {Promise<boolean>} success
   */
  async function tryDeleteFirebaseStorageByUrl(url) {
    try {
      const u = new URL(url);
      const oIndex = u.pathname.indexOf("/o/");
      if (oIndex === -1) return false;
      const encodedPath = u.pathname.substring(oIndex + 3);
      const objectPath = decodeURIComponent(encodedPath);
      await storage
          .bucket()
          .file(objectPath)
          .delete({ ignoreNotFound: true });
      return true;
    } catch (_) {
      return false;
    }
  }

  /**
   * Try to delete Supabase public object from URL.
   * @param {string} url - public URL
   * @return {Promise<boolean>} success
   */
  async function tryDeleteSupabaseByUrl(url) {
    if (!supabase) return false;
    try {
      const u = new URL(url);
      const marker = "/storage/v1/object/public/";
      const idx = u.pathname.indexOf(marker);
      if (idx === -1) return false;
      const rest = u.pathname.substring(idx + marker.length);
      const firstSlash = rest.indexOf("/");
      if (firstSlash === -1) return false;
      const bucket = rest.substring(0, firstSlash);
      const objectPath = rest.substring(firstSlash + 1);
      const { error } = await supabase
          .storage
          .from(bucket)
          .remove([objectPath]);
      return !error;
    } catch (_) {
      return false;
    }
  }

  /**
   * Try delete on known storage backends.
   * @param {string} url - object URL
   */
  async function deleteAnyStorageByUrl(url) {
    if (!url) return;
    const okFirebase = await tryDeleteFirebaseStorageByUrl(url);
    if (okFirebase) return;
    await tryDeleteSupabaseByUrl(url);
  }

  // 1) Reactions
  try {
    await deleteByBatches(
      () => db.collectionGroup("reactions").where("uid", "==", uid),
    );
  } catch (e) {
    logger.warn(`Failed deleting reactions for ${uid}: ${e}`);
  }

  // 2) Comment records (+audio files)
  try {
    const q = await db
        .collection("comment_records")
        .where("recorderUser", "==", uid)
        .get();
    for (const doc of q.docs) {
      const data = doc.data();
      if (data.audioUrl) await deleteAnyStorageByUrl(data.audioUrl);
      await doc.ref.delete();
    }
  } catch (e) {
    logger.warn(`Failed deleting comment_records for ${uid}: ${e}`);
  }

  // 3) Audios collection
  try {
    const q = await db.collection("audios").where("userId", "==", uid).get();
    for (const doc of q.docs) {
      const data = doc.data();
      if (data.firebaseUrl) await deleteAnyStorageByUrl(data.firebaseUrl);
      await doc.ref.delete();
    }
  } catch (e) {
    logger.warn(`Failed deleting audios for ${uid}: ${e}`);
  }

  // 4) Photos (collectionGroup) + related comment_records
  try {
    const photos = await db
        .collectionGroup("photos")
        .where("userID", "==", uid)
        .get();
    for (const doc of photos.docs) {
      const data = doc.data();
      try {
        const comments = await db
            .collection("comment_records")
            .where("photoId", "==", doc.id)
            .get();
        for (const c of comments.docs) {
          const cd = c.data();
          if (cd.audioUrl) await deleteAnyStorageByUrl(cd.audioUrl);
          await c.ref.delete();
        }
      } catch (e) {
        logger.warn(`Failed deleting comments of photo ${doc.id}: ${e}`);
      }

      if (data.imageUrl) await deleteAnyStorageByUrl(data.imageUrl);
      if (data.audioUrl) await deleteAnyStorageByUrl(data.audioUrl);
      await doc.ref.delete();
    }
  } catch (e) {
    logger.warn(`Failed deleting photos for ${uid}: ${e}`);
  }

  // 5) Notifications
  try {
    await deleteByBatches(
      () => db.collection("notifications").where("recipientUserId", "==", uid),
    );
    await deleteByBatches(
      () => db.collection("notifications").where("actorUserId", "==", uid),
    );
  } catch (e) {
    logger.warn(`Failed deleting notifications for ${uid}: ${e}`);
  }

  // 6) Graph cleanup and user doc
  try {
    const friends = await db
        .collection("users")
        .doc(uid)
        .collection("friends")
        .get();
    for (const f of friends.docs) {
      await f.ref.delete();
    }

    const users = await db.collection("users").get();
    for (const u of users.docs) {
      if (u.id === uid) continue;
      const otherFriendRef = u.ref.collection("friends").doc(uid);
      await otherFriendRef.delete().catch(() => {});
    }

    const categories = await db
        .collection("categories")
        .where("mates", "array-contains", uid)
        .get();
    for (const c of categories.docs) {
      const data = c.data();
      const mates = Array.isArray(data.mates)
        ? data.mates.filter((m) => m !== uid)
        : [];
      if (mates.length === 0) {
        await c.ref.delete();
      } else {
        await c.ref.update({mates});
      }
    }

    await db.collection("users").doc(uid).delete().catch(() => {});
  } catch (e) {
    logger.warn(`Failed deleting user graph for ${uid}: ${e}`);
  }

  // Delete auth user via Admin SDK
  try {
    if (auth) {
      await auth.deleteUser(uid);
      logger.info(`Firebase Auth user deleted: ${uid}`);
    }
  } catch (e) {
    logger.warn(`Failed to delete Firebase Auth user ${uid}: ${e}`);
  }

  logger.info(`Completed server-side deletion for user ${uid}`);
};
